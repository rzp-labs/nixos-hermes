{ pkgs, ... }:

{
  time.timeZone = "America/Phoenix";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  services.power-profiles-daemon.enable = false;
  services.thermald.enable = true;
  services.printing.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];

  services.openssh.enable = true;
  services.openssh.hostKeys = [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

  # Keep broad release-line updates from also migrating the live host from
  # dbus-daemon to dbus-broker. NixOS 26.05 defaults to broker, but switching
  # an already-running system can leave the old dbus-daemon under a new
  # Type=notify-reload unit and make `nixos-rebuild test` time out reloading
  # user/system buses. Migrate D-Bus separately with reboot-shaped validation.
  services.dbus.implementation = "dbus";

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    curl
    wget
    git
    man
    htop
    iotop
    tree
    jq
    python3
    ripgrep
    unzip
    gh
    bun
    fh
    repowise
    repowise-nix
    llm-agents.cli-proxy-api
    llm-agents.but
    uv # Python package manager — required for hindsight-embed setup
  ];

  environment.sessionVariables = {
    # HERMES_HOME and HERMES_MANAGED are owned by the hermes-agent module;
    # do not declare them here.
    LIBVA_DRIVER_NAME = "iHD";
  };
}
