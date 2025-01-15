{
  description = "A proxy utility for playdate";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-24.11";
  inputs.playdate-sdk.url = "github:RegularTetragon/playdate-sdk-flake";

  outputs =
    {
      nixpkgs,
      playdate-sdk,
      ...
    }:
    let
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
        ] (system: function nixpkgs.legacyPackages.${system});

      genBuildInputs =
        pkgs: with pkgs; [
          playdate-sdk.packages.x86_64-linux.default
          gcc-arm-embedded-13
          zig_0_13
          python3
          python3Packages.serialio
          python3Packages.pwntools
        ];

      PLAYDATE_SDK_PATH = "${playdate-sdk.packages.x86_64-linux.default}";
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          buildInputs = genBuildInputs pkgs;
          inherit PLAYDATE_SDK_PATH;
          ARM_GCC_PATH = "${pkgs.gcc-arm-embedded-13}";
        };
      });
    };
}
