{ lib, pkgs, ... }:
{
  system.stateVersion = "25.05";

  hardware.enableAllFirmware = true;
  environment.systemPackages = with pkgs; [
    age
    curl
    htop
    git
    vim
  ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  networking = {
    networkmanager.enable = true;
    firewall = {
      enable =  true;
    };
  };

  services = {
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "intl";
      };
    };

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        KbdInteractiveAuthentication = true;
      };
    };
  };

  programs = {
    firefox.enable = true;
  };

  time.timeZone = "Europe/Stockholm";
  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" "sv_SE.UTF-8/UTF-8" ];
    extraLocaleSettings = {
      LC_MEASUREMENT = "sv_SE.UTF-8";
      LC_NUMERIC = "sv_SE.UTF-8";
      LC_TIME = "sv_SE.UTF-8";
    };
  };

  nix.settings = {
    trusted-users = [ "esab" "infra" ];
    experimental-features = "nix-command flakes";  # Enable the use of `nix` and `nix flake` commands
  };

  users = {
    mutableUsers = false;
    users.esab = {
      isNormalUser = true;
      description = "Developer";
      group = "users";
      extraGroups = [ "wheel" "networkmanager" "docker" "libvirtd" ];
      initialPassword = "esab";
    };

    users.infra = {
      isNormalUser = true;
      description = "Infra & Test";
      group = "users";
      extraGroups = [ "wheel" "networkmanager" "docker" "libvirtd" ];
      initialPassword = "godzilla";
    };

  };

  # Disable all forms of sleep/suspend
  systemd = {
    targets = {
      sleep = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
      suspend = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
      hibernate = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
      "hybrid-sleep" = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
    };
  };
}
