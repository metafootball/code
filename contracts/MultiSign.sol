
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// 多签合约
contract MultiSign {
    using EnumerableSet for EnumerableSet.AddressSet;
    // 当前授权ID
    uint256 public curId;
    // 授权最小权重
    uint8 public authWeight;
    // 授权基础值
    uint8 public constant authBase = 100; 
    struct CallEvent {
        mapping (address=>bool) auth;
        uint8 authCount;
        uint256 id;
        uint8 state;
        string eventName;
        uint8   param1;
        uint16  param2;
        uint256 param3;
        address param4;
        address param5;
        address param6;
        address[] param7;
        bytes32 param8; 
    }
    event Modify(address indexed from, uint256 eventId ,string eventName);
    event SetAuth(address indexed from, uint256 eventId ,string eventName, uint8 count);
    event Add(address indexed from, uint256 eventId ,string eventName);
    event Remove(address indexed from, uint256 eventId ,string eventName);
    event Auth(address indexed from, uint256 eventId ,string eventName);
    event Cancel(address indexed from, uint256 eventId ,string eventName);
    event Withdraw(address indexed from, uint256 eventId ,string eventName, uint16 tokenId, uint256 amount, address to, uint8 inputDecimals);

    EnumerableSet.AddressSet private _managers;
    mapping(uint256 => CallEvent) public callEvents;
    modifier onlyManager() {
        require(_managers.contains(msg.sender), "MulSign: caller is not the manage");
        _;
    }
    modifier sendId(uint256 id) {
        require(id == curId + 1, "MulSign: wrong id");
        _;
    }
    modifier authId(uint256 id) {
        require(id <= curId, "MulSign: wrong id");
        _;
    }
    constructor(
        address[] memory mgrs,
        uint8 auth
    ) {
        require(auth <= authBase && auth >= 10, "MulSign: wrong authWeight");
        for(uint256 i = 0;i < mgrs.length; i++){
            require(mgrs[i] != address(0), "MulSign: wrong manager");
            _managers.add(mgrs[i]);
        }
        authWeight = auth;
    }

    // 查看管理员
    function viewManagers() external view returns (address[] memory list) {
        uint256 count = _managers.length();
        list = new address[](_managers.length());

        for (uint256 i = 0; i < count; i++) {
            list[i] = _managers.at(i);
        }
        return list;
    }

    function viewManagersLength() external view returns (uint256) {
        return _managers.length();
    }

    function _equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    // 取消授权
    function cancel(uint256 eventId) public onlyManager authId(eventId){
         CallEvent storage callEvent = callEvents[eventId];
         if (callEvent.state == 0){
             callEvent.state = 3;
             emit Cancel(msg.sender, eventId, callEvent.eventName);
         }
    }


    // 申请修改管理员地址
    function modifyManager(uint256 eventId, address oldAddr, address newAddr) public onlyManager sendId(eventId){
        require(_managers.contains(oldAddr), "MulSign: oldAddr is not the manager");
        require(!_managers.contains(newAddr), "MulSign: newAddr is the manager");
        require(newAddr != address(0), "MulSign: caller is not the manager");
        CallEvent storage callEvent = callEvents[eventId];
        callEvent.id = eventId;
        callEvent.eventName = "modifyManager";
        callEvent.param4 = oldAddr;
        callEvent.param5 = newAddr;
        callEvent.auth[msg.sender] = true;
        callEvent.authCount = 1;
        curId = eventId;

        emit Modify(msg.sender, eventId, callEvent.eventName);
    }

    // 授权修改管理员地址
    function auth_modifyManager(uint256 eventId) public onlyManager authId(eventId){
        CallEvent storage callEvent = callEvents[eventId];
        bool authed = callEvent.auth[msg.sender];
        require(callEvent.state == 0, "MulSign: wrong state");
        require(!authed, "MulSign: Has authorized");
        require(_equal(callEvent.eventName, "modifyManager"), "MulSign: wrong auth");
        callEvent.auth[msg.sender] = true;
        callEvent.authCount++;
        // 授权数量大于最小授权数量，则进行授权
        if(callEvent.authCount >= minAuthCount()){
            _managers.remove(callEvent.param4);
            _managers.add(callEvent.param5);
            callEvent.state = 1;
        }
        emit Modify(msg.sender, eventId, callEvent.eventName);
    }

    // 申请添加管理员
    function addManager(uint256 eventId, address newManager) public onlyManager sendId(eventId){
        require(!_managers.contains(newManager), "MulSign: newAddr is the manager");
        require(newManager != address(0), "MulSign: caller is not the manager");
        CallEvent storage callEvent = callEvents[eventId];
        callEvent.id = eventId;
        callEvent.eventName = "addManager";
        callEvent.param4 = newManager;
        callEvent.auth[msg.sender] = true;
        callEvent.authCount = 1;
        curId = eventId;

        emit Add(msg.sender, eventId, callEvent.eventName);
    }

    // 授权添加管理员
    function auth_addManager(uint256 eventId) public onlyManager authId(eventId){
        CallEvent storage callEvent = callEvents[eventId];
        bool authed = callEvent.auth[msg.sender];
        require(callEvent.state == 0, "MulSign: wrong state");
        require(!authed, "MulSign: Has authorized");
        require(_equal(callEvent.eventName, "addManager"), "MulSign: wrong auth");
        callEvent.auth[msg.sender] = true;
        callEvent.authCount++;
        if(callEvent.authCount >= minAuthCount()){
            _managers.add(callEvent.param4);
            callEvent.state = 1;
        }
        emit Add(msg.sender, eventId, callEvent.eventName);
    }

    // 移除管理员
    function removeManager(uint256 eventId, address oldManager) public onlyManager sendId(eventId){
        require(_managers.contains(oldManager), "MulSign: address is the manager");
        require(_managers.length() > 2, "MulSign: _managers length error");
        require(oldManager != address(0), "MulSign: manager is zero");
        
        CallEvent storage callEvent = callEvents[eventId];
        callEvent.id = eventId;
        callEvent.eventName = "removeManager";
        callEvent.param4 = oldManager;
        callEvent.auth[msg.sender] = true;
        callEvent.authCount = 1;
        curId = eventId;

        emit Remove(msg.sender, eventId, callEvent.eventName);
    }
    // 授权移除管理员
    function auth_removeManager(uint256 eventId) public onlyManager authId(eventId){
        CallEvent storage callEvent = callEvents[eventId];
        bool authed = callEvent.auth[msg.sender];
        require(callEvent.state == 0, "MulSign: wrong state");
        require(!authed, "MulSign: Has authorized");
        require(_equal(callEvent.eventName, "removeManager"), "MulSign: wrong auth");
        callEvent.auth[msg.sender] = true;
        callEvent.authCount++;
        if(callEvent.authCount >= minAuthCount()){
            _managers.remove(callEvent.param4);
            callEvent.state = 1;
        }
        emit Remove(msg.sender, eventId, callEvent.eventName);
    }

    // 设置多签名数量
    function setAuthWeight(uint256 eventId, uint8 weight) public onlyManager sendId(eventId){
        require(authWeight <= authBase && authWeight >= 10, "MulSign: wrong authCount");
        CallEvent storage callEvent = callEvents[eventId];
        callEvent.id = eventId;
        callEvent.eventName = "setAuthWeight";
        callEvent.param1 = weight;
        callEvent.auth[msg.sender] = true;
        callEvent.authCount = 1;
        curId = eventId;

        emit SetAuth(msg.sender, eventId, callEvent.eventName, weight);
    }

    // 授权设置多签名数量
    function auth_setAuthWeight(uint256 eventId) public onlyManager authId(eventId){
        CallEvent storage callEvent = callEvents[eventId];
        bool authed = callEvent.auth[msg.sender];
        require(callEvent.state == 0, "MulSign: wrong state");
        require(!authed, "MulSign: Has authorized");
        require(_equal(callEvent.eventName, "setAuthWeight"), "MulSign: wrong auth");
        callEvent.auth[msg.sender] = true;
        callEvent.authCount++;
        if(callEvent.authCount >= minAuthCount()){
            require(callEvent.param1 <= authBase && callEvent.param1 >= 10, "MulSign: wrong count");
            authWeight = callEvent.param1;
            callEvent.state = 1;
        }
        emit SetAuth(msg.sender, eventId, callEvent.eventName, callEvent.param1);
    }
   
    function minAuthCount() public view returns(uint16){
        return authWeight * uint16(_managers.length()) / authBase;
    }
}

