"""A module for installing NixOS root on ZFS."""
from glob import glob
import subprocess

from pybootstrap.prepare import ZfsSystemConfig


def install(config: ZfsSystemConfig):
    rpool_id = f"rpool_{config.zfs.pool_uuid}"
    bpool_id = f"bpool_{config.zfs.pool_uuid}"

    rpool_nix = f"{rpool_id}/{config.zfs.os_id}"
    bpool_nix = f"{bpool_id}/{config.zfs.os_id}"

    subprocess.run(f"zfs snapshot -r {rpool_nix}@install_start".split(), check=True)
    subprocess.run(f"zfs snapshot -r {bpool_nix}@install_start".split(), check=True)

    nixos_install = "nixos-install -v --show-trace --no-root-passwd --root /mnt"
    subprocess.run(nixos_install.split(), check=True)

    subprocess.run(f"zfs snapshot -r {rpool_nix}@install".split(), check=True)
    subprocess.run(f"zfs snapshot -r {bpool_nix}@install".split(), check=True)

    # efis = ' '.join(glob.glob('/mnt/boot/efis/*'))
    # subprocess.run(f'umount {efis}'.split(), check=True)
    subprocess.run("umount /mnt/boot/efis/*", shell=True, check=True)

    subprocess.run(f"zpool export {bpool_id}".split(), check=True)
    subprocess.run(f"zpool export {rpool_id}".split(), check=True)
