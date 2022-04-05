#!/run/current-system/sw/bin/bash -xe

# BEGINNING OF MY setup.sh script

DISK=/dev/disk/by-id/nvme-SKHynix_HFS512GDE9X081N_CD13N445112003740
for i in ${DISK}; do blkdiscard -f $i & done
wait
INST_UUID=$(dd if=/dev/urandom bs=1 count=100 2>/dev/null | tr -dc 'a-z0-9' | cut -c-6)
INST_ID=nixos
INST_CONFIG_FILE='zfs.nix'
INST_PRIMARY_DISK=$(echo $DISK | cut -f1 -d\ )
INST_PARTSIZE_ESP=2 # in GB
INST_PARTSIZE_BPOOL=4
INST_PARTSIZE_SWAP=8



# BEGINNING OF MY partition.sh script

### -------- ALL THE SAME -------- ###
for i in ${DISK}; do
    sgdisk --zap-all $i
    sgdisk -n 1:1M:+${INST_PARTSIZE_ESP}G -t1:EF00 $i
    sgdisk -n 2:0:+${INST_PARTSIZE_BPOOL}G -t2:BE00 $i
    if [ "${INST_PARTSIZE_SWAP}" != "" ]; then
        sgdisk -n 4:0:+${INST_PARTSIZE_SWAP}G -t4:8200 $i
    fi
    if [ "${INST_PARTSIZE_RPOOL}" = "" ]; then
        sgdisk -n 3:0:0   -t3:BF00 $i
    else
        sgdisk -n 3:0:+${INST_PARTSIZE_RPOOL}G -t3:BF00 $i;
    fi
    sgdisk -a1 -n 5:24K:+1000K -t5:EF02 $i
done
sync # NOT PRESENT IN MY SCRIPT
sleep 3 # NOT PRESENT IN MY SCRIPT


### -------- ALL THE SAME -------- ###
disk_num=0;
for i in $DISK; do
    disk_num=$(( $disk_num + 1 ));
done
if [ $disk_num -gt 1 ]; then
    INST_VDEV_BPOOL=mirror;
fi


### -------- NOT SAME -------- ###
## -f flag is used (not in mine)
## ashift=12 (13 in mine)
## atime=off (left unset default [on] in mine)
## relatime unset (on in mine)
zpool create -f \
    -o compatibility=grub2 \
    -o ashift=12 \
    -o autotrim=on \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=lz4 \
    -O devices=off \
    -O normalization=formD \
    -O atime=off \
    -O xattr=sa \
    -O mountpoint=/boot \
    -R /mnt \
    bpool_$INST_UUID \
    $INST_VDEV_BPOOL \
    $(for i in ${DISK}; do
        printf "$i-part2 ";
    done)


### -------- NOT SAME -------- ###
## -f flag is used (not in mine)
## ashift=12 (13 in mine)
## atime=off (left unset default [on] in mine)
## relatime unset (on in mine)
## encryption not used here, keylocation and keyformat also not used
zpool create -f \
    -o ashift=12 \
    -o autotrim=on \
    -R /mnt \
    -O acltype=posixacl \
    -O canmount=off \
    -O compression=zstd \
    -O dnodesize=auto \
    -O normalization=formD \
    -O atime=off \
    -O xattr=sa \
    -O mountpoint=/ \
    rpool_$INST_UUID \
    $INST_VDEV \
    $(for i in ${DISK}; do
        printf "$i-part3 ";
    done)


### -------- MOSTLY SAME -------- ###
## passing in encryption password
echo poolpass | zfs create \
    -o canmount=off \
    -o mountpoint=none \
    -o encryption=aes-256-gcm \
    -o keylocation=prompt \
    -o keyformat=passphrase \
    rpool_$INST_UUID/$INST_ID


### -------- MOSTLY SAME -------- ###
## put back to match the original ne9z script
zfs create -o canmount=off -o mountpoint=none bpool_$INST_UUID/$INST_ID
zfs create -o canmount=off -o mountpoint=none bpool_$INST_UUID/$INST_ID/BOOT
zfs create -o canmount=off -o mountpoint=none rpool_$INST_UUID/$INST_ID/ROOT
zfs create -o canmount=off -o mountpoint=none rpool_$INST_UUID/$INST_ID/DATA
zfs create -o mountpoint=/boot -o canmount=noauto bpool_$INST_UUID/$INST_ID/BOOT/default
zfs create -o mountpoint=/ -o canmount=off rpool_$INST_UUID/$INST_ID/DATA/default
zfs create -o mountpoint=/ -o canmount=off rpool_$INST_UUID/$INST_ID/DATA/local
zfs create -o mountpoint=/ -o canmount=noauto rpool_$INST_UUID/$INST_ID/ROOT/default
zfs mount rpool_$INST_UUID/$INST_ID/ROOT/default
zfs mount bpool_$INST_UUID/$INST_ID/BOOT/default

for i in {nix,}; do
    zfs create -o canmount=on -o mountpoint=/$i rpool_$INST_UUID/$INST_ID/DATA/local/$i;
done


zfs create -o canmount=on rpool_$INST_UUID/$INST_ID/DATA/default/state
for i in {/etc/nixos,/etc/cryptkey.d}; do
  mkdir -p /mnt/state/$i /mnt/$i
  mount -o bind /mnt/state/$i /mnt/$i
done


zfs create -o mountpoint=/ -o canmount=noauto rpool_$INST_UUID/$INST_ID/ROOT/empty
zfs snapshot rpool_$INST_UUID/$INST_ID/ROOT/empty@start


# NOT PRESENT IN MY SCRIPT
for i in {home,home/empty}; do
    zfs create -o canmount=on rpool_$INST_UUID/$INST_ID/DATA/default/$i;
done
zfs snapshot rpool_$INST_UUID/$INST_ID/DATA/default/home/empty@start


for i in ${DISK}; do
    mkfs.vfat -n EFI ${i}-part1
    mkdir -p /mnt/boot/efis/${i##*/}-part1
    mount -t vfat ${i}-part1 /mnt/boot/efis/${i##*/}-part1
done

# DOES NOT HAVE ANY OF THE DATASETS FOR {usr,var,var/lib} AS SHOWN IN THE GUIDE
# ONE OF THE FAILED UMOUNT POINTS IS /mnt/var/spool BUT THAT IS AFTER GRUB FAILS TO INSTALL



# BEGINNING OF MY system-config.sh script

# This part is exactly this same
nixos-generate-config --root /mnt
sed -i "s|./hardware-configuration.nix|./hardware-configuration-zfs.nix ./${INST_CONFIG_FILE}|g" /mnt/etc/nixos/configuration.nix
# backup, prevent being overwritten by nixos-generate-config
mv /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration-zfs.nix


# This part is exactly this same
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
{ config, pkgs, ... }:

{ boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "$(head -c 8 /etc/machine-id)";
  boot.zfs.devNodes = "${INST_PRIMARY_DISK%/*}";
EOF


# This part is mostly this same - reformatted with \
sed -i 's|fsType = "zfs";|fsType = "zfs"; options = [ "zfsutil" "X-mount.mkdir" ];|g' \
/mnt/etc/nixos/hardware-configuration-zfs.nix
sed -i 's|fsType = "vfat";|fsType = "vfat"; options = [ "x-systemd.idle-timeout=1min" "x-systemd.automount" "noauto" ];|g' \
/mnt/etc/nixos/hardware-configuration-zfs.nix


# MISSING THE LINE FOR boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;


# This part is exactly this same
mkdir -p /mnt/state/etc/zfs/
rm -f /mnt/state/etc/zfs/zpool.cache
touch /mnt/state/etc/zfs/zpool.cache
chmod a-w /mnt/state/etc/zfs/zpool.cache
chattr +i /mnt/state/etc/zfs/zpool.cache


# This part is mostly this same - white space is a little different but shouldn't matter
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


# This part is mostly this same
mkdir -p /mnt/state/etc/{ssh,zfs}
systemd-machine-id-setup --print >/mnt/state/etc/machine-id
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
  systemd.services.zfs-mount.enable = false;
  environment.etc."machine-id".source = "/state/etc/machine-id";
  environment.etc."zfs/zpool.cache".source
    = "/state/etc/zfs/zpool.cache";
  boot.loader.efi.efiSysMountPoint = "/boot/efis/${INST_PRIMARY_DISK##*/}-part1";
EOF


# Not the same
# boot.loader.efi.canTouchEfiVariables is not set but default is false
sed -i '/boot.loader/d' /mnt/etc/nixos/configuration.nix
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<-'EOF'
	  boot.loader = {
	    generationsDir.copyKernels = true;
	    ##for problematic UEFI firmware
	    grub.efiInstallAsRemovable = true;
	    ##if UEFI firmware can detect entries
	    #efi.canTouchEfiVariables = true;
	    grub.enable = true;
	    grub.version = 2;
	    grub.copyKernels = true;
	    grub.efiSupport = true;
	    grub.zfsSupport = true;
	    # for systemd-autofs
	    grub.extraPrepareConfig = ''
	      mkdir -p /boot/efis /boot/efi
	      for i in  /boot/efis/*; do mount $i ; done
	      mount /boot/efi
	    '';
	    grub.extraInstallCommands = ''
	       export ESP_MIRROR=$(mktemp -d -p /tmp)
EOF

# This part is exactly this same
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
       cp -r /boot/efis/${INST_PRIMARY_DISK##*/}-part1/EFI \$ESP_MIRROR
EOF

# This part is mostly this same - white space is a little different but shouldn't matter
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<-'EOF'
	       for i in /boot/efis/*; do
	        cp -r $ESP_MIRROR/EFI $i
	       done
	       rm -rf $ESP_MIRROR
	    '';
	    grub.devices = [
EOF

# This part is mostly this same - for loop is inline but shouldn't matter
for i in $DISK; do printf "      \"$i\"\n" >>/mnt/etc/nixos/${INST_CONFIG_FILE}; done
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
    ];
  };
EOF



# BEGINNING OF MY system-install.sh script

## ADDED LINES FOR GENERATING ROOT HASH BECAUSE I COULDN'T LOGIN WIHTOUT IT
# Generate password hash
INST_ROOT_PASSWD=$(mkpasswd -m SHA-512 -s)

# Declare initialHashedPassword for root user
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
  users.users.root.initialHashedPassword = "${INST_ROOT_PASSWD}";
EOF

tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
}
EOF

## NO SNAPSHOTS TAKEN BEFORE INSTALL

nixos-install -v --show-trace --no-root-passwd --root /mnt

## NO SNAPSHOTS TAKEN AFTER INSTALL

umount /mnt/boot/efis/*

## EXPORTS ALL RATHER THAN SPECIFIC POOLS
zpool export -a

echo $?
