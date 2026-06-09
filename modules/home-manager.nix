{ pkgs, inputs, ... }:

{
  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.hermes = {
    imports = [ ../home/common.nix ];
    home.stateVersion = "25.05";
  };
}
