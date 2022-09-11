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
  boot.loader.efi.canTouchEfiVariables = false;
  # if UEFI firmware can detect entries
  # boot.loader.efi.canTouchEfiVariables = true;

  boot.loader = {
    generationsDir.copyKernels = true;
    # for problematic UEFI firmware
    grub.efiInstallAsRemovable = true;
    grub.enable = true;
    grub.version = 2;
    grub.copyKernels = true;
    grub.efiSupport = true;
    grub.zfsSupport = true;
    # for systemd-autofs
    grub.extraPrepareConfig = ''
      mkdir -p /boot/efis
      for i in /boot/efis/*; do mount $i ; done
    '';
    grub.extraInstallCommands = ''
      export ESP_MIRROR=$(mktemp -d -p /tmp)
      cp -r /boot/efis/PRIMARY_DISK-part1/EFI $ESP_MIRROR
      for i in /boot/efis/*; do
        cp -r $ESP_MIRROR/EFI $i
      done
      rm -rf $ESP_MIRROR
    '';
    grub.devices = [GRUB_DEVICES];
  };
  users.users.root.initialHashedPassword = "INITIAL_HASHED_PW";
}
