{ lib, config, ... }:
{
  imports = [
    ../../../hardware/cpu/intel
    ../../../hardware/disk
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  hardware.disk = {
    enable = true;
    root = "/dev/nvme0n1";
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "vmd" "nvme" "usbhid" "usb_storage" "sd_mod"  ];
      kernelModules = [];
    };

    kernelModules = [ "kvm_intel" ];
    extraModulePackages = [];
  };
}
