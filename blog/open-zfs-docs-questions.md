# Questions Related to the OpenZFS Root on ZFS Docs

There are a number of things I have encountered that are not clear to me. The OpenZFS documentation has a very comprehensive guide for installing
[NixOS Root on ZFS](https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS.html).
After finding the pull request that updated much of the guide,
[#195](https://github.com/openzfs/openzfs-docs/pull/195), I found a link to an
[old entry](https://nixos.wiki/index.php?title=User:2r/NixOS_on_ZFS&oldid=5406)
on the NixOS Wiki that appears to be where the author,
[ne9z](https://github.com/ne9z), was writing a draft for submission.
I found answer to some of my questions there as well as some more information that would be nice to have in the OpenZFS documentation.

## Open Questions
* Why have a `mountpoint` for zpool and bpool that are anything but none especially when `canmount=off`?
  * I would have guessed for inheritance but `bpool/sys/BOOT/default` also sets the `mountpoint` the same as `bpool`.
* What does this line do (`mount -o bind /mnt/state/$i /mnt/$i`)? Or more specifically, what is its intention?
  * From the `mount` man page, it says, "Remount part of the file hierarchy somewhere else.". So it appears that this is a way to store system mutable state in a separate `state` dataset that is not reproducible by NixOS.
* Check if datasets that have `canmount=noauto` get added to `fstab` later.
* In the Overview - Dataset layout, the container field for Dataset `rpool/sys/ROOT`, says "contains boot environment". Should that be "contains ***root*** environment"?
* How does it work when you have an unmounted dataset between two mounted datasets?
  * For example, if dataset `a` is created with `mountpoint=/` and `canmount=on`, it has a child `b` with `canmount=off`, and that has a child `c` with `canmount=on`, what is the resulting structure look like?
    * It appears that the resulting structure will look like `/a/b/c` with each dataset being mounted under its parent (e.g. `b` will be mounted at `/a/b` and `c` will be mounted at `/a/b/c`). But `b` still cannot be mounted. So if a file is placed under dataset `b` will it appear under dataset `a`?
    * It appears that if I had set `mountpoint=none` for `b`, then `c` would have inherited that.

## Answered Questions

* Why so many nested datasets in the layout?
  * I have wondered why, in the layout, that there were so many empty dataset containers. For example, in the [NixOS Root on ZFS Overview](https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS/0-overview.html#), there is `rpool/sys/ROOT/default`. In this case, `sys` is a placeholder for `nixos`, but `ROOT` is an unmounted datasets with no other children except `default`. Couldn't `default` have been eliminated?
    * This appears to be a sysadmin practice.[^1] You could have just `ROOT`, but having `default` allows you to to apply patches or upgrade your system in a safe way. If `default` is your initial system, when you upgrade to a new version (e.g. `ver-2`), you can create a new dataset, `rpool/sys/ROOT/ver-2`, and mount that over the original dataset. If the upgrade does not work as intended, reversion is trivial. Having this under the `ROOT` dataset keeps things clean compared to if all your system datasets were at the `sys` level. I am not certain this is crucial with NixOS as systems builds emulate this behavior by changing the pointer during system upgrades, but it is useful to have just in case, and changing the dataset layout later to add this could be painful.
  * `sys` has one other child, `DATA`, where user data and `/nix` will be mounted. Similarly, could `sys` not also be eliminated? Why all the nesting.
    * I guessed, based on looking at the guides for other OSes, that the `sys` layer was so that multiple operating systems could be installed in the same pool. With the `sys` layer, it is possible to have `rpool/nixos/ROOT`, `rpool/arch/ROOT`, `rpool/debian/ROOT`, etc. I found an issue on the openzfs-docs repository, [#257](https://github.com/openzfs/openzfs-docs/issues/257), that confirmed my suspicions and gave some additional insight. The documentation from the previously mentioned pull request removed the use of `zfs-mount-generator` in exchange for a `/etc/fstab` configuration. The reason, as explained in the issue, is so that `fstab` can determine which dataset to mount. If we have multiple `sys` datasets all mounting to the same point, the mount generator will attempt to mount them all to the same path. When using `fstab`, we can control which dataset is mounted on a per-system basis. Also, I am guessing that is why the `canmount` flag for mounted boot and root datasets is set to `noauto`. We cannot set it to `off` or else it will be impossible to mount. We do not want to set it to `on` or else it would be automatically mounted by ZFS. So it is left as `noauto` so that it can be mounted by `fstab` or the `initrd zfs hook`. See the [Dataset layout](https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS/0-overview.html#dataset-layout) table notes.
* What is the difference between a physical sector and a logical sector. Comes from the discussion of `ashift` in the [System Configuration - Step 4 - Notes](https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS/2-system-configuration.html).
  * The physical sector size is what the hard drive actually reads and writes in; the logical sector size is what you can ask it to read or write. See [this](https://utcc.utoronto.ca/~cks/space/blog/tech/AdvancedFormatDrives), [this](https://utcc.utoronto.ca/~cks/space/blog/solaris/ZFS4KSectorDisks), [this](https://superuser.com/questions/982680/whats-the-point-of-hard-drives-reporting-their-physical-sector-size), [this](https://superuser.com/questions/753893/what-is-the-difference-between-physical-and-logical-size), and maybe [this](https://www.delphix.com/blog/delphix-engineering/4k-sectors-and-zfs) for more details and discussion.

[^1]: Lucas, Michael, and Allan Jude. FreeBSD Mastery: ZFS. Tilted Windmill Press, 2015, p. 17.