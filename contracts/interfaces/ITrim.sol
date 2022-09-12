// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITrim {
    function removeLP(address token0, address token1, address _to) external;
    function swap(address tokenIn, address tokenOut, uint256 amountIn, address to, uint256 feeEPX) external;
    function addLP(address token0, address token1, uint256 token0Amount, uint256 token1Amount, uint256 minLp, uint256 feeEPX, address to) external returns(uint256);
    function createLP(address tokenA,address tokenB,uint256 amountADesired,uint256 amountBDesired,uint256 amountAMin,uint256 amountBMin,address to) external returns (address lp, uint256 amountA, uint256 amountB, uint256 liquidity);
}
