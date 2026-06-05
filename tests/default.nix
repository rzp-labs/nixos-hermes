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
  denRoot = denHost.users.root;
  denAdmin = denHost.users.admin;
  denHermes = denHost.users.hermes;
  denPoc = denHost.users.den-poc;

  assertAuthorizedKeys = user: keys: ''
    machine.succeed("test -f /etc/ssh/authorized_keys.d/${user}")
    machine.succeed("grep -cve '^$' /etc/ssh/authorized_keys.d/${user} | grep -qx ${toString (builtins.length keys)}")
    ${builtins.concatStringsSep "\n" (
      map (key: ''
        machine.succeed("grep -Fx '${key}' /etc/ssh/authorized_keys.d/${user}")
      '') keys
    )}
  '';

  denHostVmModule =
    { lib, ... }:
    {
      imports = [
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        hermes-agent.nixosModules.default
        denHost.mainModule
      ];

      # Den renders the real host's SOPS surface. This VM smoke proves VM-safe
      # Den-rendered host/user behavior, not real secret decryption, so keep
      # sops-nix available while preventing real host secret activation.
      sops.age.keyFile = lib.mkForce "/run/age-keys.txt";
      sops.age.sshKeyPaths = lib.mkForce [ ];
      sops.defaultSopsFile = lib.mkForce testSecretsFile;
      systemd.services.sops-nix.enable = false;
      system.activationScripts.setupSecrets = lib.mkForce "";

      systemd.tmpfiles.rules = [
        "d /run/secrets 0755 root root - -"
        "f /run/secrets/omp-auth-broker-token 0600 admin users - dummy-token"
        "f /run/secrets/cliproxyapi-key 0600 agentmemory agentmemory - dummy-key"
        "f /run/secrets/netdata-claim-conf 0600 netdata netdata - dummy-claim"
        "f /run/secrets/hermes-env 0600 hermes hermes - GITHUB_TOKEN=dummy-token"
      ];

      # The general Den host VM smoke does not decrypt or seed real Hermes
      # runtime state. Provisioning scripts are covered by activation-focused
      # VM tests with test secrets.
      system.activationScripts.hermes-soul-md = lib.mkForce "";
      system.activationScripts.hermes-github-auth = lib.mkForce "";

      # The real host creates some groups via imported service modules. This VM
      # declares host-local group targets directly so user assertions stay
      # independent from service migrations.
      users.groups.networkmanager = { };
      users.groups.hermes = { };
      users.users.hermes = {
        isSystemUser = true;
        group = "hermes";
      };

      security.sudo.wheelNeedsPassword = false;
      den.fixtures.denPoc.enable = true;

      # Override docker storage driver and netdata run directory for VM compatibility
      virtualisation.docker.storageDriver = lib.mkForce "overlay2";
      services.netdata.config.global."run directory" = "/run/netdata";
      systemd.services.netdata.serviceConfig.ExecStartPost = lib.mkForce [
        (pkgs.writeShellScript "wait-for-netdata-up-vm" ''
          until [ -S /run/netdata/ipc ] || [ -S /tmp/netdata/ipc ]; do
            sleep 0.5
          done
        '')
      ];
      home-manager.users.den-poc = lib.mkIf denPoc.hasHomeManagerConfig {
        imports = [
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
      ${assertAuthorizedKeys "root" denRoot.sshAuthorizedKeys}
      ${assertAuthorizedKeys "admin" denAdmin.sshAuthorizedKeys}
      ${assertAuthorizedKeys "hermes" denHermes.sshAuthorizedKeys}
      machine.succeed("systemctl is-active --quiet home-manager-admin.service")
      machine.succeed("runuser -u admin -- /etc/profiles/per-user/admin/bin/glow --version")
      machine.succeed("runuser -u admin -- /etc/profiles/per-user/admin/bin/bat --version")
      machine.succeed("runuser -u admin -- script -qec '/etc/profiles/per-user/admin/bin/yazi --version' /tmp/yazi-version >/dev/null 2>&1 && grep -qi 'yazi' /tmp/yazi-version")
      machine.succeed("runuser -u admin -- /etc/profiles/per-user/admin/bin/omp --version")
      machine.succeed("systemctl list-units --plain --state=active 'home-manager-*' | grep -F 'Home Manager environment for den-poc'")
      machine.succeed("test -x /etc/profiles/per-user/den-poc/bin/glow")
      machine.succeed("test -x /etc/profiles/per-user/den-poc/bin/bat")
      machine.succeed("runuser -u den-poc -- /etc/profiles/per-user/den-poc/bin/glow --version")
      machine.succeed("runuser -u den-poc -- /etc/profiles/per-user/den-poc/bin/bat --version")

      # Sudo and Group Membership Verification
      machine.succeed("runuser -u admin -- sudo -n true")
      machine.succeed("id -nG admin | tr ' ' '\\n' | grep -qx docker")
      machine.succeed("id -nG admin | tr ' ' '\\n' | grep -qx libvirtd")

      # Service Activation Verification
      machine.wait_for_unit("docker.service")
      machine.wait_for_unit("libvirtd.service")
      machine.wait_for_unit("netdata.service")
      machine.wait_for_unit("omp-auth-gateway.service")
      machine.wait_for_unit("agentmemory.service")
      machine.wait_for_open_port(4000)
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
      { lib, ... }:
      {
        imports = [
          hermesBaseModule
          denHost.mainModule
        ];

        system.stateVersion = lib.mkForce "25.11";
        sops.age.keyFile = lib.mkForce "/run/age-keys.txt";
        sops.age.sshKeyPaths = lib.mkForce [ ];
        sops.defaultSopsFile = lib.mkForce testSecretsFile;
        sops.secrets = lib.mkForce {
          "hermes-env" = {
            owner = "hermes";
            mode = "0400";
          };
          "hermes-soul-md" = {
            owner = "hermes";
            mode = "0440";
          };
        };
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
