# NixOS flake for HIL PC

This *flake.nix* builds custom nixos iso with unattended installer.

## Usage

1. **Ensure you're in the hil-os directory**:

   If not, navigate to it.

   ```bash
   cd hil-os/
   ```

1. **Build ISO**:

   ```bash
   nix build .#hil-gbg-<ID>-installer
   ```

1. **The resulting iso will be placed in ./result/iso**:

   ```bash
   ls ./result/iso
   ```

1. **Write to Disk**

   ```bash
   # Write to disk
   # To find the device name of available drive, included an external usb drive, use:
   # lsblk
   # To write the iso image to an external drive, use "dd" (be careful to specify of="the external(!) device")
   # Example:
   # sudo dd bs=4M status=progress if=result/iso/hilos-auto-installer.iso of=/dev/sda oflag=sync
   sudo dd bs=4M status=progress if=<path/to/iso/file> of=<path/to/dev> oflag=sync
   ```

## Remote build

```bash
nixos-rebuild switch --sudo --target-host <USER>@<HOST> --flake ".#hil-gbg-<ID>"
```

If the computer that you are trying to install from is not running NixOS, the script will fail due to missing nixos-rebuild command. This can be solved by running the command in a nix shell.

```bash
nix shell nixpkgs#nixos-rebuild
```

After the rebuild is complete, the target host must be rebooted for the new configuration to be activated.
