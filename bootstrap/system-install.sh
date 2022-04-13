#!/bin/bash


# Generate password hash
INST_ROOT_PASSWD=$(mkpasswd -m SHA-512 -s)


# Declare initialHashedPassword for root user
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
  users.users.root.initialHashedPassword = "${INST_ROOT_PASSWD}";
EOF


echo "If boot pool encryption is used and installation fails with:

mktemp: failed to create directory via template
‘/mnt/tmp.coRUoqzl1P/initrd-secrets.XXXXXXXXXX’: No such file or directory
failed to create initrd secrets: No such file or directory

This is a bug. Complete the installation by executing:
nixos-enter --root /mnt -- nixos-rebuild boot
"

# System installation
# Finalize the config file
tee -a /mnt/etc/nixos/${INST_CONFIG_FILE} <<EOF
}
EOF

# Take a snapshot of the clean installation, without state for future use
zfs snapshot -r rpool_$INST_UUID/$INST_ID@install_start
zfs snapshot -r bpool_$INST_UUID/$INST_ID@install_start

# Apply configuration
nixos-install -v --show-trace --no-root-passwd --root /mnt


# Finish installation
# Take a snapshot of the clean installation for future use
zfs snapshot -r rpool_$INST_UUID/$INST_ID@install
zfs snapshot -r bpool_$INST_UUID/$INST_ID@install

# Unmount EFI system partition
umount /mnt/boot/efis/*

# Export pools
zpool export bpool_$INST_UUID
zpool export rpool_$INST_UUID

# reboot
