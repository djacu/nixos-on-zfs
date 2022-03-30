#!/bin/bash


# Generate initial NixOS system configuration
nixos-generate-config --root /mnt
# This command will generate two files, configuration.nix and
# hardware-configuration-zfs.nix, which will be the starting
# point of configuring the system.


# Edit config file to import ZFS options
sed -i "s|./hardware-configuration.nix|./hardware-configuration-zfs.nix ./${INST_CONFIG_FILE}|g" /mnt/etc/nixos/configuration.nix
# backup, prevent being overwritten by nixos-generate-config
mv /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration-zfs.nix


# ZFS options
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
{ config, pkgs, ... }:

{ boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "$(head -c 8 /etc/machine-id)";
  boot.zfs.devNodes = "${INST_PRIMARY_DISK%/*}";
EOF

# ZFS datasets should be mounted with -o zfsutil option
sed -i 's|fsType = "zfs";|fsType = "zfs"; options = [ "zfsutil" "X-mount.mkdir" ];|g' \
/mnt/etc/nixos/hardware-configuration-zfs.nix

# Allow EFI system partition mounting to fail at boot
sed -i 's|fsType = "vfat";|fsType = "vfat"; options = [ "x-systemd.idle-timeout=1min" "x-systemd.automount" "noauto" ];|g' \
/mnt/etc/nixos/hardware-configuration-zfs.nix

# Restrict kernel to versions supported by ZFS
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
EOF

# Disable cache
mkdir -p /mnt/state/etc/zfs/
rm -f /mnt/state/etc/zfs/zpool.cache
touch /mnt/state/etc/zfs/zpool.cache
chmod a-w /mnt/state/etc/zfs/zpool.cache
chattr +i /mnt/state/etc/zfs/zpool.cache


# If swap is enabled
if [ "${INST_PARTSIZE_SWAP}" != "" ]; then
sed -i '/swapDevices/d' /mnt/etc/nixos/hardware-configuration-zfs.nix

tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
  swapDevices = [
EOF
for i in $DISK; do
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
    { device = "$i-part4"; randomEncryption.enable = true; }
EOF
done
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
  ];
EOF
fi


# For immutable root file system, save machine-id and other files
mkdir -p /mnt/state/etc/{ssh,zfs}
systemd-machine-id-setup --print > /mnt/state/etc/machine-id
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
  systemd.services.zfs-mount.enable = false;
  environment.etc."machine-id".source = "/state/etc/machine-id";
  environment.etc."zfs/zpool.cache".source = "/state/etc/zfs/zpool.cache";
  boot.loader.efi.efiSysMountPoint = "/boot/efis/${INST_PRIMARY_DISK##*/}-part1";
EOF


# Configure systemd boot loader
sed -i '/boot.loader/d' /mnt/etc/nixos/configuration.nix
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<-'EOF'
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
EOF
