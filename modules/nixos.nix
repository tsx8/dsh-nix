# NixOS module for DeepSeek Harness (`dsh`).
#
# This module only installs the package into the system environment. All
# user configuration (`$DSH_HOME`, `profiles`, `skills`, `agentPresets`,
# `cordisPatch`) stays user-level and is managed by the Home Manager module
# (`modules/home-manager.nix`), which picks up this module's package through
# its read-only `finalPackage` when the HM `package` is `null`.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.deepseek-harness;
in
{
  options.programs.deepseek-harness = {
    enable = lib.mkEnableOption "DeepSeek Harness";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../packages/deepseek-harness/package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../packages/deepseek-harness/package.nix { }";
      description = ''
        The DeepSeek Harness package installed into the system environment.
        Home Manager's `programs.deepseek-harness.finalPackage` resolves to
        this package when its own `package` is `null`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
