{ inputs, ... }:

{
  imports = [
    inputs.den.flakeModule
    ./schema.nix
    ./lab.nix
    ./entities.nix
  ];
}
