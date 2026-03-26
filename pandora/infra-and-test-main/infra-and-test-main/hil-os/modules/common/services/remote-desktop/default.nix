{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.services.remote-desktop;
in
{
  options.services.remote-desktop = {
    enable = mkEnableOption "Enable remote desktop access via XRDP";

    port = mkOption {
      type = types.port;
      default = 3389;
      description = "Port for XRDP service";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall port for XRDP";
    };

    rdpUser = mkOption {
      type = types.str;
      default = "infra";
      description = "Primary user for RDP sessions";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Enable XRDP
      services.xrdp = {
        enable = true;
        port = cfg.port;
        defaultWindowManager = "startplasma-x11";
      };

      # Open firewall port
      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

      environment.systemPackages = with pkgs; [
        xrdp
        xorg.xauth
        xorg.xhost
        kdePackages.plasma-workspace
        kdePackages.kscreen
        kdePackages.systemsettings
      ];

      # Configure RDP user (add to existing user)
      users.users.${cfg.rdpUser} = {
        extraGroups = [ "video" "input" "tsusers" ];
      };

      # Logind configuration to prevent session conflicts
      services.logind = {
        settings = {
          Login = {
            HandlePowerKey = "poweroff";
            RemoveIPC = false;
            KillUserProcesses = false;
          };
        };
      };

      # Create .xsession file
      system.activationScripts.createXSession = let
        xsessionContent = ''
          #!/bin/bash
          [ -f /etc/profile ] && . /etc/profile
          [ -f ~/.profile ] && . ~/.profile

          export XDG_SESSION_TYPE=x11
          export XDG_CURRENT_DESKTOP=KDE
          export DESKTOP_SESSION=plasma
          export KDE_FULL_SESSION=true
          export KDE_SESSION_VERSION=6

          exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-x11
        '';
        userHome = "/home/${cfg.rdpUser}";
      in ''
        mkdir -p "${userHome}"
        cat > "${userHome}/.xsession" << 'EOF'
        ${xsessionContent}
      EOF
        chmod +x "${userHome}/.xsession"
        chown ${cfg.rdpUser}:users "${userHome}/.xsession"
      '';

      # Polkit is needed for KDE
      security.polkit.enable = true;

      # Basic fonts
      fonts.enableDefaultPackages = true;
      fonts.packages = with pkgs; [
        dejavu_fonts
        liberation_ttf
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
      ];
    }
  ]);
}
