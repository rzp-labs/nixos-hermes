{ pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ../../modules/service.nix
  ];

  environment.systemPackages = [
    (pkgs.callPackage ../../packages/app { })
  ];

  system.stateVersion = "26.05";
}
