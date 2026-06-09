{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  home = {
    username = "admin";
    homeDirectory = "/home/admin";
    stateVersion = "25.05";
    packages = with pkgs; [
      bat
      glow
      yazi
      llm-agents.omp
    ];
    sessionVariables = {
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
