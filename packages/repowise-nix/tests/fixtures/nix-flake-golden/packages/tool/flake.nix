{
  description = "Nested local tool flake";

  outputs =
    { self }:
    {
      packages.x86_64-linux.default = ./default.nix;
    };
}
