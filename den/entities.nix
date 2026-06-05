{ config, inputs, ... }:

let
  host = config.den.hosts.x86_64-linux.nixos-hermes;
  admin = host.users.admin;
  hermes = host.users.hermes;
  root = host.users.root;
  denPoc = host.users.den-poc;
in
{
  den.hosts.x86_64-linux.nixos-hermes = {
    moduleImports = [
      "hosts/hermes/hardware.nix"
      "hosts/hermes/disk-config.nix"
      "hosts/hermes/sops.nix"
      "hosts/hermes/provision.nix"
      "hosts/hermes/virtualisation.nix"
      "hosts/hermes/llama-server.nix"
      "hosts/hermes/hindsight-embed.nix"
      "hosts/hermes/hindsight-memory.nix"
      "hosts/hermes/agentmemory.nix"
      "hosts/hermes/netdata.nix"
      "hosts/hermes/omp-auth-gateway.nix"
      "modules/system.nix"
      "modules/packages.nix"
      "modules/home-manager.nix"
      "modules/hermes-agent.nix"
      "modules/hermes-plugins.nix"
      "modules/users.nix"
    ];

    serviceModules = [
      "hosts/hermes/llama-server.nix"
      "hosts/hermes/hindsight-embed.nix"
      "hosts/hermes/hindsight-memory.nix"
      "hosts/hermes/agentmemory.nix"
      "hosts/hermes/netdata.nix"
      "hosts/hermes/omp-auth-gateway.nix"
      "modules/hermes-agent.nix"
      "modules/hermes-plugins.nix"
    ];

    sharedModules = [
      "modules/system.nix"
      "modules/packages.nix"
      "modules/home-manager.nix"
      "modules/users.nix"
    ];

    nixpkgsHostPlatform = "x86_64-linux";
    hostId = "52dd4e5a";
    stateVersion = "25.05";
    trustedUsers = [ "admin" ];
    timeZone = "America/Phoenix";
    defaultLocale = "en_US.UTF-8";
    consoleKeyMap = "us";
    systemPackages = [
      "curl"
      "wget"
      "git"
      "man"
      "htop"
      "iotop"
      "tree"
      "jq"
      "python3"
      "ripgrep"
      "unzip"
      "gh"
      "bun"
      "fh"
      "repowise"
      "repowise-nix"
      "llm-agents.cli-proxy-api"
      "llm-agents.but"
      "uv"
    ];
    storage.zfs = true;

    users.root = {
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQ0xpYd/EJnMyHW36xmWodb0DPoMHf4LpQAl7xheMRE"
      ];
    };

    users.admin = {
      normalUser = true;
      description = "System Admin";
      hasHomeManagerConfig = true;
      home = "/home/admin";
      createHome = true;
      homeMode = "700";
      extraGroups = [
        "wheel"
        "networkmanager"
        "hermes"
      ];
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG3neF+6qsDFb1pwr06mdW0mqMcxquAGNsjbGiG/Rj23"
      ];
      classes = [ "homeManager" ];
    };

    users.hermes = {
      description = "Hermes account";
      hasHomeManagerConfig = true;
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0inarJ3Em+01Y22ahDmJkbhevhwuFFrWyIEl0CjkzE"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBN6C8GPyeaAKWwkSqNXzDDQEzeGQ21IWGhAa+xFqNIHlQ7uDNA/9wc8A4tXO3ckp7seY+84aXAAyCQyfrrmKSbQ= #ssh.id"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCBs4KwCYyBZxsb02nyw9tRMsgOtfBuyM3mBh4varuvKc4JO4rzN1Iq2cXHyy0ttYIaDg52iPWlTM+O6pdpvVcE= #ssh.id"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNWfcMlHqWVodM+9A5ZnVEvw7zkDJMHW2cUw4Ru4v+8a3ot+QHH038uLkTl95SIL5XaKslAqe+gyqcZ4X6BPhtA= #ssh.id"
      ];
      classes = [ "homeManager" ];
    };

    # VM-only fixture used to prove same-user mixed Den/native Home Manager
    # migration. It is not production inventory.
    users.den-poc = {
      normalUser = true;
      hasHomeManagerConfig = true;
      home = "/home/den-poc";
      createHome = true;
      classes = [ "homeManager" ];
    };
  };

  den.aspects.nixos-hermes.os =
    { lib, pkgs, ... }:
    let
      vitePlusToolchain = with pkgs; [
        nodejs
        (pkgs.vite-plus or pkgs.hello)
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
      sharedUserConfig = {
        manual.manpages.enable = false;
        programs.bash.enable = true;
        programs.bash.initExtra = vitePlusBashInit;
      };
      direnvConfig = {
        programs.direnv.enable = true;
        programs.direnv.nix-direnv.enable = true;
      };
    in
    let
      # VM tests use the nixpkgs instance supplied by nixosTest, not the full
      # host overlay stack. Fall back to hello there; the live host eval below
      # proves the real overlaid package attrs resolve on nixos-hermes.
      packageByName = name: lib.attrByPath (lib.splitString "." name) pkgs.hello pkgs;
    in
    {
      networking.hostName = host.name;
      networking.hostId = host.hostId;
      nix.settings.trusted-users = host.trustedUsers;
      system.stateVersion = host.stateVersion;

      time.timeZone = host.timeZone;
      i18n.defaultLocale = host.defaultLocale;
      console.keyMap = host.consoleKeyMap;

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

      services.dbus.implementation = "dbus";
      security.sudo.wheelNeedsPassword = false;
      environment.systemPackages = builtins.map packageByName host.systemPackages;
      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

      users.users.root.openssh.authorizedKeys.keys = root.sshAuthorizedKeys;
      users.users.admin = {
        isNormalUser = admin.normalUser;
        inherit (admin)
          description
          home
          createHome
          homeMode
          extraGroups
          ;
        openssh.authorizedKeys.keys = admin.sshAuthorizedKeys;
      };
      users.users.hermes = {
        inherit (hermes) description;
        openssh.authorizedKeys.keys = hermes.sshAuthorizedKeys;
      };
      users.users.den-poc = {
        isNormalUser = denPoc.normalUser;
        inherit (denPoc) home createHome;
      };

      home-manager.users.admin = pkgs.lib.recursiveUpdate sharedUserConfig direnvConfig // {
        home = vitePlusHome // {
          stateVersion = "25.05";
          packages =
            (with pkgs; [
              bat
              glow
              yazi
              inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp
            ])
            ++ vitePlusToolchain;
          sessionVariables = {
            XDG_DATA_HOME = "$HOME/.local/share";
            XDG_STATE_HOME = "$HOME/.local/state";
            XDG_CACHE_HOME = "$HOME/.cache";
            XDG_CONFIG_HOME = "$HOME/.config";
          };
        };
      };
      home-manager.users.hermes = sharedUserConfig // {
        home = vitePlusHome // {
          stateVersion = "25.05";
          packages = vitePlusToolchain;
        };
      };
      home-manager.users.den-poc = {
        home.stateVersion = "25.05";
        home.packages = [ pkgs.glow ];
      };
    };
}
