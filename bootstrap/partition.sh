#!/bin/bash

# Wipe solid-state drives with the generic tool blkdiscard, to clean
# previous partition tables and improve performance.
function wipe_disks() {
    for i in ${DISK}; do
        blkdiscard -f $i &
    done
    wait
}

echo "Wipe solid-state drive (recommended)?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) wipe_disks; break;;
        No ) break;;
    esac
done


# Partition the disks.
for i in ${DISK}; do
    # Zap (destroy) the GPT and MBR data structures and then exit.
    sgdisk --zap-all $i
    # ESP partition
    sgdisk -n 1:1M:+${INST_PARTSIZE_ESP}G -t1:EF00 $i
    # Boot pool partition
    sgdisk -n 2:0:+${INST_PARTSIZE_BPOOL}G -t2:BE00 $i
    # Swap partition if specified
    if [ "${INST_PARTSIZE_SWAP}" != "" ]; then
        sgdisk -n 4:0:+${INST_PARTSIZE_SWAP}G -t4:8200 $i
    fi
    # Root partition. Size specified or rest of disk if not.
    if [ "${INST_PARTSIZE_RPOOL}" = "" ]; then
        sgdisk -n 3:0:0   -t3:BF00 $i
    else
        sgdisk -n 3:0:+${INST_PARTSIZE_RPOOL}G -t3:BF00 $i
    fi
    # Legacy boot
    sgdisk -a1 -n 5:24K:+1000K -t5:EF02 $i
done


# Create the boot pool
disk_num=0;
for i in $DISK; do
    disk_num=$(( $disk_num + 1 ));
done
if [ $disk_num -gt 1 ]; then
    INST_VDEV_BPOOL=mirror;
fi

zpool create \
    -o compatibility=grub2 \
    -o ashift=13 \
    -o autotrim=on \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=lz4 \
    -O devices=off \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/boot \
    -R /mnt \
    bpool_$INST_UUID \
    $INST_VDEV_BPOOL \
    $(for i in ${DISK}; do
        printf "$i-part2 ";
    done)


# Create the root pool
zpool create \
    -o ashift=13 \
    -o autotrim=on \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=zstd \
    -O dnodesize=auto \
    -O encryption=aes-256-gcm \
    -O keylocation=prompt \
    -O keyformat=passphrase \
    -O normalization=formD \
    -O relatime=on \
    -O xattr=sa \
    -O mountpoint=/ \
    -R /mnt \
    rpool_$INST_UUID \
    $INST_VDEV \
    $(for i in ${DISK}; do
        printf "$i-part3 ";
    done)


# Encrypt the system dataset. Pick a strong password.
# Once compromised, changing password will not keep your data safe.
# See zfs-change-key(8) for more info.
zfs create \
    -o canmount=off \
    -o mountpoint=none \
    -o encryption=aes-256-gcm \
    -o keylocation=prompt \
    -o keyformat=passphrase \
    rpool_$INST_UUID/$INST_ID
