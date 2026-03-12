{ lib, config, options, pkgs, ... }:
{
  imports = [
    ../../targets/raspberry/pi5
    ../../modules/hil-system
  ];

  networking.hostName = "hil-rpi5";
}
