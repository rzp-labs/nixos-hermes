# apps/default.nix — flake apps for a single dev system.
#
# Install-time CLIs (nixos-anywhere, disko) are exposed so they use the same
# lockfile pin as the NixOS modules. Linux-only operational smokes wrap shell
# scripts under ../tools. Invoke with:
#   nix run .#nixos-anywhere -- --flake .#nixos-hermes ...
#   nix run .#disko -- --mode disko hosts/hermes/disk-config.nix
{
  pkgs,
  lib,
  system,
  nixos-anywhere,
  disko,
}:
let
  prePrVerify = pkgs.writeShellApplication {
    name = "pre-pr-verify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.nix
      pkgs.nixos-rebuild
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${../tools/pre-pr-verify.sh} "$@"
    '';
  };
  hindsightContinuitySmoke = pkgs.writeShellApplication {
    name = "hindsight-continuity-smoke";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
      pkgs.systemd
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${../tools/hindsight-continuity-smoke.sh} "$@"
    '';
  };
in
{
  nixos-anywhere = {
    type = "app";
    program = "${nixos-anywhere.packages.${system}.nixos-anywhere}/bin/nixos-anywhere";
  };
  disko = {
    type = "app";
    program = "${disko.packages.${system}.disko}/bin/disko";
  };
}
// lib.optionalAttrs (system == "x86_64-linux") {
  pre-pr-verify = {
    type = "app";
    program = "${prePrVerify}/bin/pre-pr-verify";
  };
  hindsight-continuity-smoke = {
    type = "app";
    program = "${hindsightContinuitySmoke}/bin/hindsight-continuity-smoke";
  };
}
