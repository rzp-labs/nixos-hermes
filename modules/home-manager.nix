{ pkgs, ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.admin = {
    home.stateVersion = "25.05";

    home.packages = with pkgs; [
      bat # syntax-highlighted cat replacement
      glow # markdown renderer for the terminal
      yazi # terminal file manager
      llm-agents.omp # terminal-based multi-model coding agent
      nodejs # NixOS-compatible runtime for Vite+
      vite-plus
    ];

    home.sessionPath = [
      "$HOME/.vite-plus/bin"
    ];

    programs.bash.initExtra = ''
      if [ -f "$HOME/.vite-plus/env" ]; then
        . "$HOME/.vite-plus/env"
      fi
    '';
  };
}
