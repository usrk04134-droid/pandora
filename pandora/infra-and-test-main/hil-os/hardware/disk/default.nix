{ lib, config, ... }:
let
  cfg = config.hardware.disk;
in {
  options.hardware.disk = {
    enable = lib.mkEnableOption "Unattended disko disk setup";

    root = lib.mkOption {
      default = "/dev/nvme0n1";
      type = with lib.types; str;
      description = "Sets the system disk";
    };

    withSwap = lib.mkOption {
      default = true;
      type = with lib.types; bool;
      description = "Enables swap partition";
    };

    swapSize = lib.mkOption {
      default = "32G";
      type = with lib.types; str;
      description = "Sets the swap size if swap is enabled";
    };
  };

  config = lib.mkIf cfg.enable {
    disko.devices.disk = {
      nixos = {
        type = "disk";
        device = cfg.root;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            nixos = {
              size = "100%";
              content = {
                type = "btrfs";
                mountpoint = "/.partition-root";
                subvolumes = {
                  "@" = {
                    # Default subvolume, not mounted
                  };
                  "@/ephemeral" = {
                    # Ephemeral subvolumes group root, not mounted
                  };
                  "@/home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" ];
                  };
                  "@/persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "compress=zstd" ];
                  };
                  "@/ephemeral/root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@/ephemeral/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@/ephemeral/var-lib" = {
                    mountpoint = "/var/lib";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@/ephemeral/var-log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@/ephemeral/var-tmp" = {
                    mountpoint = "/var/tmp";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                } // lib.optionalAttrs cfg.withSwap {
                  "@/swap" = {
                    mountpoint = "/.swap";
                    swap = {
                      swapfile.size = cfg.swapSize;
                      #randomEncryption = true;
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
    fileSystems."/persist".neededForBoot = true;
  };
}
