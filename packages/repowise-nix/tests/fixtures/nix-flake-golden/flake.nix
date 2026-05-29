{
  description = "Repowise Nix reachability golden fixture";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    local-tool.url = "path:./packages/tool";
  };

  outputs =
    {
      self,
      nixpkgs,
      local-tool,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system}.default = pkgs.callPackage ./packages/app { };
      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/golden-app";
      };
      checks.${system}.smoke = pkgs.callPackage ./checks { };
      formatter.${system} = pkgs.callPackage ./checks { };
      nixosConfigurations.golden = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./hosts/golden/configuration.nix ];
      };
    };
}
