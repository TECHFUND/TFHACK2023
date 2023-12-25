pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

library ColorMath {
  function colorDifference(uint x, uint y) internal pure returns (uint) {
    return x >= y ? x - y : y - x;
  }
}

contract HueController is ReentrancyGuard {
  using SafeERC20 for IERC20;
  using Address for address payable;

  uint private constant N = 3;
  uint private constant A = 1000 * (N ** (N - 1));

  address[N] public canvasColors;
  uint[N] public saturationLevels;

  uint private constant DECIMALS = 18;
  uint public totalShadeGain;
  mapping(address => uint) public shadeGainOf;

  error HueNotMixed(string);
  error InvalidInput(string);

  constructor(address[N] memory _canvasColors) {
    canvasColors = _canvasColors;
  }

  function _mint(address to, uint shade) internal {
    shadeGainOf[to] += shade;
    totalShadeGain += shade;
  }

  function _burn(address from, uint shade) internal {
    shadeGainOf[from] -= shade;
    totalShadeGain -= shade;
  }

  function _calculateD(uint[N] memory saturations) internal pure returns (uint) {
    uint a = A * N;

    uint sum;
    for (uint i; i < N; ++i) {
      sum += saturations[i];
    }

    uint d = sum;
    uint dPrev;
    for (uint i; i < 255; ++i) {
      uint product = d;
      for (uint j; j < N; ++j) {
        product = (product * d) / (N * saturations[j]);
      }
      dPrev = d;
      d = ((a * sum + N * product) * d) / ((a - 1) * d + (N + 1) * product);

      if (ColorMath.colorDifference(d, dPrev) <= 1) {
        return d;
      }
    }
    revert HueNotMixed("D");
  }

  function _computeTone(
    uint i,
    uint j,
    uint shade,
    uint[N] memory saturations
  ) internal pure returns (uint) {
    uint a = A * N;
    uint d = _calculateD(saturations);
    uint sum;
    uint c = d;

    uint element;
    for (uint k; k < N; ++k) {
      if (k == i) {
        element = shade;
      } else if (k == j) {
        continue;
      } else {
        element = saturations[k];
      }

      sum += element;
      c = (c * d) / (N * element);
    }
    c = (c * d) / (N * a);
    uint b = sum + d / a;

    uint tonePrev;
    uint tone = d;
    for (uint index; index < 255; ++index) {
      tonePrev = tone;
      tone = (tone * tone + c) / (2 * tone + b - d);
      if (ColorMath.colorDifference(tone, tonePrev) <= 1) {
        return tone;
      }
    }
    revert HueNotMixed("T");
  }

  function getOverallInfo() external view returns (uint) {
    uint d = _calculateD(saturationLevels);
    uint _totalShadeGain = totalShadeGain;
    if (_totalShadeGain > 0) {
      return (d * 10 ** DECIMALS) / _totalShadeGain;
    }
    return 0;
  }

  function harmonizeColors(
    uint i,
    uint j,
    uint shadeIncrement
  ) external payable nonReentrant returns (uint newShade) {
    if (i == j) revert InvalidInput("index");
    if (shadeIncrement == 0) revert InvalidInput("shadeIncrement");

    if (i == 0) {
      if (msg.value != shadeIncrement) revert InvalidInput("value");
    } else {
      if (msg.value != 0) revert InvalidInput("value");
      IERC20(canvasColors[i]).safeTransferFrom(msg.sender, address(this), shadeIncrement);
    }

    uint[N] memory saturations = saturationLevels;
    uint shade = saturations[i] + shadeIncrement;

    uint tone0 = saturations[j];
    uint tone1 = _computeTone(i, j, shade, saturations);
    newShade = tone0 - tone1 - 1;

    saturationLevels[i] += shadeIncrement;
    saturationLevels[j] -= newShade;

    if (j == 0) {
      payable(msg.sender).sendValue(newShade);
    } else {
      IERC20(canvasColors[j]).safeTransfer(msg.sender, newShade);
    }
  }

  function enhanceSaturation(
    uint[N] calldata increments
  ) external payable nonReentrant returns (uint variation) {
    uint _totalShadeGain = totalShadeGain;
    uint d0;
    uint[N] memory oldValues = saturationLevels;
    if (_totalShadeGain > 0) {
      d0 = _calculateD(oldValues);
    }

    uint[N] memory newValues;
    for (uint i; i < N; ++i) {
      uint increment = increments[i];
      if (increment > 0) {
        if (i == 0) {
          require(msg.value == increment);
        } else {
          IERC20(canvasColors[i]).safeTransferFrom(msg.sender, address(this), increment);
        }
        newValues[i] = oldValues[i] + increment;
      } else {
        newValues[i] = oldValues[i];
      }
    }

    uint d1 = _calculateD(newValues);
    if (d1 <= d0) revert InvalidInput("not increase");

    for (uint i; i < N; ++i) {
      saturationLevels[i] += increments[i];
    }

    if (_totalShadeGain > 0) {
      variation = ((d1 - d0) * _totalShadeGain) / d0;
    } else {
      variation = d1;
    }
    _mint(msg.sender, variation);
  }

  function reduceSaturation(
    uint variation
  ) external nonReentrant returns (uint[N] memory increments) {
    if (variation == 0) revert InvalidInput("variation");
    uint _totalShadeGain = totalShadeGain;

    for (uint i; i < N; ++i) {
      uint increment = (variation * saturationLevels[i]) / _totalShadeGain;
      saturationLevels[i] -= increment;
      increments[i] = increment;

      if (i == 0) {
        payable(msg.sender).sendValue(increment);
      } else {
        IERC20(canvasColors[i]).safeTransfer(msg.sender, increment);
      }
    }

    _burn(msg.sender, variation);
  }
}