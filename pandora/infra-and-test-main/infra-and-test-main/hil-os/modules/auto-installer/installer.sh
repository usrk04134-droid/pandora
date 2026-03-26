#!/usr/bin/env bash

set -eEx
function trap_err () {
    echo "Error in Automated NixOS installer"
    read -rs -p "Paused, press enter to reboot ..."
    echo ""
    reboot
}
trap trap_err ERR

result=""
export DIALOG_ESC=0

until [[ -n "$result" ]]; do
    result=$(dialog --title "WARNING: INSTALLATION WILL WIPE YOUR COMPUTER!" \
    --backtitle "HIL OS Unattended installer" \
    --output-fd 1 \
    --colors \
    --no-cancel \
    --ok-label "Continue" \
    --item-help \
    --menu "\nPlease select installation type" \
    13 60 3 \
    0 "Abort" "Exit from the installer and reboot"\
    1 "Reinstall - \Zb\Z1WIPE '/'!\Zn" "Clean the '/' volume on @disk.nixos.device@ and \ZbOVERWRITE\Zn all its data, keeping any other volumes intact" \
    2 "Clean install - \Zb\Z1WIPE DISK!\Zn" "\Zb\Z1\ZuWIPE\Zn @disk.nixos.device@ completely and remove all volumes" \
    )
done

# Use disko to partition target

if [[ "$result" == "1" ]]; then
    echo "Reinstallation requested, will OVERWRITE '/' on disk!"

    function install_failed () {
    MSG=$1
    dialog --title "Installation failed" \
        --backtitle "HIL OS Unattended installer" \
        --no-cancel \
        --pause \
        "\nInstallation failed\n\n$MSG" \
        13 60 60
    reboot
    }

    # Verify that btrfs based HIL OS was previously installed
    # Check that nixos partition exists
    DEV="@part.nixos.device@"
    [[ -e "$DEV" ]] ||
    install_failed "Root volume $DEV does not exist, please do clean install"

    # Check that nixos partition is btrfs
    FS=$(lsblk -n -o FSTYPE "$DEV")
    [[ "btrfs" == "$FS" ]] ||
    install_failed "Root volume $DEV does not have BTRFS filesystem ($FS), please do clean install"

    # TODO: Should verify that we have a HIL OS install somehow

    echo "Restoring initial snapshots of the initial filesystem"
    (
        MNTPOINT=$(mktemp -d)
        mount "@part.nixos.device@" "$MNTPOINT"
        trap 'umount "$MNTPOINT"; rmdir "$MNTPOINT"' EXIT
        SNAPSHOTS="$MNTPOINT/.snapshots"
        EPHEMERAL="$MNTPOINT/@/@cfg.btrfsEphemeralGroup@"
        SUBVOLS=$(btrfs subvolume list -a --sort=-path "$MNTPOINT" | grep "/@/@cfg.btrfsEphemeralGroup@/" | cut -d@ -f2- | cut -d/ -f3-)

        for SUBVOL in $SUBVOLS; do
            btrfs subvolume delete -c "$EPHEMERAL/$SUBVOL"
            # Not all subvolumes have snapshots (some are created by nixos-installer)
            btrfs subvolume snapshot "$SNAPSHOTS/$SUBVOL-blank" "$EPHEMERAL/$SUBVOL" || true
        done

        btrfs subvolume sync "$MNTPOINT"
    )

    # Disko mode set to `mount`: mount existing fs and perform reinstall
    ./@build.mount@/bin/disko-mount

elif [[ "$result" == "2" ]]; then
    echo "Fresh installation requested, will WIPE @disk.nixos.device@!"

    # Disko mode set to `destroy,format,mount`: create new partition table, format and mount
    ./@build.destroyFormatMount@/bin/disko-destroy-format-mount --yes-wipe-all-disks

    echo "Creating initial snapshots of the new filesystem"
    (
        MNTPOINT=$(mktemp -d)
        mount "@part.nixos.device@" "$MNTPOINT"
        trap 'umount "$MNTPOINT"; rmdir "$MNTPOINT"' EXIT
        SNAPSHOTS="$MNTPOINT/.snapshots"
        mkdir "$SNAPSHOTS"
        EPHEMERAL="$MNTPOINT/@/@cfg.btrfsEphemeralGroup@"
        SUBVOLS=$(btrfs subvolume list -o "$EPHEMERAL" | cut -d@ -f2- | cut -d/ -f3-)

        for SUBVOL in $SUBVOLS; do
            btrfs subvolume snapshot -r "$EPHEMERAL/$SUBVOL" "$SNAPSHOTS/$SUBVOL-blank"
        done
    )

else
    dialog --title "Installation aborted" \
    --backtitle "HIL OS Unattended installer" \
    --no-cancel \
    --pause \
    "\nInstallation aborted\n\nWill reboot" \
    13 60 60
    reboot
fi

# Install system
nixos-install --root /mnt --system "@build.toplevel@" --no-root-password

# Reboot
dialog --title "Installation done" \
    --backtitle "HIL OS Unattended installer" \
    --no-cancel \
    --pause \
    "\nUnattended installation completed\n\nWill reboot to finalize installation" \
    13 60 60
reboot
