// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC20BlackPauser.sol";

contract FY is ERC20BlackPauser {
    using Address for address;
    // 设置权限
    bytes32 public constant SET_ROLE = keccak256("SET_ROLE");
    // 绑定关系权限
    bytes32 public constant BINDER_ROLE = keccak256("BINDER_ROLE");

    mapping (address => address) public parent;
    // 卖币收费地址
    mapping (address => bool) private _transferToFee;
    // 卖币不收费地址
    mapping (address => bool) private _transferFromNotFee;
    mapping (address => address[]) public children;
    mapping (address => bool) public binder;

    uint256 public burn_fee;
    // 绑定关系的触发金额
    uint256 public BINDAMOUNT = 123 * 1e15;
    // 销毁地址
    address public burnAddress;
    // 关系跟地址
    address _root;
    

    event BindReferer(address indexed self,address indexed referer);

    constructor (address rootAddress, address mintTo, address burnTo) ERC20BlackPauser("Frog Youth Token", "FY"){
        require(burnTo != address(0),"FY: burnAddr is zero");
        _root = rootAddress;
        burn_fee = 300;
        burnAddress = burnTo;
        // 铸币1亿
        _mint(mintTo, 100000000*1e18);
        _setupRole(SET_ROLE, _msgSender());
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    // 设置卖币系数
    function setBurnFee(uint256 fee) public onlyRole(SET_ROLE) {
        require(fee < 10000,"FY: burn fee can not more than 100%");
        burn_fee = fee;
    }

    // 设置销毁地址
    function setBurnAddress(address burnAddr) public onlyRole(SET_ROLE) {
        require(burnAddr != address(0),"FY: burnAddr is zero");
        burnAddress = burnAddr;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transferStandard(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _spendAllowance(sender, _msgSender(), amount);
        _transferStandard(sender, recipient, amount);
        return true;
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        require(sender != address(0), "FY: transfer from the burn address");
        require(tAmount > 0, "FY: Transfer amount must be greater than 0");
        // 触发绑定关系
        if (tAmount == BINDAMOUNT){
            _bindReferer(sender, recipient);
        }
       
        bool takeFee = false;

        if(_transferToFee[recipient] && !_transferFromNotFee[sender]){
            takeFee = true;
        }
        
        (uint256 burnAmount, uint256 leftAmount) = _calcActualAmount(tAmount, takeFee);
        if (burnAmount > 0){
            _transfer(sender, burnAddress, burnAmount);
        }
        _transfer(sender, recipient, leftAmount);
    }

    function _calcActualAmount(uint256 tAmount, bool txFee) private view returns (uint256 burnAmount, uint256 leftAmount){
        if(!txFee){
            return (0, tAmount);
        }
        burnAmount = tAmount * burn_fee  / 10000;
        leftAmount = tAmount - burnAmount;
    }

    function transferToFee(address account) public  onlyRole(SET_ROLE) {
        _transferToFee[account] = true;
    }
    
    function deleteTransferToFee(address account) public  onlyRole(SET_ROLE) {
        _transferToFee[account] = false;
    }

    function transferFromNotFee(address account) public  onlyRole(SET_ROLE) {
        _transferFromNotFee[account] = true;
    }
    
    function deleteTransferFromNotFee(address account) public  onlyRole(SET_ROLE) {
        _transferFromNotFee[account] = false;
    }

    function isTransferToFee(address account) public view returns(bool) {
        return _transferToFee[account];
    }

    function isTransferFromNotFee(address account) public view returns(bool) {
        return _transferFromNotFee[account];
    }

    function bindReferer(address from, address to) public onlyRole(BINDER_ROLE) {
        _bindReferer(from, to);
    }

    function _bindReferer(address from, address to) internal {
        if(from != address(0) && to != address(0)) {
            if (parent[from] == address(0) && from != _root){
                parent[from] = _root;
                children[_root].push(from);
                emit BindReferer(to, _root);
            }
            if(parent[to] == address(0) && from != to && parent[from] != to &&
             !from.isContract() && !to.isContract()){ 
                parent[to] = from;
                children[from].push(to);
                emit BindReferer(to, from);
            }
        }
    }

    function getChildren(address account) public view returns (address[] memory) {
        return children[account];
    }

    function getChildrenCount(address account) external view returns (uint256){
        return children[account].length;
    }

    function getParent(address account) external view returns (address) {
        return parent[account];
    }

    function getParents(address account, uint256 count) external view returns (address[] memory parents) {
        parents = new address[](count);
        address tmp = account;
        for (uint256 i = 0; i < count; i++) {
            address parentAddr = parent[tmp];
            if (parentAddr == address(0)){
                return parents;
            }
            parents[i] = parentAddr;
            tmp = parentAddr;
        }
    }

    function rootAddess() external view returns(address){
        return _root;
    }
}