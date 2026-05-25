{
  autoPatchelfHook,
  coreutils,
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "vite-plus";
  version = "0.1.22";

  src = fetchurl {
    url = "https://registry.npmjs.org/@voidzero-dev/vite-plus-cli-linux-x64-gnu/-/vite-plus-cli-linux-x64-gnu-${version}.tgz";
    hash = "sha256-l/NWIy+DoUxjPJYyhzyxy3HZf2kEglZuyBPW87rSvj4=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm0755 vp $out/libexec/vite-plus/vp
    mkdir -p $out/bin
    cat > $out/bin/vp <<EOF
    #!${stdenv.shell}
    real_vp="$out/libexec/vite-plus/vp"

    repair_vite_plus_shims() {
      vp_home="\''${VP_HOME:-\$HOME/.vite-plus}"
      [ -d "\$vp_home/bin" ] || return 0

      for tool in vp node npm npx vpx vpr; do
        shim="\$vp_home/bin/\$tool"
        if [ -L "\$shim" ] && [ "\$(${coreutils}/bin/readlink "\$shim")" = "../current/bin/vp" ]; then
          ${coreutils}/bin/ln -sfn "$out/bin/vp" "\$shim"
        fi
      done
    }

    if [ "\''${1-}" = "env" ] && [ "\''${2-}" = "setup" ]; then
      repair_vite_plus_shims
      "\$real_vp" "\$@"
      repair_vite_plus_shims
      exit 0
    fi

    exec -a "\$0" "\$real_vp" "\$@"
    EOF
    chmod 0755 $out/bin/vp
    ln -s vp $out/bin/vpx
    ln -s vp $out/bin/vpr
    runHook postInstall
  '';

  meta = {
    description = "Vite+ unified toolchain CLI for the web";
    homepage = "https://viteplus.dev";
    license = lib.licenses.mit;
    mainProgram = "vp";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
