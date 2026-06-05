# Retired host-local Hindsight memory substrate.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hindsightMemory;
  hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
  providerConfig = {
    mode = "local_external";
    api_url = "http://127.0.0.1:8888";
    # Keep a static fallback for older provider versions, but prefer the
    # template below so Hermes profiles do not blend memories into one bank.
    bank_id = "hermes";
    bank_id_template = "hermes-{profile}";
    budget = "mid";
  };
  hindsightConfig = pkgs.writeText "hermes-hindsight-config.json" (builtins.toJSON providerConfig);
in
{
  # Keep the module imported so rollback/history remain readable, but do not
  # start Hindsight or its llama.cpp embedding server by default. Agent Memory
  # is the active memory backend now; Hindsight can be re-enabled explicitly for
  # forensics or migration if needed.
  services.hindsightMemory.enable = lib.mkDefault false;

  services.hermes-agent = lib.mkIf cfg.enable {
    settings.memory.provider = "hindsight";

    # Hindsight also supports env-only config, but the provider gives
    # $HERMES_HOME/hindsight/config.json precedence. Manage that file below so
    # stale interactive setup state cannot silently override this host wiring.
    environment = {
      HINDSIGHT_MODE = providerConfig.mode;
      HINDSIGHT_API_URL = providerConfig.api_url;
      HINDSIGHT_BANK_ID = providerConfig.bank_id;
      HINDSIGHT_BUDGET = providerConfig.budget;
    };
  };

  # Hindsight is a local memory provider, not a Hermes lifecycle dependency.
  # Keep startup ordering when both units are queued, but do not have Hermes pull
  # Hindsight into the transaction; provider failures should degrade memory, not
  # assistant/gateway availability.
  systemd.services.hermes-agent = lib.mkIf cfg.enable {
    after = [ "hindsight-embed.service" ];
  };

  # Recurring refresh, not one-shot: Hindsight's provider config file takes
  # precedence over env vars and may be created by interactive setup. Keep it
  # aligned with the declarative host config, and remove it when the substrate
  # is disabled so rollback returns Hermes to the built-in memory provider.
  system.activationScripts.hermes-hindsight-config = lib.stringAfter [ "hermes-agent-setup" ] (
    if cfg.enable then
      ''
        install -d \
          -o ${config.services.hermes-agent.user} \
          -g ${config.services.hermes-agent.group} \
          -m 0750 \
          ${hermesHome}/hindsight
        install -m 0640 \
          -o ${config.services.hermes-agent.user} \
          -g ${config.services.hermes-agent.group} \
          ${hindsightConfig} ${hermesHome}/hindsight/config.json
      ''
    else
      ''
        rm -f ${hermesHome}/hindsight/config.json
      ''
  );
}
