{ ... }:

{
  sops.defaultSopsFile = ../../../../hosts/hermes/secrets/hermes-secrets.yaml;
  sops.age.keyFile = "/etc/secrets/age.key";
  # The SSH host key is itself a sops-managed secret; using it as an age
  # identity creates a circular dependency. Use only the age key file.
  sops.age.sshKeyPaths = [ ];

  sops.secrets = {

    # Stable SSH host key — same fingerprint survives rebuilds.
    # sops-nix decrypts and places this at runtime; no pre-placement needed.
    ssh_host_ed25519_key = {
      sopsFile = ../../../../hosts/hermes/secrets/ssh_host_ed25519_key.enc;
      format = "binary";
      owner = "root";
      mode = "0600";
      path = "/etc/ssh/ssh_host_ed25519_key";
    };

    # Combined env file for hermes-agent: ELEVENLABS_API_KEY, DISCORD_BOT_TOKEN,
    # OPENROUTER_API_KEY, LINEAR_API_KEY, etc.
    # Value is a newline-delimited KEY=value file; merged into $HERMES_HOME/.env
    # at activation time by the hermes-agent module.
    "hermes-env" = {
      owner = "hermes";
      mode = "0400";
    };

    # Bearer token shared by the loopback OMP auth broker and gateway.
    # The broker API is localhost-only, but keeping this token declarative
    # avoids sysd correctness depending on mutable `omp auth-broker token`
    # state under /home/admin.
    omp-auth-broker-token = {
      owner = "admin";
      mode = "0400";
    };

    # API key for the LAN CLIProxyAPI endpoint used by local OpenAI-compatible
    # LLM providers. The key is consumed at runtime by managed services, not
    # written into the Nix store.
    cliproxyapi-key = {
      sopsFile = ../../../../hosts/hermes/secrets/cliproxyapi-key.enc;
      format = "binary";
      owner = "agentmemory";
      group = "agentmemory";
      mode = "0400";
    };

    # Agent personality — encrypted so contents remain private in the public repo.
    # Decrypted by sops-nix at activation; the hermes-soul-md script provisions
    # it to $HERMES_HOME on first boot only.
    hermes-soul-md = {
      sopsFile = ../../../../hosts/hermes/secrets/soul.md;
      format = "binary";
      owner = "hermes";
      mode = "0440";
    };

    # Netdata Cloud claim.conf. Contains the cloud URL, claim token, and room
    # binding; installed into /etc/netdata/claim.conf by netdata.service.
    netdata-claim-conf = {
      sopsFile = ../../../../hosts/hermes/secrets/netdata-claim.conf;
      format = "binary";
      owner = "root";
      group = "netdata";
      mode = "0440";
    };

  };
}
