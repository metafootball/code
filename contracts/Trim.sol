// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/ICandySwapPair.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";

interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract Trim is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;
    using SafeMath  for uint256;
    bytes32 public constant SET_ROLE = keccak256("SET_ROLE");   // 设置权限
    uint256 public constant MAX = (1 << 256) - 1;

    // 0.01%
    uint256 public constant EPX = 10000; 
    bytes private emptyData = bytes("");
    
    // 工厂
    address public factory;
    address public excutor;

    modifier lock() {
        require(excutor == address(0) || excutor == msg.sender, 'Trim: FORBIDDEN');
        _;
    }

    constructor(address _factory) {
        factory = _factory;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(SET_ROLE, _msgSender());
    }

    function setExcutor(address _excutor) external onlyRole(SET_ROLE) {
        excutor = _excutor;
    }

    function skim(address token, address to) public onlyRole(SET_ROLE) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if ( balance > 0 ) _safeTransfer(token, to, balance);
    }

    function getPair(address token0, address token1) public view returns (address pair) {
        pair = IFactory(factory).getPair(token0, token1);
    }

    function getReserves(address _token0, address _token1) public view returns(uint256 reserves0, uint256 reserves1, address pair, bool isReversed) {
        pair = getPair(_token0, _token1);
        (reserves0, reserves1, isReversed) = reservesByLP(pair, _token0);
    }

    function reservesByLP(address pair, address _token0) public view returns(uint256 reserves0, uint256 reserves1, bool isReversed) {
        (reserves0,reserves1,) = ICandySwapPair(pair).getReserves();
        if ( ICandySwapPair(pair).token1() == _token0 ) {
            isReversed = true;
            (reserves0,reserves1) = (reserves1,reserves0);
        }
    }

    /// @dev Compute optimal deposit amount
    /// @param amtA amount of token A desired to deposit
    /// @param amtB amonut of token B desired to deposit
    /// @param resA amount of token A in reserve
    /// @param resB amount of token B in reserve
    function optimalDeposit(
        uint256 amtA,
        uint256 amtB,
        uint256 resA,
        uint256 resB,
        uint256 feeEPX
    ) internal pure returns (uint256 swapAmt, bool isReversed) {
        if (amtA * resB >= amtB * resA) {
            swapAmt = _optimalDepositA(amtA, amtB, resA, resB, feeEPX);
            isReversed = false;
        } else {
            swapAmt = _optimalDepositA(amtB, amtA, resB, resA, feeEPX);
            isReversed = true;
        }
    }

    /// @dev Compute optimal deposit amount helper
    /// @param amtA amount of token A desired to deposit
    /// @param amtB amonut of token B desired to deposit
    /// @param resA amount of token A in reserve
    /// @param resB amount of token B in reserve
    function _optimalDepositA(
        uint256 amtA,
        uint256 amtB,
        uint256 resA,
        uint256 resB,
        uint256 feeEPX
    ) internal pure returns (uint256) {
        require(amtA * resB >= amtB * resA, "Reversed");
        uint256 a = feeEPX;
        uint256 b = (EPX + feeEPX) * resA;
        uint256 _c = amtA * resB - amtB * resA;
        uint256 c = _c * EPX  * resA / (amtB + resB);

        uint256 d = 4 * a * c;
        uint256 e = sqrt(b ** 2 + d);
        uint256 numerator = e - b;
        uint256 denominator = 2*a;
        return numerator / denominator;
    }

    function tokens(address lp) public view returns(address t0, address t1) {
        t0 = ICandySwapPair(lp).token0();
        t1 = ICandySwapPair(lp).token1();
    }

    // 配平 lp
    /// @dev Execute worker strategy. Take LP tokens + debtToken. Return LP tokens.
    /// feeEPX 不一致 在某些情况下 不会报错, feeEPX 9975
    function _mint(address token0, address token1, address lp, address to) internal returns(uint256 moreLPAmount) {
        _safeTransfer(token0, lp, IERC20(token0).balanceOf(address(this)));
        _safeTransfer(token1, lp, IERC20(token1).balanceOf(address(this)));
        // 这里没有退币
        // 只有价格变动
        moreLPAmount = ICandySwapPair(lp).mint_rateLSwap_6Reif0Umb4POOcBLsDzPk9WBnoOlVQWl(to);
    }

    // returns(uint256 , uint256)
    function removeLP(address token0, address token1, address _to) external nonReentrant lock {
        address lp = IFactory(factory).getPair(token0, token1);
        ICandySwapPair(lp).burn_rateLSwap_6Reif0Umb4POOcBLsDzPk9WBnoOlVQWl(_to);
    }

    // 自动配平
    function addLP(address token0, address token1, uint256 token0Amount, uint256 token1Amount, uint256 minLp, uint256 feeEPX, address to) external lock returns(uint256 moreLPAmount){
        // 配平需要在预支代币
        if (token0Amount > 0) {
            _safeTransferFrom(msg.sender, token0, address(this), token0Amount);
        }

        if (token1Amount > 0) {
            _safeTransferFrom(msg.sender, token1, address(this), token1Amount);
        }
        address lp = IFactory(factory).getPair(token0, token1);

        (uint256 _token0Amount, uint256 _token1Amount) = token0 < token1 ? (token0Amount, token1Amount) : (token1Amount, token0Amount);
        calAndSwap(lp, _token0Amount, _token1Amount, feeEPX);
        moreLPAmount = _mint(token0, token1,lp, to);
        require(moreLPAmount >= minLp, "insufficient addLP tokens received");
    }


    function swap(address tokenIn, address tokenOut, uint256 amountIn, address to, uint256 feeEPX) external lock {
       (uint256 reservesIn, uint256 reservesOut, address pair, bool isReversed) = getReserves(tokenIn, tokenOut);
        uint256 amount0Out = 0;
        uint256 amount1Out = 0;
        _safeTransferFrom(msg.sender, tokenIn, pair, amountIn);
        uint256 balance = IERC20(tokenIn).balanceOf(pair);
        amountIn = balance - reservesIn;
        if (isReversed) {
            amount0Out = getAmountOut(amountIn, reservesIn, reservesOut, feeEPX);
        } else {
            amount1Out = getAmountOut(amountIn, reservesIn, reservesOut, feeEPX);
        }
        ICandySwapPair(pair).swap_rateLSwap_6Reif0Umb4POOcBLsDzPk9WBnoOlVQWl(amount0Out, amount1Out, to, emptyData);
    }

    /// Compute amount and swap between borrowToken and tokenRelative.
    function calAndSwap(address lp, uint256 token0Amount, uint256 token1Amount, uint256 feeEPX) internal {
        (uint256 token0Reserve, uint256 token1Reserve,) = ICandySwapPair(lp).getReserves();
        (uint256 swapAmt, bool isReversed) = optimalDeposit(token0Amount, token1Amount, token0Reserve, token1Reserve, feeEPX);
        console.log("swapAmt1 %s", swapAmt);
        if (swapAmt > 0){
            (address token0, address token1) = tokens(lp);
            address tokenIn = isReversed ? token1 : token0;
            address tokenOut = isReversed ? token0 : token1;
            // tokenIn.safeTransfer(lp, swapAmt);
            // _swap(lp, tokenIn, swapAmt, address(this), feeEPX);
            _swap(tokenIn, tokenOut, swapAmt, address(this), feeEPX);
            // console.log("swap balance %s ", tokenOut.balanceOf(address(this)));
        }
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // feeEPX 9975
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 feeEPX) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * feeEPX;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * EPX + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _swap(address tokenIn, address tokenOut, uint256 amountIn, address to, uint256 feeEPX) internal {
        (uint256 reservesIn, uint256 reservesOut, address pair, bool isReversed) = getReserves(tokenIn, tokenOut);
        uint256 amount0Out = 0;
        uint256 amount1Out = 0;
        _safeTransfer(tokenIn, pair, amountIn);
        uint256 balance = IERC20(tokenIn).balanceOf(pair);
        amountIn = balance - reservesIn;
        if (isReversed) {
            amount0Out = getAmountOut(amountIn, reservesIn, reservesOut, feeEPX);
        } else {
            amount1Out = getAmountOut(amountIn, reservesIn, reservesOut, feeEPX);
        }
        ICandySwapPair(pair).swap_rateLSwap_6Reif0Umb4POOcBLsDzPk9WBnoOlVQWl(amount0Out, amount1Out, to, emptyData);
    }

    function _mint(address lp, address to) internal returns(uint256 moreLPAmount) {
        moreLPAmount = ICandySwapPair(lp).mint_rateLSwap_6Reif0Umb4POOcBLsDzPk9WBnoOlVQWl(to);
    }

    function sqrt(uint256 x) public pure returns (uint256) {
        if (x == 0) return 0;
        uint256 xx = x;
        uint256 r = 1;
    
        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
    
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }
    
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }

    function _safeTransferFrom(address from, address token, address to, uint256 amount) internal{
        uint256 value = IERC20(token).balanceOf(from);
        if (amount > value) {
            IERC20(token).transferFrom(from, to, value);
        } else {
            IERC20(token).transferFrom(from, to, amount);
        }
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
