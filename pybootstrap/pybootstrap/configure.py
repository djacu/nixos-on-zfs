"""A module for configure NixOS root on ZFS nix files."""
import re
#import subprocess
from functools import partial
from pathlib import Path
from typing import List

import questionary

from pybootstrap.prepare import ZfsSystemConfig


def configure(config: ZfsSystemConfig):
    """Setup the NixOS configuration files."""
    generate_system_config()
    # update_config_imports(config=config)
    # add_experimental_features_to_configuration(config=config)
    # enable_network_manager(config=config)
    # remove_systemd_boot_refs(config=config)
    # update_hardware_config(config=config)
    # update_zfs_nix_file(config=config)


def generate_system_config():
    """Auto-generates the NixOS system configuration files."""
    # subprocess.run("nixos-generate-config --root /mnt".split(), check=True)
    
    with open('cmd_configure', 'a') as file:
        file.write("nixos-generate-config --root /mnt")


def update_config_imports(config: ZfsSystemConfig):
    """Replace the auto-generated imports.

    We move the default hardware configuration file so it does not get
    accidentally overwritten by NixOS. We also create a separate
    configuration file for the ZFS pools and datasets.
    """
    config_file = config.nixos.path / config.nixos.config
    old = f"./{config.nixos.hw_old}"
    new = f"./{config.nixos.hw} ./{config.nixos.zfs}"

    with open(config_file, "r", encoding="UTF-8") as file:
        lines = file.readlines()

    newlines = [line.replace(old, new) for line in lines]

    with open(config_file, "w", encoding="UTF-8") as file:
        file.writelines(newlines)


def add_experimental_features_to_configuration(config: ZfsSystemConfig) -> None:
    """Add nix-command and flakes to nix so NixOS is flake ready."""

    config_file = config.nixos.path / config.nixos.config

    with open(config_file, "r", encoding="UTF-8") as file:
        configuration = file.read()

    regex_seq = re.compile(r"(./zfs.nix\n\s*];\n)", re.MULTILINE)
    # \1 pulls the match group from the pattern so we aren't really replacing but appending
    new_text = r'\1\n  nix.settings.experimental-features = "nix-command flakes";\n'
    configuration = regex_seq.sub(new_text, configuration)

    with open(config_file, "w", encoding="UTF-8") as file:
        file.write(configuration)


def enable_network_manager(config: ZfsSystemConfig) -> None:
    """Add nix-command and flakes to nix so NixOS is flake ready."""

    config_file = config.nixos.path / config.nixos.config

    with open(config_file, "r", encoding="UTF-8") as file:
        configuration = file.read()

    old = "# networking.networkmanager.enable"
    new = "networking.networkmanager.enable"
    configuration = configuration.replace(old, new)

    with open(config_file, "w", encoding="UTF-8") as file:
        file.write(configuration)


def remove_systemd_boot_refs(config: ZfsSystemConfig):
    """Removing auto-generated references for boot.loader.

    The configuration file auto-generated by nixos enables systemd-boot
    and allows for EFI variables to be touched. These lines need to be
    removed so we can set things up properly.
    """
    config_file = config.nixos.path / config.nixos.config
    pattern = re.compile("boot.loader")

    with open(config_file, "r", encoding="UTF-8") as file:
        lines = file.readlines()

    newlines = [line for line in lines if not pattern.findall(line)]

    with open(config_file, "w", encoding="UTF-8") as file:
        file.writelines(newlines)


def update_hardware_config(config: ZfsSystemConfig):
    """Updates the hardware-configuration.nix file and changes the
    name."""
    old_path = config.nixos.path / config.nixos.hw_old
    new_path = config.nixos.path / config.nixos.hw

    with open(old_path, "r", encoding="UTF-8") as file:
        lines = file.readlines()

    newlines = list(map(hardware_config_replace, lines))

    if config.part.swap not in ("", "0"):
        newlines = [line for line in newlines if "swapDevices" not in line]

    with open(new_path, "w", encoding="UTF-8") as file:
        file.writelines(newlines)


def hardware_config_replace(line: str):
    """Performs the string keyword replacements for the
    hardware-configuration.nix file."""
    zfs_new = "\n      ".join(
        ('fsType = "zfs";', 'options = [ "zfsutil" "X-mount.mkdir" ];')
    )
    line = line.replace('fsType = "zfs";', zfs_new)

    vfat_new = "\n      ".join(
        (
            'fsType = "vfat";',
            'options = [ "x-systemd.idle-timeout=1min" "x-systemd.automount" "noauto" ];',
        )
    )
    line = line.replace('fsType = "vfat";', vfat_new)

    return line


def update_zfs_nix_file(config: ZfsSystemConfig):
    """Moves the zfs.nix template and updates the string keywords."""
    old_path = Path(__file__).parent / "files" / config.nixos.zfs
    new_path = config.nixos.path / config.nixos.zfs

    with open(old_path, "r", encoding="UTF-8") as file:
        lines = file.readlines()

    newlines = update_zfs_nix_bootloader(lines=lines, config=config)

    host_id = get_machine_id()[:8]
    init_hash = get_initial_hashed_pw()
    nix_replace = partial(
        zfs_nix_replace, config=config, host_id=host_id, init_hash=init_hash
    )
    newlines = list(map(nix_replace, newlines))

    if config.part.swap in ("", "0"):
        newlines = [line for line in newlines if "swapDevices" not in line]
    else:
        swap_list = [
            f'{{ device = "{disk}-part4"; randomEncryption.enable = true; }}'
            for disk in config.zfs.disks
        ]
        swaps = "\n    " + "\n    ".join(swap_list) + "\n  "
        newlines = [line.replace("SWAP_DEVICES", swaps) for line in newlines]

    with open(new_path, "w", encoding="UTF-8") as file:
        file.writelines(newlines)


def update_zfs_nix_bootloader(lines: List[str], config: ZfsSystemConfig) -> List[str]:
    """Replace the bootloader keyword with the bootloader config."""
    match config.bootloader.name:
        case "grub":
            config_file_name = "grub-config"
        case "systemd-boot":
            config_file_name = "systemd-boot-config"
        case _:
            raise ValueError(f"Unknown bootloader: {config.bootloader.name}")

    config_file_path = Path(__file__).parent / "files" / config_file_name

    with open(config_file_path, "r", encoding="UTF-8") as file:
        bootloader_config = file.read()

    single_string = "".join(lines)
    new_string = single_string.replace("  #BOOT_LOADER", bootloader_config)
    delim = "\n"
    return [line + delim for line in new_string.split(delim)]


def zfs_nix_replace(
    line: str, config: ZfsSystemConfig, host_id: str, init_hash: str
) -> str:
    """Performs the string keyword replacements for the zfs.nix file."""
    line = line.replace("HOST_ID", host_id)
    line = line.replace("DEV_NODES", str(Path(config.zfs.primary_disk).parent))
    line = line.replace("PRIMARY_DISK", str(Path(config.zfs.primary_disk).name))

    disks = [f'"{disk}"' for disk in config.zfs.disks]
    disks = "\n      " + "\n      ".join(disks) + "\n    "
    line = line.replace("GRUB_DEVICES", disks)

    line = line.replace("INITIAL_HASHED_PW", init_hash)
    return line


def get_initial_hashed_pw() -> str:
    """Gets an initial password hash."""
    while True:
        password = questionary.password(message="Enter an initial root password.").ask()

        if password:
            break

#    process = subprocess.run(
#        f"mkpasswd -m SHA-512 {password}".split(),
#        capture_output=True,
#        text=True,
#        check=True,
#    )
#
#    return process.stdout.strip()

    with open('cmd_configure', 'a') as file:
        file.write("mkpasswd -m SHA-512 {password}")

    return ""


def get_machine_id() -> str:
    """Gets the host machine ID."""
    with open("/etc/machine-id", "r", encoding="UTF-8") as file:
        machine_id = file.readline()
    return machine_id


if __name__ == "__main__":
    pass
