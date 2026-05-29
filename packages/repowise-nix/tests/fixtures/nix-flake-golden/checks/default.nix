{ runCommand }:
runCommand "golden-check" { } ''
  touch $out
''
