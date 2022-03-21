#!/bin/bash
# Import external functions
this_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$this_dir/funcs/parts.sh"
source "$this_dir/funcs/disk.sh"
source "$this_dir/funcs/math.sh"

# Unique pool suffix. ZFS expects pool names to be unique,
# therefore it’s recommended to create pools with a unique suffix
INST_UUID=$(dd if=/dev/urandom bs=1 count=100 2>/dev/null | tr -dc 'a-z0-9' | cut -c-6)

# Identify this installation in ZFS filesystem path
INST_ID=nixos

# Root on ZFS configuration file name
INST_CONFIG_FILE='zfs.nix'

# Define the disk by-id path for re-use
DEV_DISK=/dev/disk/by-id

# Lists the disk devices by ID
# Asks the user to specify desired devices
echo ""
DISK=$(ask_user_for_disks)

# Choose a primary disk.
# This disk will be used for primary EFI partition, default to first disk in the array.
INST_PRIMARY_DISK=$(echo $DISK | cut -f1 -d\ )


echo "Set vdev topology. Possible options are:"
select INST_VDEV in "single" "mirror" "raidz1" "raidz2" "raidz3";
do
    echo "vdev selected as $INST_VDEV"
    case $INST_VDEV in
        single ) unset INST_VDEV; break;;
        mirror | raidz1 | raidz2 | raidz3 ) break;;
    esac

done


# Set the ESP partition size.
set_partition_size INST_PARTSIZE_ESP "ESP" 2

# Set boot pool size. To avoid running out of space while using boot
# environments, the minimum is 4GB. Adjust the size if you intend to use
# multiple kernel/distros.
set_partition_size INST_PARTSIZE_BPOOL "boot pool" 4

# Set swap size. It’s recommended to setup a swap partition. If you
# intend to use hibernation, the minimum should be no less than RAM
# size. Skip if swap is not needed.
SYSTEM_MEM=$(ceil $(get_system_memory -s gibi))
set_partition_size INST_PARTSIZE_SWAP "swap" $SYSTEM_MEM

# Root pool size, use all remaining disk space if not set.
set_partition_size INST_PARTSIZE_RPOOL "root pool"
