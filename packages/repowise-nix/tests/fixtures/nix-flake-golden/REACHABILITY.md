# Golden Nix reachability fixture

| Case | Source | Referenced path | Expected resolved file | Expected dead-code behavior |
|---|---|---|---|---|
| flake package output | `packages.x86_64-linux.default` | `./packages/app` | `packages/app/default.nix` | live |
| flake app output | `apps.x86_64-linux.default` | `self.packages...` | `flake.nix` / package output | live root |
| flake check output | `checks.x86_64-linux.smoke` | `./checks` | `checks/default.nix` | live |
| formatter output | `formatter.x86_64-linux` | `./checks` | `checks/default.nix` | live |
| local flake input | `inputs.local-tool.url` | `path:./packages/tool` | `packages/tool/flake.nix` | live |
| NixOS configuration module | `nixosConfigurations.golden.modules` | `./hosts/golden/configuration.nix` | `hosts/golden/configuration.nix` | live |
| NixOS import-list module | `configuration.nix` | `./hardware.nix` | `hosts/golden/hardware.nix` | live |
| NixOS import-list module | `configuration.nix` | `../../modules/service.nix` | `modules/service.nix` | live |
| NixOS callPackage package | `configuration.nix` | `../../packages/app` | `packages/app/default.nix` | live |
| intentionally unused Nix file | none | `docs/unused-notes.nix` | none | remains reportable |
