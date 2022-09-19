{
  config,
  pkgs,
  ...
}: {
  boot.supportedFilesystems = ["zfs"];
  networking.hostId = "HOST_ID";
  boot.zfs.devNodes = "DEV_NODES";
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  swapDevices = [SWAP_DEVICES];
  systemd.services.zfs-mount.enable = false;
  environment.etc."machine-id".source = "/state/etc/machine-id";
  environment.etc."zfs/zpool.cache".source = "/state/etc/zfs/zpool.cache";
  boot.loader.efi.efiSysMountPoint = "/boot/efis/PRIMARY_DISK-part1";

  # boot loader specific config
  #BOOT_LOADER
  users.users.root.initialHashedPassword = "INITIAL_HASHED_PW";
}
