{ pkgs, ... }:

{
  manual.manpages.enable = false;

  programs.bash = {
    enable = true;
    initExtra = ''
      if [ -f "$HOME/.vite-plus/env" ]; then
        . "$HOME/.vite-plus/env"
      fi
    '';
  };

  home = {
    sessionPath = [
      "$HOME/.vite-plus/bin"
    ];
    packages = with pkgs; [
      nodejs
      vite-plus
    ];
  };
}
