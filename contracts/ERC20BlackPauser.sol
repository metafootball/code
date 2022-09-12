
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// 黑名单+暂停ERC20
contract ERC20BlackPauser is ERC20Pausable, AccessControl, Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet black;   
    // 添加黑名单权限
    bytes32 public constant BLACK_ROLE = keccak256("BLACK_ROLE");
    // 查看黑名单权限
    bytes32 public constant VIEWBLACK_ROLE = keccak256("VIEWBLACK_ROLE");
    // 暂停权限
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    event BlackAdd(address indexed owner, address indexed addr);
    event BlackRemove(address indexed owner, address indexed addr);

    constructor (string memory name, string memory symbol) ERC20(name, symbol){
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(BLACK_ROLE, _msgSender());
        _setupRole(VIEWBLACK_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(!black.contains(_msgSender()), "ERC20BlackPauser: forbidden");
        require(!black.contains(from), "ERC20BlackPauser: forbidden");
        require(!black.contains(to), "ERC20BlackPauser: forbidden");
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // 添加黑名单
    function blackAdd(address addr) external  onlyRole(BLACK_ROLE) {
        if (!black.contains(addr)) {
            black.add(addr);

            emit BlackAdd(msg.sender, addr);
        }
    }

    // 移除黑名单
    function blackRemove(address addr) external  onlyRole(BLACK_ROLE) {
        if (black.contains(addr)) {
            black.remove(addr);

            emit BlackRemove(msg.sender, addr);
        }
    }

    // 查看是否是黑名单
    function viewBlack(address addr) external view onlyRole(VIEWBLACK_ROLE) returns (bool)  {
        return black.contains(addr);
    }

    // 查看黑名单
    function viewBlacks() external view  onlyRole(VIEWBLACK_ROLE) returns (address[] memory list) {
        uint256 count = black.length();
        list = new address[](black.length());

        for (uint256 i = 0; i < count; i++) {
            list[i] = black.at(i);
        }
        return list;
    }

    function skim(address token,address to, uint256 amount) public onlyOwner {
        _safeTransfer(token, to, amount);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal{
        uint256 value = IERC20(token).balanceOf(address(this));
        if (amount > value) {
            IERC20(token).transfer(to, value);
        } else {
            IERC20(token).transfer(to, amount);
        }
    }
}