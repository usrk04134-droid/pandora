{ lib, pkgs, config, ... }:
let
  cfg = config.services.hil-runner;
  token = "$(cat ${config.sops.secrets."hosts/${cfg.hostName}/runner-registration-token".path})";

in {
  options.services.hil-runner = {
    enable = lib.mkEnableOption "Enable Gitlab Runner Module";
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The name of the host where the runner is installed";
      example = "hil-gbg-01";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl."net.ipv4.ip_forward" = true;
    virtualisation.docker.enable = true;
    environment.etc."gitlab-runner/registration".text = ''
        CI_SERVER_URL="https://gitlab.com"
        CI_SERVER_TOKEN=${token}
        '';

    services.gitlab-runner = {
      enable = true;  # Enable installation and registration
      settings = {
        check_interval = 3;
      };
      services.hil= {
          authenticationTokenConfigFile = "/etc/gitlab-runner/registration";
          executor = "docker";
          dockerImage = "alpine:latest";
          registrationFlags = [
            "--docker-network-mode host"
            "--docker-privileged"
          ];
          dockerVolumes = [
            "/etc/nix/cache-priv-key.pem:/etc/nix/cache-priv-key.pem:ro"
            "/etc/nix/cache-pub-key.pem:/etc/nix/cache-pub-key.pem:ro"
          ];
          environmentVariables = {
            HIL_CACHE_PUB_KEY_FILE = "/etc/nix/cache-pub-key.pem";
            HIL_CACHE_SIGNING_KEY_FILE = "/etc/nix/cache-priv-key.pem";
            HIL_CACHE_URL = "http://127.0.0.1:8100/";
          };
      };
    };
    systemd.services.gitlab-runner = {
      serviceConfig = {
        DynamicUser = lib.mkForce false;  # Register runner in system mode
      };
    };
  };
}
