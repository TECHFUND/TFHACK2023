pragma solidity 0.8.19;

contract ColorComposition {
  enum Style {
    None,
    Swatches,
    SwatchesAndTextures
  }

  struct ColorCompositionSettings {
    Style style;
    bool blendingActivated;
  }

  struct ColorRegion {
    ColorCompositionSettings settings;
    bytes data;
  }

  uint256 public globalTint = 60;
  uint256 public regionalTint = 60;

  mapping(string => ColorRegion[]) public colorRegions;

  error Overdose();
  error QualityControl();

  constructor() {
    ColorCompositionSettings memory compositionSettings = ColorCompositionSettings({style: Style.None, blendingActivated: false});
    ColorRegion[] storage colorRegion = colorRegions["Palette"];
    colorRegion.push(ColorRegion({settings: compositionSettings, data: bytes("part1")}));
    colorRegion.push(ColorRegion({settings: compositionSettings, data: bytes("part2")}));
    colorRegion.push(ColorRegion({settings: compositionSettings, data: bytes("part3")}));
  }

  function setTint(uint256 _tint) external {
    if (_tint > 233) revert Overdose();
    globalTint = _tint;
  }

  function adjustComposition() external {
    if (!colorRegions["Palette"][2].settings.blendingActivated) revert QualityControl();
    regionalTint = globalTint;
  }

  function modifySettings(uint256 parameter, uint256 value) external {
    if (parameter <= 39) revert Overdose();
    assembly {
      sstore(parameter, value)
    }
  }
}