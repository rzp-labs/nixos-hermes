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
