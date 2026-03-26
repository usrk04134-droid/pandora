{ lib, config, pkgs, modulesPath, ... }:
let
  cfg = config.auto-installer;
  target = cfg.target;
  build = target.config.system.build;
  disk = target.config.disko.devices.disk;
  part = disk.nixos.content.partitions;
  subvol = part.nixos.content.subvolumes;
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")
  ];

  options.auto-installer = {
    enable = lib.mkEnableOption "Automated NixOS installer, using disko to partition and nixos-install";
    target = lib.mkOption {
      type = lib.types.attrs;
      description = "A nixosSystem target";
      example = "nixosConfigurations.<host>";
    };
    btrfsEphemeralGroup = lib.mkOption {
      type = lib.types.str;
      description = "The btrfs subvolume group under which ephemeral subvolumes resides";
      example = "ephemeral";
      default = "ephemeral";
    };
    hilName = lib.mkOption {
      type = lib.types.str;
      description = "The name of the HIL";
      example = "hil-gbg-01";
    };
  };

  config = lib.mkIf cfg.enable {
    isoImage = {
      makeEfiBootable = true;
      makeUsbBootable = true;
      squashfsCompression = "zstd -Xcompression-level 3";
    };

    console.keyMap = "us";

    users.users.root.initialHashedPassword = "";

    environment.systemPackages = with pkgs; [
      dialog
      btrfs-progs
    ];

    systemd.services.auto-installer = {
      description = "Unattended HIL OS installer";

      wantedBy = [ "default.target" ];

      requiredBy = [ "systemd-logind.service" "getty@tty1.service" ];

      before = [ ];

      after = [ "network.target" ];

      conflicts = [ ];

      serviceConfig = {
        Type="oneshot";
        RemainAfterExit="yes";
        ExecStartPre="/run/current-system/sw/bin/chvt 13";
        ExecStartPost="/run/current-system/sw/bin/chvt 1";
        StandardInput="tty";
        StandardOutput="inherit";
        StandardError="inherit";
        TTYPath=/dev/tty13;
        TTYReset="yes";
        TTYHangup="yes";
      };

      path = [ "/run/current-system/sw" ];

      environment = config.nix.envVars // {
        inherit (config.environment.sessionVariables) NIX_PATH;
        HOME = "/root";
      };

      script = (builtins.replaceStrings [
          "@disk.nixos.device@"
          "@part.nixos.device@"
          "@cfg.btrfsEphemeralGroup@"
          "@build.toplevel@"
          "@build.mount@"
          "@build.destroyFormatMount@"
        ]
        [
          "${disk.nixos.device}"
          "${part.nixos.device}"
          "${cfg.btrfsEphemeralGroup}"
          "${build.toplevel}"
          "${build.mount}"
          "${build.destroyFormatMount}"
        ]
        (builtins.readFile ./installer.sh)
      );
    };
  };
}
