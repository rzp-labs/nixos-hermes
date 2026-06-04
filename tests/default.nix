# tests/default.nix — NixOS VM test suite
#
# Run individual tests with:
#   nix build .#checks.x86_64-linux.activation-github-auth
#
# These tests require QEMU — they run unprivileged via nixosTest.
# Consult the testing ladder in AGENTS.md to decide which tool is
# appropriate for the change you are making.
{
  pkgs,
  nixpkgs,
  sops-nix,
  hermes-agent,
  home-manager,
  denModel,
}:

let
  # Throwaway age key for test secrets — committed intentionally.
  # This key encrypts only dummy test values, never real secrets.
  testAgeKeyFile = ./assets/age-test-key.txt;
  testSecretsFile = ./assets/test-secrets.yaml;

  # Shared base config for tests that need the hermes-agent activation
  # scripts. Imports the real upstream module with the service enabled so
  # hermes-agent-setup runs exactly as it does on the live host. The agent
  # binary will not start (no valid config/secrets for the service) but
  # activation scripts run before systemd units and succeed independently.
  hermesBaseModule =
    { config, ... }:
    {
      imports = [
        sops-nix.nixosModules.sops
        hermes-agent.nixosModules.default
      ];

      # Inject test age key via initrd — required because sops.age.keyFile
      # rejects paths inside the Nix store (world-readable). Copying through
      # boot.initrd.secrets places the key outside the store before activation
      # and works with systemd stage 1.
      boot.initrd.secrets."run/age-keys.txt" = testAgeKeyFile;

      sops.age.keyFile = "/run/age-keys.txt";
      sops.age.sshKeyPaths = [ ];
      sops.defaultSopsFile = testSecretsFile;
      sops.secrets."hermes-env" = {
        owner = "hermes";
        mode = "0400";
      };
      sops.secrets."hermes-soul-md" = {
        owner = "hermes";
        mode = "0440";
      };

      # Minimal hermes-agent config — enough to run hermes-agent-setup
      # and hermes-github-auth activation scripts.
      services.hermes-agent = {
        enable = true;
        # Suppress missing required options with stub values
        authFile = pkgs.writeText "test-auth.json" (
          builtins.toJSON {
            version = 1;
            providers = { };
            credential_pool = { };
          }
        );
        environmentFiles = [ config.sops.secrets."hermes-env".path ];
        settings.model = {
          default = "test-model";
          provider = "test-provider";
        };
      };

      # Required for nixosTest
      system.stateVersion = "25.11";
    };

  # Target closure switched to by vm-switch-smoke. Build this outside the
  # guest and carry it in the initial VM closure so the smoke proves switch
  # activation behavior instead of guest-side Nix evaluation, binary-cache
  # access, DNS, or upstream fetches.
  vmSwitchTarget = nixpkgs.lib.nixosSystem {
    modules = [
      (pkgs.path + "/nixos/modules/virtualisation/qemu-vm.nix")
      (pkgs.path + "/nixos/modules/testing/test-instrumentation.nix")
      {
        nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
        boot.loader.grub.enable = false;
        boot.loader.systemd-boot.enable = false;
        networking.hostName = "vm-switch-smoke";
        system.nixos.label = "vm-switch-smoke";
        environment.etc."agent-workflow-switch-marker".text = "after-switch\n";
        system.stateVersion = "25.11";
      }
    ];
  };

  denHost = denModel.den.hosts.x86_64-linux.nixos-hermes;
  denAdmin = denHost.users.admin;
  denHermes = denHost.users.hermes;
  denPoc = denHost.users.den-poc;

  denHostVmModule =
    { lib, ... }:
    {
      imports = [ home-manager.nixosModules.home-manager ];

      networking.hostName = denHost.name;
      system.stateVersion = denHost.stateVersion;
      services.openssh.enable = true;

      users.mutableUsers = false;
      # The real host creates some groups via imported service modules. This
      # VM harness declares Den-modeled group targets directly so user-shape
      # assertions remain independent from unrelated service migrations.
      users.groups.networkmanager = { };
      users.users.admin = {
        isNormalUser = denAdmin.normalUser;
        home = lib.mkIf (denAdmin.home != null) denAdmin.home;
        createHome = lib.mkIf (denAdmin.createHome != null) denAdmin.createHome;
        homeMode = lib.mkIf (denAdmin.homeMode != null) denAdmin.homeMode;
        extraGroups = denAdmin.extraGroups;
        openssh.authorizedKeys.keys = lib.mkIf denAdmin.sshAuthorizedKeysConfigured [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDenVmAdminKeyForShapeOnly000000000000000000"
        ];
      };
      users.groups.hermes = { };
      users.users.hermes = {
        isSystemUser = true;
        group = "hermes";
        openssh.authorizedKeys.keys = lib.mkIf denHermes.sshAuthorizedKeysConfigured [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDenVmHermesKeyForShapeOnly00000000000000000"
        ];
      };
      users.users.den-poc = {
        isNormalUser = denPoc.normalUser;
        home = lib.mkIf (denPoc.home != null) denPoc.home;
        createHome = lib.mkIf (denPoc.createHome != null) denPoc.createHome;
      };

      security.sudo.wheelNeedsPassword = false;
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.admin = lib.mkIf denAdmin.hasHomeManagerConfig {
        home.stateVersion = denHost.stateVersion;
      };
      home-manager.users.hermes = lib.mkIf denHermes.hasHomeManagerConfig {
        home.stateVersion = denHost.stateVersion;
      };
      home-manager.users.den-poc = lib.mkIf denPoc.hasHomeManagerConfig {
        imports = [
          ((builtins.elemAt denModel.den.aspects.den-poc.homeManager.__contentValues 0).value {
            inherit pkgs;
          })
          # Native Home Manager config deliberately remains alongside the
          # Den-rendered module for the same user. This proves per-user
          # incremental migration, not just different users on different paths.
          {
            home.packages = [ pkgs.bat ];
          }
        ];
      };
    };

in
{
  # Test: build a VM from the Den-modeled host/user facts. This is the
  # iteration harness for Den refactors: when a host module is migrated into a
  # Den aspect, add its VM-safe assertions here before using the live host.
  den-host-vm-smoke = pkgs.testers.runNixOSTest {
    name = "den-host-vm-smoke";

    nodes.machine = denHostVmModule;

    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("hostname | grep -qx nixos-hermes")
      machine.succeed("getent passwd admin >/dev/null")
      machine.succeed("getent passwd hermes >/dev/null")
      machine.succeed("getent passwd den-poc >/dev/null")
      machine.succeed("id -nG admin | tr ' ' '\\n' | grep -qx wheel")
      machine.succeed("id -nG admin | tr ' ' '\\n' | grep -qx networkmanager")
      machine.succeed("id -nG admin | tr ' ' '\\n' | grep -qx hermes")
      machine.succeed("test -d /home/admin")
      machine.succeed("stat -c%a /home/admin | grep -qx 700")
      machine.succeed("test -f /etc/ssh/authorized_keys.d/admin")
      machine.succeed("test -f /etc/ssh/authorized_keys.d/hermes")
      machine.succeed("test -L /etc/profiles/per-user/admin")
      machine.succeed("test -L /etc/profiles/per-user/hermes")
      machine.succeed("test -L /etc/profiles/per-user/den-poc")
      machine.succeed("test -x /etc/profiles/per-user/den-poc/bin/glow")
      machine.succeed("test -x /etc/profiles/per-user/den-poc/bin/bat")
      machine.succeed("runuser -u den-poc -- /etc/profiles/per-user/den-poc/bin/glow --version")
      machine.succeed("runuser -u den-poc -- /etc/profiles/per-user/den-poc/bin/bat --version")
    '';
  };

  # Test: switch to a prebuilt target inside a guest and verify an
  # activation-visible change. This catches changes that build cleanly but
  # only fail when switch-to-configuration runs, without depending on guest
  # network/cache access for nixos-rebuild evaluation.
  vm-switch-smoke = pkgs.testers.runNixOSTest {
    name = "vm-switch-smoke";

    nodes.machine =
      { ... }:
      {
        networking.hostName = "vm-switch-smoke";
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
        environment.etc."agent-workflow-switch-marker".text = "before-switch\n";
        virtualisation.memorySize = 2048;
        virtualisation.additionalPaths = [ vmSwitchTarget.config.system.build.toplevel ];
        system.stateVersion = "25.11";
      };

    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("grep -qx before-switch /etc/agent-workflow-switch-marker")

      machine.succeed(
          "${vmSwitchTarget.config.system.build.toplevel}/bin/switch-to-configuration switch"
      )
      machine.succeed("grep -qx after-switch /etc/agent-workflow-switch-marker")
      machine.succeed(
          "test \"$(readlink -f /run/current-system)\" = \"${vmSwitchTarget.config.system.build.toplevel}\""
      )
    '';
  };

  # Test: hermes-github-auth activation script
  # Verifies the script correctly writes git and gh credentials from sops secret.
  activation-github-auth = pkgs.testers.runNixOSTest {
    name = "activation-github-auth";

    nodes.machine =
      { ... }:
      {
        imports = [
          hermesBaseModule
          ../hosts/hermes/provision.nix
        ];
      };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      # File must exist
      machine.succeed("test -f /var/lib/hermes/.git-credentials")

      # Mode must be 600
      machine.succeed(
          "stat -c%a /var/lib/hermes/.git-credentials | grep -qx 600"
      )

      # Owner must be hermes
      machine.succeed(
          "stat -c%U /var/lib/hermes/.git-credentials | grep -qx hermes"
      )

      # Content must be correct — token contains = signs (tests cut -d= -f2- fix)
      machine.succeed(
          "grep -qF 'https://yui-hermes:TEST_TOKEN_WITH_EQUALS_AAA1234567890==suffix@github.com'"
          " /var/lib/hermes/.git-credentials"
      )

      # gh config must exist with private permissions and be readable by gh.
      machine.succeed("test -f /var/lib/hermes/.config/gh/hosts.yml")
      machine.succeed("stat -c%a /var/lib/hermes/.config/gh | grep -qx 700")
      machine.succeed(
          "stat -c%a /var/lib/hermes/.config/gh/hosts.yml | grep -qx 600"
      )
      machine.succeed(
          "stat -c%U /var/lib/hermes/.config/gh/hosts.yml | grep -qx hermes"
      )
      machine.succeed("test -f /var/lib/hermes/.config/gh/config.yml")
      machine.succeed(
          "stat -c%a /var/lib/hermes/.config/gh/config.yml | grep -qx 600"
      )
      machine.succeed(
          "stat -c%U /var/lib/hermes/.config/gh/config.yml | grep -qx hermes"
      )
      machine.succeed(
          "grep -qF 'user: yui-hermes' /var/lib/hermes/.config/gh/hosts.yml"
      )
      machine.succeed(
          "grep -qF 'git_protocol: https' /var/lib/hermes/.config/gh/hosts.yml"
      )
      machine.succeed(
          "runuser -u hermes -- sh -c 'HOME=/var/lib/hermes ${pkgs.gh}/bin/gh auth token'"
          " | grep -qx 'TEST_TOKEN_WITH_EQUALS_AAA1234567890==suffix'"
      )
    '';
  };
}
