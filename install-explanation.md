# Installation

There are no files to modify before starting. Simply execute the `setup.sh` script and it will begin an interactive session to bootstrap the system.

## Disk Selection

The function `ask_user_for_disks` presents the user with a selection of disks to add to the ZFS pool. Here is an example:

```console
$ ask_user_for_disks
Disk 1 is '/dev/disk/by-id/ata-SanDisk_SD9SN8W512G_183347423947'          ->  '../../sda'
Disk 2 is '/dev/disk/by-id/nvme-eui.0025385881b3ba2a'                     ->  '../../nvme0n1'
Disk 3 is '/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E'  ->  '../../nvme0n1'
Disk 4 is '/dev/disk/by-id/wwn-0x5001b444a9dae907'                        ->  '../../sda'
Select a disk by number. Return 0 or nothing to finish: 3
Select a disk by number. Return 0 or nothing to finish:

Are you satisfied with your disk(s) selection?
/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E
1) Yes
2) No
#? 1
/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E
```

The selection should only show you physical disks with the disk id symbolic link on the left and the disk kernel name on the right (e.g. `'/dev/disk/by-id/nvme-eui.0025385881b3ba2a'  ->  '../../nvme0n1'`). You select disks one at a time by entering a number followed by the `Return` key. If you enter `0` or nothing and hit `Return`, it will present you with all the disks you have selected and verify that you are satisfied with the disks. If you select yes, the function will return an array of disks by ID. Otherwise, it will start the selection over again.

### Issues

A lot of work went into presenting only disks to the user, and the disk by ID with the associated kernel name. Diving into the `ask_user_for_disks` function, we see it is a wrapper for `add_disks_to_pool` to verify their selection. Inside, `add_disks_to_pool` is a simply while loop that allows the user to enter as many disks as desired. The `show_only_disks` function finds all the disks by ID and their associated kernel names and presents it to the user. In other words, running `show_only_disks` does this part of the previous example.

```console
$ show_only_disks
Disk 1 is '/dev/disk/by-id/ata-SanDisk_SD9SN8W512G_183347423947'          ->  '../../sda'
Disk 2 is '/dev/disk/by-id/nvme-eui.0025385881b3ba2a'                     ->  '../../nvme0n1'
Disk 3 is '/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E'  ->  '../../nvme0n1'
Disk 4 is '/dev/disk/by-id/wwn-0x5001b444a9dae907'                        ->  '../../sda'
```

After that, a while loop is entered and the `ask_for_disk_by_idx` function is called which will allow the user to enter a disk number. For example:
```console
Select a disk by number. Return 0 or nothing to finish:
```
Entering `0` or nothing breaks the loop. Entering a valid number passes the entry to `select_only_disks_by_idx` which will add the selected disk to an array.

In all the functions used in `add_disks_to_pool`, there is a common function, `get_only_disks`, that does a lot of the leg work of finding only physical disks. We do _not_ want to present the user with partitions, logical volumes, or other non-disk devices. Let's take a look at `get_only_disks` and see how it works.

First, there is a call to `disks_by_id_symbolic` which uses stat to list all the devices in `/dev/disk/by-id/` along with the with the dereferenced link if it is a symbolic link. The output can look something like this.

```console
$ disks_by_id_symbolic
'/dev/disk/by-id/ata-SanDisk_SD9SN8W512G_183347423947' -> '../../sda'
'/dev/disk/by-id/ata-SanDisk_SD9SN8W512G_183347423947-part1' -> '../../sda1'
'/dev/disk/by-id/dm-name-mint--vg-root' -> '../../dm-1'
'/dev/disk/by-id/dm-name-mint--vg-swap_1' -> '../../dm-2'
'/dev/disk/by-id/dm-name-nvme0n1p3_crypt' -> '../../dm-0'
'/dev/disk/by-id/dm-uuid-CRYPT-LUKS1-fb4b18d9d6dd4a69a0f70788af75c9c9-nvme0n1p3_crypt' -> '../../dm-0'
'/dev/disk/by-id/dm-uuid-LVM-zxzta3KcKSgRkfwyn1Z0SNJzOZpV4OIb1UZeblfiKTovaTc3h2GMucn0OKJedV3T' -> '../../dm-1'
'/dev/disk/by-id/dm-uuid-LVM-zxzta3KcKSgRkfwyn1Z0SNJzOZpV4OIbmP71R2Rt7EqRfEFiuBT5g97i0WSU3aFB' -> '../../dm-2'
'/dev/disk/by-id/lvm-pv-uuid-fvcO13-Z9iF-Mi9h-grcH-5Uy8-WrRR-PGcxjP' -> '../../dm-0'
'/dev/disk/by-id/nvme-eui.0025385881b3ba2a' -> '../../nvme0n1'
'/dev/disk/by-id/nvme-eui.0025385881b3ba2a-part1' -> '../../nvme0n1p1'
'/dev/disk/by-id/nvme-eui.0025385881b3ba2a-part2' -> '../../nvme0n1p2'
'/dev/disk/by-id/nvme-eui.0025385881b3ba2a-part3' -> '../../nvme0n1p3'
'/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E' -> '../../nvme0n1'
'/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E-part1' -> '../../nvme0n1p1'
'/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E-part2' -> '../../nvme0n1p2'
'/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E-part3' -> '../../nvme0n1p3'
'/dev/disk/by-id/wwn-0x5001b444a9dae907' -> '../../sda'
'/dev/disk/by-id/wwn-0x5001b444a9dae907-part1' -> '../../sda1'
```

That is a lot of devices! There are physical disks, partitions, loop devices, LVMs -- all sorts of things. But we are bootstrapping a new systems so we do not want to overwhelm the end user and want to parse through that. Unfortunately, stat does not give us any information about what each of these devices are (or at least I couldn't figure out how to get it to tell me). So we use another function `lsblk_filesystems` which uses `lsblk` to give us an output that looks like this.

```console
$ lsblk_filesystems
KNAME     TYPE
loop0     loop
loop1     loop
loop2     loop
loop4     loop
loop5     loop
loop6     loop
loop7     loop
loop8     loop
loop9     loop
loop10    loop
loop11    loop
sda       disk
sda1      part
dm-0      crypt
dm-1      lvm
dm-2      lvm
nvme0n1   disk
nvme0n1p1 part
nvme0n1p2 part
nvme0n1p3 part
```

That is interesting. Now we have the kernel name for our devices along with the type. But we don't need to know all the different types. We only want device kernel names that are of type `disk`. So we use `filter_lsblk_by_disk` to filter the output of `lsblk_filesystems` and we get something like this.

```console
$ filesystems=$(lsblk_filesystems)
$ filter_lsblk_by_disk "${filesystems[@]}"
sda nvme0n1
```

Nice! We have the only two device kernel names that are of type `disk`. Now we just need to filter the output of `disks_by_id_symbolic` with this array and we get our filtered list.

```console
$ get_only_disks
'/dev/disk/by-id/ata-SanDisk_SD9SN8W512G_183347423947' -> '../../sda'
'/dev/disk/by-id/nvme-eui.0025385881b3ba2a' -> '../../nvme0n1'
'/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E' -> '../../nvme0n1'
'/dev/disk/by-id/wwn-0x5001b444a9dae907' -> '../../sda'
```

With our filtered list we can do a lot. As mentioned previously, `add_disks_to_pool` has several functions that all use `get_only_disks`: `show_only_disks`, `ask_for_disk_by_idx`, and `select_only_disks_by_idx`. We already talked about what `show_only_disks` does; it neatly prints all the disks and associates them with a disk number for user selection. `ask_for_disk_by_idx` uses `get_only_disks` as part of its bounds check. It finds the number of lines of the output of `get_only_disks` using `wc` to to make sure that a disk selection is in bounds. For example, if we try to select disk 5 when there are only 4, we get a warning, and a message telling us what the upper bound for disk selection is.

```console
$ ask_user_for_disks
Disk 1 is '/dev/disk/by-id/ata-SanDisk_SD9SN8W512G_183347423947'          ->  '../../sda'
Disk 2 is '/dev/disk/by-id/nvme-eui.0025385881b3ba2a'                     ->  '../../nvme0n1'
Disk 3 is '/dev/disk/by-id/nvme-Samsung_SSD_970_PRO_1TB_S462NF0K816201E'  ->  '../../nvme0n1'
Disk 4 is '/dev/disk/by-id/wwn-0x5001b444a9dae907'                        ->  '../../sda'
Select a disk by number. Return 0 or nothing to finish: 5
5 is out of bounds! Upper bound is 4
Select a disk by number. Return 0 or nothing to finish:
```

Finally, `select_only_disks_by_idx` takes the disk number user input, cycling through all the lines from the output of `get_only_disks`, and returning the `/dev/disk/by-id/` path for the device when it finds the correct disk.