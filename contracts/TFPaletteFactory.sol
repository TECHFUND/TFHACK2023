pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ud, convert} from "@prb/math/src/UD60x18.sol";

import "./ColorPalette.sol";
import "./ColorComposition.sol";
import "./HueController.sol";

contract TFPaletteFactory {
  uint private constant INITIAL_PALETTE = 100 ether;
  address private constant ARTIST = 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199;

  ColorComposition public colorComposition;
  HueController public hueController;

  mapping(bytes => bool) public usedRedemptionCode;

  event ArtworkCrafted();

  error TooSimple(uint256 level);
  error CodeRedeemed();
  error InvalidRedemptionCode();

  constructor() payable {
    colorComposition = new ColorComposition();

    address[3] memory colorBands;
    colorBands[0] = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    colorBands[1] = address(new ColorPalette("Canvas", "CVS"));
    colorBands[2] = address(new ColorPalette("Backdrop", "BKDP"));

    ColorPalette(colorBands[1]).mint(address(this), INITIAL_PALETTE);
    ColorPalette(colorBands[2]).mint(address(this), INITIAL_PALETTE);

    hueController = new HueController(colorBands);

    uint[3] memory amounts = [INITIAL_PALETTE, INITIAL_PALETTE, INITIAL_PALETTE];
    IERC20(colorBands[1]).approve(address(hueController), amounts[1]);
    IERC20(colorBands[2]).approve(address(hueController), amounts[2]);
    hueController.enhanceSaturation{value: 100 ether}(amounts);

    uint8 v = 28;
    bytes32 r = hex"0000000000000000000000000000000000000001000000000000000000000000";
    bytes32 s = hex"0000000000000000000000000000000000000001000000000000000000000000";
    usedRedemptionCode[abi.encodePacked(r, s, v)] = true;
  }

  function getColorMaterial(bytes memory redemptionCode) external {
    if (usedRedemptionCode[redemptionCode]) revert CodeRedeemed();
    bytes32 hash = ECDSA.toEthSignedMessageHash(
      abi.encodePacked("Lorem Ipsum")
    );
    if (ECDSA.recover(hash, redemptionCode) != ARTIST) revert InvalidRedemptionCode();

    usedRedemptionCode[redemptionCode] = true;

    ColorPalette(hueController.canvasColors(1)).mint(msg.sender, 1 ether);
    ColorPalette(hueController.canvasColors(2)).mint(msg.sender, 1 ether);
  }

  function _calculateComplexity(uint256 n) internal pure returns (uint256 c) {
    bytes memory s = bytes(Strings.toString(n));
    bool[] memory v = new bool[](10);
    for (uint i; i < s.length; ++i) {
      v[uint8(s[i]) - 48] = true;
    }
    for (uint i; i < 10; ++i) {
      if (v[i]) ++c;
    }
  }

  function getColorCraftLevel() public view returns (uint256) {
    return
      convert(ud(colorComposition.regionalTint() * 1e18).log2()) *
      _calculateComplexity(hueController.getOverallInfo());
  }

  function finalizeArtwork() external {
    uint256 level = getColorCraftLevel();
    if (level < 30) revert TooSimple(level);
    emit ArtworkCrafted();
  }
}