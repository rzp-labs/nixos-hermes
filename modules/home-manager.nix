{ pkgs, ... }:

let
  vitePlusToolchain = with pkgs; [
    nodejs # NixOS-compatible runtime for Vite+
    vite-plus
  ];

  vitePlusHome = {
    sessionPath = [
      "$HOME/.vite-plus/bin"
    ];
  };

  vitePlusBashInit = ''
    if [ -f "$HOME/.vite-plus/env" ]; then
      . "$HOME/.vite-plus/env"
    fi
  '';
in
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.admin = {
    manual.manpages.enable = false;

    home = vitePlusHome // {
      stateVersion = "25.05";
      packages =
        (with pkgs; [
          bat # syntax-highlighted cat replacement
          glow # markdown renderer for the terminal
          yazi # terminal file manager
          llm-agents.omp # terminal-based multi-model coding agent
        ])
        ++ vitePlusToolchain;
      sessionVariables = {
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_STATE_HOME = "$HOME/.local/state";
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_CONFIG_HOME = "$HOME/.config";
      };
    };

    programs.bash.enable = true;
    programs.bash.initExtra = vitePlusBashInit;
  };

  home-manager.users.hermes = {
    manual.manpages.enable = false;

    home = vitePlusHome // {
      stateVersion = "25.05";
      packages = vitePlusToolchain;
    };

    programs.bash.enable = true;
    programs.bash.initExtra = vitePlusBashInit;
  };
}
