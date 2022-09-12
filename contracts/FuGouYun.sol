// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@pancakeswap-libs/pancake-swap-core/contracts/interfaces/IPancakePair.sol";
import "./interfaces/ICandySwapFactory.sol";
import "./interfaces/ICandySwapRouter.sol";
import "./ERC20BlackPauser.sol";
import "./interfaces/IFY.sol";


contract FuGouYun is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // 设置权限
    bytes32 public constant SET_ROLE = keccak256("SET_ROLE");   // 设置权限
    // 转移权限
    bytes32 public constant SKIM_ROLE = keccak256("SKIM_ROLE"); // 取币权限
    
    // 死期质押用户数据
    struct DeathInfo {
        uint256 amount;                         // 质押总金额
        uint256 pow;                            // 衰减后的当前算力
        uint256 earned;                         // 已经计算过收益
        uint256 lastAccTokenPerShare;           // 最后一次质押时的算力奖励值 

        uint256 marketPow;                      // 市场总算力
        uint256 marketEarned;                     // 市场收益欠款
        uint256 lastAccMarketTokenPerShare;     // 最后一次质押时的算力奖励值 
    }
    bool public lock = false;                               // 合约锁定标记
    uint256 public startTime;                               // 开始时间
    uint256 public endTime;                                 // 结束时间
    uint256 public totalDepositPow = 0;                     // 质押总算力
    uint256 public totalMarketPow = 0;                      // 死期市场质押算力，实际算力需要计算算力递减
    uint256 public declineFactor = 10000000;                // 算力递减系数
    uint256 public lastRewardTime;                          // 静态收益上次奖励时间
    uint256 public accTokenPerShare;                        // 每个lp算力的奖励金额（乘MULVALUE后的值）
    uint256 public accMarketTokenPerShare;                  // 每个市场算力的奖励金额（乘MULVALUE后的值）
    uint256 public deathMul = 1;                            // 死期算力倍数
    uint256 public minDeposit = 100 * DECIMAL;              // 最小质押金额
    uint256 constant MAX_DECLINEFACTOR = 10000000000;       // 最大的算力递减系数
    uint256 constant MULVALUE = 1e18;                       // 计算收益乘数
    uint256 constant REWARD_INTERVAL = 27;                  // 挖矿间隔
    uint256 constant DECIMAL = 1e18;                        // token的小数位
    uint256 constant MAX_UINT256 = 2**256 - 1;              // 授权最大值
    uint256 constant SWAP_FEE = 9950;
    uint256 constant public DAY_TIMES = 24 hours / REWARD_INTERVAL; // 一天挖矿次数

    address public lpToken;                                 // lp合约地址
    address public router;                                  // router
    address public factory;
    address public fyToken;                                 // fy合约地址
    address public uToken;                                  // 购买需要的U的合约地址
    address public operating;                               // 运营地址
    address public development;                             // 开发地址
    address public mintAddress;                             // 产币地址

    uint256 public perReward;       // 每次挖矿基础算力产出
    uint256 public perMarketReward; // 每次市场算力产出
    uint256 public perOperating;    // 每次运营产出
    uint256 public perDevelopment;  // 每次开发产出

    mapping(address => DeathInfo) public deathUser;     // 死期用户
    mapping(address => uint256) public userUpdateEarned;     // 死期用户
    EnumerableSet.AddressSet _users;                    // 用户地址集合

    // 做市商合约地址
    address public smartAMM;
    // 进入做市商合约想系数
    uint256 public ammValue = 9000;
    // 进入做市商合约基数
    uint256 constant AMMBASE = 10000;

    modifier lockContract() {
        require(!lock, "FuGouYun: forbidden");
        _;
    }

    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
    event Claim(address indexed sender, uint256 amount);
    event Skim(address indexed from, address indexed to, address indexed token, uint256 amount);
    constructor(
        address smartAMMAddr,
        address routerddr,
        address factoryAddr,
        address fy,
        address ut,
        address op,
        address dp,
        address mintAddr,
        uint256 eTime
    ) {
        smartAMM = smartAMMAddr;
        fyToken = fy;
        uToken = ut;
        operating = op;
        development = dp;
        mintAddress = mintAddr;
        router = routerddr;
        factory = factoryAddr;
        endTime = eTime;

        IERC20(uToken).approve(router, MAX_UINT256);
        IERC20(fyToken).approve(router, MAX_UINT256);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(SKIM_ROLE, _msgSender());
        _setupRole(SET_ROLE, _msgSender());

        // 设置每日产量
        _setDayout(1000);
    }

    // 修改做市商合约地址
    function setSmartAMM(address amm) public onlyRole(DEFAULT_ADMIN_ROLE) {
        smartAMM = amm;
    }

    // 修改做市商合约转入系数
    function setAMMValue(uint256 value) public onlyRole(SET_ROLE) {
        require(value <= AMMBASE, "FuGouYun: invalid value");
        ammValue = value;
    }

    // 修改每日产币量
    function setDayout(uint256 dayOut) public onlyRole(SET_ROLE) {
        _setDayout(dayOut);
    }

    function _setDayout(uint256 dayOut) internal {
        perReward = dayOut.mul(DECIMAL).mul(49).div(100).div(DAY_TIMES);  
        perMarketReward = dayOut.mul(DECIMAL).mul(21).div(100).div(DAY_TIMES);  
        perOperating = dayOut.mul(DECIMAL).mul(20).div(100).div(DAY_TIMES);  
        perDevelopment = dayOut.mul(DECIMAL).mul(10).div(100).div(DAY_TIMES);       
    }

    // 设置开始时间
    function setStartTime(uint256 sTime) public onlyRole(SET_ROLE) {
        startTime = sTime;
    }

    // 设置结束时间
    function setEndTime(uint256 eTime) public onlyRole(SET_ROLE) {
        endTime = eTime;
    }

    // 设置算力递减系数
    function setDeclineFactor(uint256 dFactor) public onlyRole(SET_ROLE) {
        declineFactor = dFactor;
    }

    // 设置最低质押金额
    function setMinDeposit(uint256 mDeposit) public onlyRole(SET_ROLE) {
        minDeposit = mDeposit;
    }

    // 设置lp地址
    function setLpToken(address lp) public onlyRole(SET_ROLE) {
        lpToken = lp;
        IERC20(lpToken).approve(router, MAX_UINT256);
    }

    // 设置fy地址
    function setFYToken(address fy) public onlyRole(SET_ROLE) {
        fyToken = fy;
        IERC20(fyToken).approve(router, MAX_UINT256);
    }

    // 设置usdt地址
    function setUToken(address u) public onlyRole(SET_ROLE) {
        uToken = u;
        IERC20(uToken).approve(router, MAX_UINT256);
    }

    // 设置router地址
    function setRouter(address routerAddr) public onlyRole(SET_ROLE) {
        router = routerAddr;
        IERC20(uToken).approve(router, MAX_UINT256);
        IERC20(fyToken).approve(router, MAX_UINT256);
        IERC20(lpToken).approve(router, MAX_UINT256);
    }

    // 设置运营地址
    function setOperating(address op) public onlyRole(SET_ROLE) {
        operating = op;
    }

    // 设置开发地址
    function setDevelopment(address dp) public onlyRole(SET_ROLE) {
        development = dp;
    }

    // 设置产币来源地址
    function setMintAddress(address ma) public onlyRole(SET_ROLE) {
        mintAddress = ma;
    }

    // 锁定合约
    function setLock() public onlyRole(SET_ROLE) {
        lock = true;
    }

    // 解锁合约
    function unLock() public onlyRole(SET_ROLE) {
        lock = false;
    }

    // 初始化底池100wUSDT
    // 20w fy:10w usdt
    // 90w usdt进入做市商
    function initPool() public onlyRole(SET_ROLE) {
        uint256 uAmount = 100000 ether;
        uint256 fyAmount = 200000 ether;
        uint256 smartAMMIn = 900000 ether;
        if(smartAMM != address(0)){
            ERC20(uToken).transferFrom(msg.sender, smartAMM, smartAMMIn);
        }
        ERC20(uToken).transferFrom(msg.sender, address(this), uAmount);
        ERC20(fyToken).transferFrom(msg.sender, address(this), fyAmount);
        // 添加底池流动性，设置lptoken地址
        ICandySwapRouter(router).addLiquidity(uToken, fyToken, uAmount, fyAmount, 0, 0, address(this), block.timestamp + 100);
        lpToken = ICandySwapFactory(factory).getPair(uToken, fyToken);
        IERC20(lpToken).approve(router, MAX_UINT256);
        // 设置合约开始挖矿时间
        startTime = _curTermStart(block.timestamp);  
        // 设置最后一次奖励时间      
        lastRewardTime = _curTermStart(startTime);
    }

    // 初始化底池用户
    function initPoolUser(address user, uint256 amount) public onlyRole(SET_ROLE) {
        DeathInfo storage death = deathUser[user];
        require(death.amount == 0, "FuGouYun: initialized");
        require(startTime == 0, "FuGouYun: overdue");
        // 添加user地址
        _addUser(user);
        // 如果没有关系，则绑定关系
        _bindReferer(user);
        // 计算算力
        uint256 pow = amount.mul(deathMul);
        totalDepositPow = totalDepositPow.add(pow);
        death.amount = amount;
        death.pow = pow;
        // 底池没有市场算力
        // _updateParents(user, pow);
        emit Deposit(user, amount);
    }


    // 初始化底池用户
    struct User {
        address user;
        uint256 amount;
    }
    function initPoolUsers(User[] calldata _user) external onlyRole(SET_ROLE) {
        uint _totalDepositPow = 0;
        for(uint i = 0 ; i < _user.length; i++) {
            
            address user = _user[i].user;
            uint amount = _user[i].amount;

            DeathInfo storage death = deathUser[user];
            // require(death.amount == 0, "FuGouYun: initialized");
            // require(startTime == 0, "FuGouYun: overdue");
            // 添加user地址
            _addUser(user);
            // 如果没有关系，则绑定关系
            _bindReferer(user);
            // 计算算力
            uint256 pow = amount.mul(deathMul);
            _totalDepositPow = _totalDepositPow.add(pow);
            death.amount = amount;
            death.pow = pow;
            // 底池没有市场算力
            // _updateParents(user, pow);
            emit Deposit(user, amount);
        }
        totalDepositPow = totalDepositPow.add(_totalDepositPow);
    }

    // 质押
    function deposit(uint256 amount) public lockContract {
        require (block.timestamp < endTime, "FuGouYun: it's over");
        require (amount >= minDeposit, "FuGouYun: not less than the minimum amount deposit");

        // 如果没有关系，绑定默认关系
        _bindReferer(msg.sender);
        // 转USDT给合约
        IERC20(uToken).safeTransferFrom(address(msg.sender), address(this), amount);
        // 添加用户地址
        _addUser(msg.sender);
        // 更新产币
        updatePool();
        // 更新收益
        _updateEarned(msg.sender);
        // 兑换fy
        _swapFyToken(amount);
        // 死期质押
        _depositDeath(amount);
        
        emit Deposit(msg.sender, amount);
    }

    function _bindReferer(address user) private {
        address parent = IFY(fyToken).getParent(user);
        if (parent == address(0)){
            // 如果用户没有上级，则默认绑定到根地址
            IFY(fyToken).bindReferer(IFY(fyToken).rootAddess(), user);
        }
    }

    // 死期质押
    function _depositDeath(uint256 amount) private {
        // 死期购买的fy销毁
        DeathInfo storage death = deathUser[msg.sender];
        uint256 increasePow = amount.mul(deathMul);
        death.amount = death.amount.add(amount);
        death.pow = death.pow.add(increasePow);
        totalDepositPow = totalDepositPow.add(increasePow);
        // 更新父级
        _updateParents(msg.sender, increasePow);
    }

    // 取出收益
    function claim() lockContract public {
        // 更新产币
        updatePool();
        // 更新收益
        _updateEarned(msg.sender);

        DeathInfo storage death = deathUser[msg.sender];
        
        // 加上质押算力
        uint256 totalEarned = death.earned;
        death.earned = 0;

        // 加上市场算力
        totalEarned = totalEarned.add(death.marketEarned);
        death.marketEarned = 0;

        require(totalEarned > 0, "FuGouYun: no claim");

        _safeTokenTransfer(msg.sender, fyToken, totalEarned);

        emit Claim(msg.sender, totalEarned);
    }

    // 更新产币
    function updatePool() public lockContract {
        if (startTime == 0) {
            startTime = _curTermStart(block.timestamp);
        }
        if (block.timestamp <= lastRewardTime) {
            return;
        }
        
        if (lastRewardTime == 0){
            lastRewardTime = _curTermStart(startTime);
        }
        
        uint256 multiplier = _getMultiplier(lastRewardTime, block.timestamp);
       
        // 更新当前递减后的总质押算力
        totalDepositPow = _calPowDecline(totalDepositPow, lastRewardTime, block.timestamp);
        
        if (totalDepositPow > 0) {
            uint256 reward = multiplier.mul(perReward);
            if (reward > 0){
                // 产币到当前合约
                IERC20(fyToken).safeTransferFrom(mintAddress, address(this), reward);
                accTokenPerShare = accTokenPerShare.add(reward.mul(MULVALUE).div(totalDepositPow));
            }
        }
        // 更新当前递减后的总市场质押算力
        totalMarketPow = _calPowDecline(totalMarketPow, lastRewardTime, block.timestamp);

        if (totalMarketPow > 0) {
            uint256 marketReward = multiplier.mul(perMarketReward);
            if (marketReward > 0){
                // 市场产币到当前合约
                IERC20(fyToken).safeTransferFrom(mintAddress, address(this), marketReward);
                accMarketTokenPerShare = accMarketTokenPerShare.add(marketReward.mul(MULVALUE).div(totalMarketPow));
            }
        }
        
        // 产币给运营
        uint256 curOperatingReward = multiplier.mul(perOperating);
        if (curOperatingReward > 0 ) {
            IERC20(fyToken).safeTransferFrom(mintAddress, operating, curOperatingReward);
        }

        // 产币给开发
        uint256 curDevelopmentReward = multiplier.mul(perDevelopment);
        if (curDevelopmentReward > 0) {
           IERC20(fyToken).safeTransferFrom(mintAddress, development, curDevelopmentReward);
        }

        // 更新产币时间
        lastRewardTime = _curTermStart(block.timestamp);
    }

    // 更新收益
    function _updateEarned(address user) private {
        // 如果startTime == 0 ，则为还未开始，不递减算力和收益
        if (startTime == 0){
            return;
        }
        uint256 lastUpdateEarned = userUpdateEarned[user];
        // 如果lastUpdateEarned == 0，则该用户为底池用户，
        // 赋予初始更新时间
        if (lastUpdateEarned == 0){
            lastUpdateEarned = startTime;
        }
        // 更新质押收益
        _updateDeathEarned(user, lastUpdateEarned);
        // 更新市场收益
        _updateMarketEarned(user, lastUpdateEarned);
        // 修改更新收益时间
        userUpdateEarned[user] =  _curTermStart(block.timestamp);
    }

    // 更新死期收益
    function _updateDeathEarned(address user, uint256 lastUpdateEarned) private {
        DeathInfo storage death = deathUser[user];
        // 更新递减后的用户算力
        death.pow = _calPowDecline(death.pow, lastUpdateEarned, block.timestamp);
        // 更新死期算力
        if (death.pow > 0) {
            // 计算收益
            uint256 pending = death.pow.mul(accTokenPerShare.sub(death.lastAccTokenPerShare)).div(MULVALUE);
            if (pending > 0) {
                // 更新收益值
                death.earned = death.earned.add(pending);
            }
        }
        // 修改最后一次计算过收益手的增益值
        death.lastAccTokenPerShare = accTokenPerShare;
    }

    // 更新市场收益
    function _updateMarketEarned(address user, uint256 lastUpdateEarned) private {
        DeathInfo storage death = deathUser[user];
        if (death.amount >= minDeposit) {
            // 更新递减后的市场算力
            death.marketPow = _calPowDecline(death.marketPow, lastUpdateEarned, block.timestamp);
            if( death.marketPow > 0){
                // 计算市场收益
                uint256 pending = death.marketPow.mul(accMarketTokenPerShare.sub(death.lastAccMarketTokenPerShare)).div(MULVALUE);
                if (pending > 0) {
                    // 更新市场收益值
                    death.marketEarned = death.marketEarned.add(pending);
                }
            }
        }
        // 修改最后一次计算过市场收益手的增益值
        death.lastAccMarketTokenPerShare = accMarketTokenPerShare;
    }

    // 更新父地址收益和算力
    function _updateParents(address user, uint256 increasePow) private {
        // 只给一层直推添加市场算力
        address[] memory parents = IFY(fyToken).getParents(user, 1);
        if (parents.length >= 1){
            address parent = parents[0];
            if (parent == address(0)){
                return;
            }
            // 根地址不计算算力
            if (parent == IFY(fyToken).rootAddess()){
                return;
            }
            // 添加地址
            _addUser(parent);

            DeathInfo storage death = deathUser[parent];
            // 质押金额必须大于100，才能有市场算力
            if(death.amount < minDeposit){
                return;
            }
            // 更新上级收益
            _updateEarned(parent);
            uint256 pow = increasePow.mul(80).div(1000);
            // 更新上级市场算力
            death.marketPow = death.marketPow.add(pow);
            // 更新总市场算力
            totalMarketPow = totalMarketPow.add(pow);
        }
    }

    // 获得用户当前总收益
    function userEarned(address user, uint256 timestamp) public view returns(uint256){
        DeathInfo storage death = deathUser[user];
        uint256 lastUpdateEarned = userUpdateEarned[user];
        // 如果lastUpdateEarned == 0，则为底池用户，修改上次更新时间为开始时间
        if (lastUpdateEarned == 0){
            lastUpdateEarned = startTime;
        }
        if (death.pow == 0 && death.marketPow == 0){
            return 0;
        }
        // 如果当前时间超过结束时间，则最后时间为结束时间
        timestamp = endTime < timestamp? endTime : timestamp;
        uint256 tempAccTokenPerShare = accTokenPerShare;
        uint256 tempAccMarketTokenPerShare = accMarketTokenPerShare;
        if (lastRewardTime != 0 && timestamp > lastRewardTime) {
            // 计算产币次数
            uint256 multiplier = _getMultiplier(lastRewardTime, timestamp);
            // 计算递减后的质押算力
            uint256 curDepositPow = _calPowDecline(totalDepositPow, lastRewardTime, timestamp);
            tempAccTokenPerShare = accTokenPerShare.add(multiplier.mul(perReward).mul(MULVALUE).div(curDepositPow));

            // 计算递减后的市场算力
            uint256 curMarketPow = _calPowDecline(totalMarketPow, lastRewardTime, timestamp);
            if (curMarketPow != 0){
                tempAccMarketTokenPerShare = accMarketTokenPerShare.add(multiplier.mul(perMarketReward).mul(MULVALUE).div(curMarketPow));
            }
        }
        // 上次计算过的质押收益+市场收益
        uint256 totalEarned = death.earned.add(death.marketEarned);

        if (death.pow > 0){
            // 计算未计算的质押收益
            uint256 curDeathPow = _calPowDecline(death.pow, lastUpdateEarned, timestamp);
            uint256 pending = curDeathPow.mul(tempAccTokenPerShare.sub(death.lastAccTokenPerShare)).div(MULVALUE);
            totalEarned = totalEarned.add(pending);
        }

        if (death.amount >= minDeposit && death.marketPow > 0){
            // 计算未计算的市场收益
            uint256 curMarketPow = _calPowDecline(death.marketPow, lastUpdateEarned, timestamp);
            uint256 pending = curMarketPow.mul(tempAccMarketTokenPerShare.sub(death.lastAccMarketTokenPerShare)).div(MULVALUE);
            totalEarned = totalEarned.add(pending);
        }
    
        return totalEarned;
    }

    // 购买fy
    function _swapFyToken(uint256 amount) private {
        // 购买前fy余额
        uint256 swapBefore = IERC20(fyToken).balanceOf(address(this));
        if(smartAMM != address(0)){
            // 计算进入做市商的USDT金额
            uint256 smartAMMIn = amount * ammValue / AMMBASE;
            amount = amount - smartAMMIn;
            // 转入做市商合约
            _safeTokenTransfer(smartAMM, uToken, smartAMMIn);
        }
    
        address[] memory path = new address[](2);
        path[0] = uToken;
        path[1] = fyToken;
        // 购买FY
        uint256[] memory amounts = ICandySwapRouter(router).swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp + 100);
        uint256 swapAfter = IERC20(fyToken).balanceOf(address(this));
        if (swapAfter > swapBefore && swapAfter.sub(swapBefore) <= amounts[1]){
            // 死期质押兑换后直接销毁， swapAfter-swapBefore = 实际兑换FY数量
            IFY(fyToken).burn(swapAfter.sub(swapBefore));
        }
    }

    // 转币
    function _safeTokenTransfer(address to, address coin,uint256 amount) private {
        uint256 value = IERC20(coin).balanceOf(address(this));
        if (amount > value) {
            IERC20(coin).transfer(to, value);
        } else {
            IERC20(coin).transfer(to, amount);
        }
    }
    
    // 计算质押时间周期数
    function _curTermStart(uint256 blockTime) private pure returns (uint256) {
        if (blockTime.mod(REWARD_INTERVAL) == 0) {
            return blockTime;
        }
        // 整数周期
        return blockTime.div(REWARD_INTERVAL).mul(REWARD_INTERVAL);
    }

    // 计算产币次数
    function _getMultiplier(uint256 from, uint256 to) private view returns (uint256) {
        // 不能超过结束时间
        if (to > endTime) {
            to = endTime;
        }
        if (from >= endTime) {
            return 0;
        }
        return to.sub(from).div(REWARD_INTERVAL);
    }

    // 获取用户地址
    function viewAddress(uint256 index) public view returns (address) {
        return _users.at(index);
    }

    // 获取用户数量
    function userLength() public view returns (uint256) {
        return _users.length();
    }

    // 添加用户地址
    function _addUser(address user) private {
        if (!_users.contains(user)) {
            _users.add(user);
        }
    }

    // 取出合约中的币
    function skim(address token,address to, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _safeTokenTransfer(to, token, amount);
        emit Skim(msg.sender, to, token, amount);
    }

    // 计算算力递减
    function _calPowDecline(uint256 pow, uint256 lastTime, uint256 nowTime) private view returns (uint256){
        if (pow == 0 || lastTime >= nowTime){
            return pow;
        }
        uint256 powTemp = pow;
        uint256 sec = nowTime - lastTime;
        // 递减天数
        uint256 dayTimes = sec.div(24 hours);
        if(sec % 24 hours != 0){
            dayTimes = dayTimes + 1;
        }
        for(uint256 i = 0;i < dayTimes;i++){
            powTemp = powTemp * (MAX_DECLINEFACTOR - declineFactor) / MAX_DECLINEFACTOR;
        }
        uint256 subPow = pow - powTemp;
        uint256 maxTimes = dayTimes * DAY_TIMES;
        uint256 times = sec / REWARD_INTERVAL;
        uint256 actulSub = (times * subPow / maxTimes);
        if (actulSub >= pow){
            return 1;
        }
        return pow - actulSub;
    }

    // 当前总质押算力
    function curTotalDepositPow(uint256 timestamp) public view returns(uint256){
        return _calPowDecline(totalDepositPow, lastRewardTime, timestamp);
    }

    // 当前总市场算力
    function curTotalMarketPow(uint256 timestamp) public view returns(uint256){
        return _calPowDecline(totalMarketPow, lastRewardTime, timestamp);
    }

    // 当前用户总质押算力
    function curUserDepositPow(address user, uint256 timestamp) public view returns(uint256){
        DeathInfo storage death = deathUser[user];
        uint256 lastUpdateEarned = userUpdateEarned[user];
        // 底池用户时
        if (lastUpdateEarned == 0){
            lastUpdateEarned = startTime;
        }
        return _calPowDecline(death.pow, lastUpdateEarned, timestamp);
    }

    // 当前用户市场算力
    function curUserMarketPow(address user, uint256 timestamp) public view returns(uint256){
        DeathInfo storage death = deathUser[user];
        uint256 lastUpdateEarned = userUpdateEarned[user];
        if (lastUpdateEarned == 0){
            lastUpdateEarned = startTime;
        }
        return _calPowDecline(death.marketPow, lastUpdateEarned, timestamp);
    }

    // 当前用户死期算力
    function curUserDeathPow(address user, uint256 timestamp) public view returns(uint256){
        DeathInfo storage death = deathUser[user];
        uint256 lastUpdateEarned = userUpdateEarned[user];
        if (lastUpdateEarned == 0){
            lastUpdateEarned = startTime;
        }
        return _calPowDecline(death.pow, lastUpdateEarned, timestamp);
    }

    struct Info {
        uint256 Price;
        uint256 DayOutPut;
        uint256 TVL;
        uint256 CurTotalDepositPow;
        uint256 CurTotalMarketPow;
        uint256 USDTTVL;
        uint256 FYTVL;
    }

    function fuGouYunInfo(uint256 timestamp) public view returns(Info memory data){
        (uint256 reserve0, uint256 reserve1,) = IPancakePair(lpToken).getReserves();
        address token0 = IPancakePair(lpToken).token0();
        (uint256 reserveInput, uint256 reserveOutput) = fyToken == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        data = Info({
            Price: reserveOutput.mul(10000).div(reserveInput),
            DayOutPut: perReward.add(perMarketReward).mul(DAY_TIMES),
            TVL: reserveOutput.mul(2),
            CurTotalDepositPow: curTotalDepositPow(timestamp),
            CurTotalMarketPow: curTotalMarketPow(timestamp),
            USDTTVL: reserveOutput,
            FYTVL: reserveInput});
    }
    
}



