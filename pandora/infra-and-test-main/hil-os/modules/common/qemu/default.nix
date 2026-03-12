{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.virtualization.qemu;
  forceUser = "esab";
  forceGroup = "users";
in
{
  options.virtualization.qemu = {
    enable = mkEnableOption "QEMU virtualization with Samba shared folders";

    sharedPath = mkOption {
      type = types.str;
      default = "/persist/qemu/shared-files";
      description = "Path to the shared directory for QEMU VMs";
    };

    configPath = mkOption {
      type = types.str;
      default = "/persist/qemu";
      description = "Path where QEMU configuration files will be stored";
    };

    configFile = mkOption {
      type = types.path;
      description = "Path to the QEMU configuration file";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      qemu_kvm
      qemu
    ];

    # Configure Samba service for QEMU shared folders
    services.samba = {
      enable = true;
      settings = {
        global = {
          workgroup = "WORKGROUP";
          "server string" = "HIL PC Samba Server";
          security = "user";
          "map to guest" = "bad user";
          "guest account" = "nobody";
        };
        qemu-shared = {
          path = cfg.sharedPath;
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "create mask" = "0664";
          "directory mask" = "0775";
          "force user" = forceUser;
          "force group" = forceGroup;
        };
      };
    };

    # Open firewall for Samba access from VMs
    networking.firewall = {
      allowedTCPPorts = [ 139 445 ];
      allowedUDPPorts = [ 137 138 ];
    };

    # Ensure shared directory path exists for QEMU VMs
    # Copy the specified configuration file to the configPath
    systemd.tmpfiles.rules = [
      "d ${cfg.configPath} 0755 ${forceUser} ${forceGroup} - -"
      "d ${cfg.sharedPath} 0755 ${forceUser} ${forceGroup} - -"
      "C ${cfg.configPath}/vm-config.cfg 0664 ${forceUser} ${forceGroup} - ${cfg.configFile}"
    ];
  };
}
