{ lib, pkgs, config, inputs, ... }:
let
  cfg = config.services.nix-cache;
  nixStored = inputs.nix-stored.packages.${pkgs.system}.default;
  cachePruneScript = pkgs.writeShellScriptBin "cache-prune" (builtins.readFile ./cache-prune.sh);
  nixStoredPath = "/var/lib/nix-stored";
in
{
  options.services.nix-cache = {
    enable = lib.mkEnableOption "Enable Nix binary cache and key generation";
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The hostname for the cache key";
      example = "hil-gbg-01";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP address for nix-stored to listen on";
    };
    listenPort = lib.mkOption {
      type = lib.types.int;
      default = 8100;
      description = "Port for nix-stored to listen on";
    };
    pruneInterval = lib.mkOption {
      type = lib.types.str;
      default = "quarterly";
      description = "How often to completely clear the cache (systemd timer format)";
    };
  };

  config = lib.mkIf cfg.enable {

    # Make NIX_STORED_PATH available globally for manual script execution
    environment.variables = {
      NIX_STORED_PATH = nixStoredPath;
    };

    environment.etc."nix/generate-cache-key.sh" = {
      source = pkgs.writeShellScript "generate-cache-key.sh" ''
        set -e
        if [ ! -f /etc/nix/cache-priv-key.pem ]; then
          ${pkgs.nix}/bin/nix-store --generate-binary-cache-key ${cfg.hostName} /etc/nix/cache-priv-key.pem /etc/nix/cache-pub-key.pem
          ${pkgs.coreutils}/bin/chmod 0400 /etc/nix/cache-priv-key.pem
        fi
      '';
    };

    systemd.services.generate-nix-cache-key = {
      description = "Generate Nix binary cache key if missing";
      wantedBy = [ "nix-stored.service" ];
      before = [ "nix-stored.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "/etc/nix/generate-cache-key.sh";
      };
    };

    systemd.services.prune-nix-cache = {
      description = "Completely clear nix-stored cache";
      environment = {
        NIX_STORED_PATH = nixStoredPath;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cachePruneScript}/bin/cache-prune --restart-service";
        ExecStartPost = "${pkgs.systemd}/bin/systemctl restart nix-stored.service";
        User = "root";

        Nice = "19";
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = "7";
        OOMScoreAdjust = "200";
      };

      path = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.systemd
      ];
    };

    systemd.timers.prune-nix-cache = {
      description = "Timer for nix-stored cache pruning";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.pruneInterval;
        Persistent = true;  # Run missed timers on boot
        RandomizedDelaySec = "1h";  # Add some randomization to avoid load spikes
      };
    };

    systemd.services.nix-stored = {
      description = "Nix binary cache server (nix-stored)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "generate-nix-cache-key.service" ];
      requires = [ "generate-nix-cache-key.service" ];

      environment = {
        NIX_STORED_LISTEN_INTERFACE = "${cfg.listenAddress}:${toString cfg.listenPort}";
        NIX_STORED_PATH = nixStoredPath;
      };

      serviceConfig = {
        ExecStart = "${nixStored}/bin/nix-stored";
        DynamicUser = true;
        StateDirectory = "nix-stored";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    environment.systemPackages = [
      cachePruneScript
      pkgs.coreutils
      pkgs.findutils
    ];
  };
}
