# Remote Desktop Module

This NixOS module configures remote desktop access via XRDP, specifically tailored for a KDE Plasma 6 desktop environment.

## Features

- Enables the `xrdp` service.
- Configures `xrdp` to use `startplasma-x11` as the window manager.
- Opens the necessary firewall port for XRDP.
- Adds the specified RDP user to the necessary groups for remote access (`video`, `input`, `tsusers`).
- Configures `logind` to prevent session conflicts between local and remote sessions.
- Creates an `.xsession` file for the RDP user to ensure a Plasma 6 session starts correctly.
- Enables Polkit, which is required for KDE Plasma.
- Installs a basic set of fonts for a good user experience.

## Options

All options are configured under `services.remote-desktop`.

| Option         | Type    | Default  | Description                                                                    |
|----------------|---------|----------|--------------------------------------------------------------------------------|
| `enable`       | boolean | `false`  | Enable or disable the remote desktop module.                                   |
| `port`         | port    | `3389`   | The port for the XRDP service to listen on.                                    |
| `openFirewall` | boolean | `true`   | Whether to automatically open the XRDP port in the firewall.                   |
| `rdpUser`      | string  | `"infra"`| The primary user for RDP sessions. This user must already be defined.          |

## Usage

To use this module, import it into your NixOS configuration and enable it.

Here is an example for a host configuration:

```nix
{ lib, config, ... }:

{
  imports = [
    # ... other imports
    ./path/to/modules/common/services/remote-desktop
  ];

  # ... other system configuration

  services.remote-desktop = {
    enable = true;
    rdpUser = "myuser";
  };
}
```

### Notes

- This module is designed to work alongside an existing local desktop environment (like the Plasma 6 setup in `hil-system`) without interference.
- The user specified in `rdpUser` must be defined elsewhere in your configuration. This module only adds supplementary groups to that user.
- The `.xsession` file is created via an `activationScript`. It will overwrite any existing `.xsession` file in the user's home directory.
