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


# Create ROOT datasets
zfs create -o canmount=off -o mountpoint=none rpool_$INST_UUID/$INST_ID/ROOT
zfs create -o mountpoint=/ -o canmount=noauto rpool_$INST_UUID/$INST_ID/ROOT/default
zfs mount rpool_$INST_UUID/$INST_ID/ROOT/default


# Create BOOT datasets
zfs create -o canmount=off -o mountpoint=none bpool_$INST_UUID/$INST_ID
zfs create -o canmount=off -o mountpoint=none bpool_$INST_UUID/$INST_ID/BOOT
zfs create -o mountpoint=/boot -o canmount=noauto bpool_$INST_UUID/$INST_ID/BOOT/default
zfs mount bpool_$INST_UUID/$INST_ID/BOOT/default


# Create DATA datasets
zfs create -o canmount=off -o mountpoint=none   rpool_$INST_UUID/$INST_ID/DATA

# Create dataset for mounting /nix
zfs create -o mountpoint=/ -o canmount=off      rpool_$INST_UUID/$INST_ID/DATA/local
for i in {nix,}; do
    zfs create -o canmount=on -o mountpoint=/$i rpool_$INST_UUID/$INST_ID/DATA/local/$i
done

# Create user datasets / shared datasets / persistent datasets
zfs create -o mountpoint=/ -o canmount=off      rpool_$INST_UUID/$INST_ID/DATA/default

for i in {usr,var,var/lib};
do
    zfs create -o canmount=off                  rpool_$INST_UUID/$INST_ID/DATA/default/$i
done

for i in {home,root,srv,usr/local,var/log,var/spool};
do
    zfs create -o canmount=on                   rpool_$INST_UUID/$INST_ID/DATA/default/$i
done
chmod 750 /mnt/root

# Create a state dataset for saving mutable data in case an immutable file system is used
zfs create -o canmount=on                       rpool_$INST_UUID/$INST_ID/DATA/default/state
for i in {/etc/nixos,/etc/cryptkey.d}; do
  mkdir -p /mnt/state/$i /mnt/$i
  mount -o bind /mnt/state/$i /mnt/$i
done


# Create an `empty` dataset to use as an original snapshot for an immutable file system.
zfs create -o mountpoint=/ -o canmount=noauto rpool_$INST_UUID/$INST_ID/ROOT/empty
zfs snapshot rpool_$INST_UUID/$INST_ID/ROOT/empty@start


# Format and mount ESP
for i in ${DISK}; do
    mkfs.vfat -n EFI ${i}-part1
    mkdir -p /mnt/boot/efis/${i##*/}-part1
    mount -t vfat ${i}-part1 /mnt/boot/efis/${i##*/}-part1
done


## Create optional user data datasets to omit data form rollback
for i in {var/games,var/www,var/lib/docker,var/lib/nfs}; do
    read -r -p "Do you want to add $i to the user datasets? [y/N] " response
    response=${response,,}  # tolower
    if [[ "$response" =~ ^(yes|y)$ ]]
    then
        echo "Okay! Adding $i!"
        zfs create -o canmount=on rpool_$INST_UUID/$INST_ID/DATA/default/$i
    else
        echo "Skipping $i... :("
    fi

done