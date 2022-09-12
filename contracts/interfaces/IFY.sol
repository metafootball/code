// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFY {
    function rootAddess() external view returns(address);
    function getParents(address account, uint256 count) external view returns (address[] memory parents);
    function getParent(address account) external view returns (address);
    function burn(uint256 amount) external;
    function bindReferer(address from, address to) external;
    function getChildrenCount(address account) external view returns (uint256);
}
