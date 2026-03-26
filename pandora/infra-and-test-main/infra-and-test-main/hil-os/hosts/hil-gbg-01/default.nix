{ lib, config, options, ... }:
let
  hostName = "hil-gbg-01";
in
{
  imports = [
    ../../targets/generic/intel
    ../../modules/hil-system
    ../../modules/common/services/hil-runner
    ../../modules/common/qemu
    ../../modules/common/sops
    ../../modules/common/services/remote-desktop
    ../../modules/common/services/nix-cache
  ];

  services.hil-runner = {
    enable = true;
    hostName = hostName;
  };

  virtualization.qemu = {
    enable = true;
    configFile = ../../modules/common/qemu/vm-config.cfg;
  };

  services.remote-desktop = {
    enable = true;
  };

  services.nix-cache = {
    enable = true;
    hostName = hostName;
  };

  networking.hostName = hostName;

}
