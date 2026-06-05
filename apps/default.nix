# apps/default.nix — flake apps for a single dev system.
#
# Install-time CLIs (nixos-anywhere, disko) are exposed so they use the same
# lockfile pin as the NixOS modules. Linux-only operational smokes wrap shell
# scripts under ../tools. Invoke with:
#   nix run .#nixos-anywhere -- --flake .#nixos-hermes ...
#   nix run .#disko-hermes
{
  pkgs,
  lib,
  system,
  nixos-anywhere,
  disko,
  hostDiskoDevices,
}:
let
  diskoPackage = disko.packages.${system}.disko;
  hostDiskoConfig = pkgs.writeText "nixos-hermes-disko.nix" ''
    { ... }:
    {
      disko.devices = builtins.fromJSON ${builtins.toJSON hostDiskoDevices};
    }
  '';
in
{
  nixos-anywhere = {
    type = "app";
    program = "${nixos-anywhere.packages.${system}.nixos-anywhere}/bin/nixos-anywhere";
  };
  disko = {
    type = "app";
    program = "${diskoPackage}/bin/disko";
  };
  disko-hermes = {
    type = "app";
    program = "${
      pkgs.writeShellApplication {
        name = "disko-hermes";
        runtimeInputs = [ diskoPackage ];
        text = ''
          exec disko --mode disko ${hostDiskoConfig} "$@"
        '';
      }
    }/bin/disko-hermes";
  };
}
// lib.optionalAttrs (system == "x86_64-linux") (
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
    pre-pr-verify = {
      type = "app";
      program = "${prePrVerify}/bin/pre-pr-verify";
    };
    hindsight-continuity-smoke = {
      type = "app";
      program = "${hindsightContinuitySmoke}/bin/hindsight-continuity-smoke";
    };
  }
)
