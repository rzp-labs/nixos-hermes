{ writeShellApplication }:
writeShellApplication {
  name = "golden-app";
  text = ''
    echo golden
  '';
}
