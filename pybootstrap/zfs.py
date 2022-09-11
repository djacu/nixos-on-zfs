"""Modules for building OpenZFS commands."""
from abc import ABC
from dataclasses import dataclass, field, fields
from pathlib import Path
from typing import Any, List, Optional


@dataclass(frozen=True)
class ZfsOptionBase(ABC):
    """Base class for ZFS option like Pool ZFS Properties."""

    prefix: str = field(init=False, default="")

    def _attr_filter(self) -> List[str]:
        field_names = [f.name for f in fields(self) if f.name != "prefix"]
        return list(filter(lambda f: getattr(self, f) is not None, field_names))

    def _prop(self, attr: str) -> str:
        return f"-{self.prefix} {attr}={getattr(self, attr)}"

    def _valid_attr(self, attr: str, allowed: list[Any]):
        attr_val = getattr(self, attr)
        if attr_val is not None and attr_val not in allowed:
            bad_val = getattr(self, attr)
            raise ValueError(f"Attribute {attr} ({bad_val}) not in {allowed}.")


@dataclass(frozen=True)
class ZPoolProps(ZfsOptionBase):
    """Properties of ZFS storage pools.

    Attributes
    ----------
        altroot : Path, optional
            Alternate root directory. If set, this directory is
            prepended to any mount points within the pool. This can be
            used when examining an unknown pool where the mount points
            cannot be trusted, or in an alternate boot environment,
            where the typical paths are not valid. altroot is not a
            persistent property. It is valid only while the system is
            up. Setting altroot defaults to using `cachefile=none`,
            though this may be overridden using an explicit setting.
        ashift : int
            Pool sector size exponent, to the power of 2. Values from 9
            to 16, inclusive, are valid; also, the value 0 (the default)
            means to auto-detect using the kernel's block layer and a
            ZFS internal exception list.
        autotrim : str
            When set to on space which has been recently freed, and is
            no longer allocated by the pool, will be periodically
            trimmed. This allows block device vdevs which support
            BLKDISCARD, such as SSDs, or file vdevs on which the
            underlying file system supports hole-punching, to reclaim
            unused blocks. The default value for this property is off.
        cachefile : Path | str, optional
            Controls the location of where the pool configuration is
            cached. Discovering all pools on system startup requires a
            cached copy of the configuration data that is stored on the
            root file system. All pools in this cache are automatically
            imported when the system boots. Some environments, such as
            install and clustering, need to cache this information in a
            different location so that pools are not automatically
            imported. Setting this property caches the pool
            configuration in a different location that can later be
            imported with `zpool import -c`. Setting it to the value
            `'none'` creates a temporary pool that is never cached, and
            the “” (empty string) uses the default location. Multiple
            pools can share the same cache file. Because the kernel
            destroys and recreates this file when pools are added and
            removed, care should be taken when attempting to access this
            file. When the last pool using a `cachefile` is exported or
            destroyed, the file will be empty.
        compatibility : str
            Specifies that the pool maintain compatibility with specific
            feature sets. When set to off (or unset) compatibility is
            disabled (all features may be enabled); when set to legacy
            no features may be enabled. When set to a comma- separated
            list of filenames (each filename may either be an absolute
            path, or relative to /etc/zfs/compatibility.d or
            /usr/share/zfs/compatibility.d) the lists of requested
            features are read from those files, separated by whitespace
            and/or commas. Only features present in all files may be
            enabled.
    """

    prefix: str = field(init=False, default="o")
    altroot: Optional[Path] = None
    ashift: int = 0
    autotrim: str = "off"
    cachefile: Optional[Path | str] = None
    compatibility: str = "off"

    def __post_init__(self):
        if self.altroot is not None and self.cachefile is None:
            # required for frozen datasets
            super().__setattr__("cachefile", "none")

        self._valid_attr("ashift", [0] + list(range(9, 17)))
        self._valid_attr("autotrim", ["on", "off"])

    def __str__(self):
        return " ".join(map(self._prop, self._attr_filter()))


@dataclass(frozen=True)
class ZfsProps(ZfsOptionBase):
    # pylint: disable=too-many-instance-attributes
    """Native properties of ZFS datasets.

    Attributes
    ----------
        prefix : str
            The prefix to use for the options in this class (e.g. 'o' or
            'O'). The prefix is dependent on which command it is
            intended for. For example, `zpool create` requires 'O' while
            `zfs create` requires 'o'.
        atime : {'on', 'off'}, optional
            Controls whether the access time for files is updated when
            they are read. Turning this property off avoids producing
            write traffic when reading files and can result in
            significant performance gains, though it might confuse
            mailers and other similar utilities. The values on and off
            are equivalent to the atime and noatime mount options. The
            default value is on. See also `relatime` below.
        acltype: {'off', 'noacl', 'nfsv4', 'posix', 'posixacl'},
        optional
            Controls whether ACLs are enabled and if so what type of ACL
            to use. When this property is set to a type of ACL not
            supported by the current platform, the behavior is the same
            as if it were set to off. To obtain the best performance
            when setting posix users are strongly encouraged to set the
            `xattr`='sa' property. This will result in the POSIX ACL
            being stored more efficiently on disk. But as a consequence,
            all new extended attributes will only be accessible from
            OpenZFS implementations which support the `xattr`='sa'
            property. See the `xattr` property for more details.
        canmount: {'on', 'off', 'noauto'}, optional
            If this property is set to off, the file system cannot be
            mounted, and is ignored by zfs mount -a. Setting this
            property to off is similar to setting the mountpoint
            property to none, except that the dataset still has a normal
            mountpoint property, which can be inherited. Setting this
            property to off allows datasets to be used solely as a
            mechanism to inherit properties. One example of setting
            canmount=off is to have two datasets with the same
            mountpoint, so that the children of both datasets appear in
            the same directory, but might have different inherited
            characteristics. When set to 'noauto', a dataset can only be
            mounted and unmounted explicitly. The dataset is not mounted
            automatically when the dataset is created or imported, nor
            is it mounted by the zfs mount -a command or unmounted by
            the zfs unmount -a command. This property is not inherited.
        compression : {'on', 'off', 'gzip', 'lz4', 'lzjb', 'zle',
        'zstd', 'zstd-fast'}, optional
            Controls the compression algorithm used for this dataset.
        devices : {'on', 'off'}, optional
            Controls whether device nodes can be opened on this file
            system. The default value is on. The values on and off are
            equivalent to the dev and nodev mount options.
        dnodesize : {'legacy', 'auto', '1k', '2k', '4k', '8k', '16k'},
        optional
            Specifies a compatibility mode or literal value for the size
            of dnodes in the file system. The default value is legacy.
            Setting this property to a value other than legacy requires
            the large_dnode pool feature to be enabled. Consider setting
            dnodesize to auto if the dataset uses the xattr=sa property
            setting and the workload makes heavy use of extended
            attributes. This may be applicable to SELinux-enabled
            systems, Lustre servers, and Samba servers, for example.
            Literal values are supported for cases where the optimal
            size is known in advance and for performance testing.
        encryption : {'off', 'on', 'aes-128-ccm', 'aes-192-ccm',
        'aes-256-ccm', 'aes-128-gcm', 'aes-192-gcm', 'aes-256-gcm'},
        optional
            Controls the encryption cipher suite (block cipher, key
            length, and mode) used for this dataset. Requires the
            encryption feature to be enabled on the pool. Requires a
            keyformat to be set at dataset creation time. Selecting
            encryption=on when creating a dataset indicates that the
            default encryption suite will be selected, which is
            currently aes-256-gcm. In order to provide consistent data
            protection, encryption must be specified at dataset creation
            time and it cannot be changed afterwards.
        keyformat : {'passphrase'}, optional
            Controls what format the user's encryption key will be
            provided as. This property is only set when the dataset is
            encrypted. `raw` and `hex` currently not supported.
        keylocation : {'prompt'}, optional
            Controls where the user's encryption key will be loaded from
            by default for commands such as zfs. `file://`, `https://`
            and `http://` currently not supported.
        mountpoint : Path | {'none', 'legacy'}, optional
            Controls the mount point used for this file system. When the
            mountpoint property is changed for a file system, the file
            system and any children that inherit the mount point are
            unmounted. If the new value is legacy, then they remain
            unmounted. Otherwise, they are automatically remounted in
            the new location if the property was previously legacy or
            none, or if they were mounted before the property was
            changed. In addition, any shared file systems are unshared
            and shared in the new location.
        normalization : {'none', 'formC', 'formD', 'formKC', 'formKD'},
        optional
            Indicates whether the file system should perform a unicode
            normalization of file names whenever two file names are
            compared, and which normalization algorithm should be used.
            File names are always stored unmodified, names are
            normalized as part of any comparison process. If this
            property is set to a legal value other than none, and the
            utf8only property was left unspecified, the utf8only
            property is automatically set to on. The default value of
            the normalization property is none. This property cannot be
            changed after the file system is created.
        relatime : {'on', 'off'}, optional
            Controls the manner in which the access time is updated when
            atime=on is set. Turning this property on causes the access
            time to be updated relative to the modify or change time.
            Access time is only updated if the previous access time was
            earlier than the current modify or change time or if the
            existing access time hasn't been updated within the past 24
            hours. The default value is off. The values on and off are
            equivalent to the relatime and norelatime mount options.
        xattr : {'on', 'off', 'sa'}, optional
            Controls whether extended attributes are enabled for this
            file system. Two styles of extended attributes are
            supported: either directory-based or system-attribute-based.
            The use of system-attribute-based xattrs is strongly
            encouraged for users of SELinux or POSIX ACLs. Both of these
            features heavily rely on extended attributes and benefit
            significantly from the reduced access time.

    Raises
    ------
        ValueError
            If `encryption` is `None` or `'off'`, then `keyformat` and
            `keylocation` must also be `None`. If `encryption` is any
            other valid option, then the other two options must also be
            specified.
    """
    prefix: str
    atime: Optional[str] = None
    acltype: Optional[str] = None
    canmount: Optional[str] = None
    compression: Optional[str] = None
    devices: Optional[str] = None
    dnodesize: Optional[str] = None
    encryption: Optional[str] = None
    keyformat: Optional[str] = None
    keylocation: Optional[str] = None
    mountpoint: Optional[Path | str] = None
    normalization: Optional[str] = None
    relatime: Optional[str] = None
    xattr: Optional[str] = None

    def __post_init__(self):
        self._valid_attr("atime", ("on", "off"))
        self._valid_attr("acltype", ("off", "noacl", "nfsv4", "posix", "posixacl"))
        self._valid_attr("canmount", ("on", "off", "noauto"))
        self._valid_attr(
            "compression",
            ("on", "off", "gzip", "lz4", "lzjb", "zle", "zstd", "zstd-fast"),
        )
        self._valid_attr("devices", ("on", "off"))
        self._valid_attr("dnodesize", ("legacy", "auto", "1k", "2k", "4k", "8k", "16k"))
        self._valid_attr(
            "encryption",
            (
                "off",
                "on",
                "aes-128-ccm",
                "aes-192-ccm",
                "aes-256-ccm",
                "aes-128-gcm",
                "aes-192-gcm",
                "aes-256-gcm",
            ),
        )
        self._valid_attr("keyformat", ("passphrase",))
        self._valid_attr("keylocation", ("prompt",))
        self._valid_encryption()
        self._valid_mountpoint()
        self._valid_attr(
            "normalization", ("none", "formC", "formD", "formKC", "formKD")
        )
        self._valid_relatime()
        self._valid_attr("xattr", ("on", "off", "sa"))

    def _valid_encryption(self):
        self._valid_attr(
            "encryption",
            (
                "off",
                "on",
                "aes-128-ccm",
                "aes-192-ccm",
                "aes-256-ccm",
                "aes-128-gcm",
                "aes-192-gcm",
                "aes-256-gcm",
            ),
        )

        encrypt_off = self.encryption == "off" or self.encryption is None
        keyformat_unset = self.keyformat is None
        keylocation_unset = self.keylocation is None

        if self._xor_three(encrypt_off, keyformat_unset, keylocation_unset):
            raise ValueError(
                "encryption, keyformat, and keylocation must all"
                " be None (or encryption='off') or all set to"
                " valid values (with encryption not being 'off')."
            )

    def _xor_three(self, a, b, c):
        return (a ^ b) or (a ^ c)

    def _valid_mountpoint(self):
        if isinstance(self.mountpoint, str):
            self._valid_attr("mountpoint", ("none", "legacy"))

        if (
            not isinstance(self.mountpoint, str)
            and not isinstance(self.mountpoint, Path)
            and self.mountpoint is not None
        ):
            err_str = (
                f"Unexpected type {type(self.mountpoint)} for attribute `mountpoint`."
            )
            raise ValueError(err_str)

    def _valid_relatime(self):
        self._valid_attr("relatime", ("on", "off"))
        if self.atime == "off" and not self.relatime == "off":
            raise ValueError("`relatime` must be off if `atime` is off.")

    def __str__(self):
        return " ".join(map(self._prop, self._attr_filter()))


@dataclass
class ZPool:
    """Class for creating ZFS storage pools."""

    zpoolprops: ZPoolProps
    zfsprops: ZfsProps

    def __str__(self):
        return " ".join(("zpool create", str(self.zpoolprops), str(self.zfsprops)))

    def _valid_vdev_type(self, vdev_type: str):
        # pylint: disable=no-self-use
        allowed = ["", "mirror", "raidz1", "raidz2", "raidz3"]
        if vdev_type not in allowed:
            raise ValueError(f"vdev_type ({vdev_type}) not in {allowed}.")

    def create(self, name: str, disks: List[Path], vdev_type: str = ""):
        """Creates a ZFS storage pool.

        Creates a new storage pool containing the virtual devices
        specified on the command line. The pool name must begin with a
        letter, and can only contain alphanumeric characters as well as
        the underscore (“_”), dash (“-”), colon (“:”), space (“ ”), and
        period (“.”). The pool names mirror, raidz, draid, spare and log
        are reserved, as are names beginning with mirror, raidz, draid,
        and spare.

        Parameters
        ----------
        name : str
            The name of the pool.
        disks : Path
            List of absolute path to the disk(s) to add to the pool.
        vdev_type : str
            The type of virtual device to create from the disks. If an
            empty string, will create a non-redundant pool using all the
            disks. Valid values are an empty string, 'mirror', 'raidz1',
            'raidz2', and 'raidz3'.
        """
        self._valid_vdev_type(vdev_type=vdev_type)

        disks_str = [str(disk) for disk in disks]
        return " ".join((str(self), name, vdev_type, *disks_str))


@dataclass
class ZDataset:
    """Create ZFS datasets."""

    zfsprops: ZfsProps

    def __post_init__(self):
        self.zfsprops = self.zfsprops

    def __str__(self):
        return " ".join(("zfs create", str(self.zfsprops)))

    def create(self, filesystem: Path):
        """Creates a new ZFS file system.

        Parameters
        ----------
        filesystem : Path
            The dataset path to create.
        """
        return " ".join((str(self), str(filesystem)))


def demo():
    """Demonstrate classes and functions in this module."""
    zpoolprops = ZPoolProps(
        altroot=Path("/mnt"), ashift=12, autotrim="on", compatibility="grub"
    )
    print(zpoolprops)
    print()

    zpoolprops = ZPoolProps(ashift=12, autotrim="on", compatibility="grub")
    zfsprops = ZfsProps(
        prefix="O",
        atime="on",
        acltype="posixacl",
        canmount="off",
        compression="lz4",
        devices="off",
        dnodesize="auto",
        encryption="aes-256-gcm",
        keylocation="prompt",
        keyformat="passphrase",
        mountpoint=Path("/"),
        normalization="formD",
        relatime="on",
        xattr="sa",
    )
    print(zpoolprops)
    print(zfsprops)
    print()

    zpool = ZPool(zpoolprops=zpoolprops, zfsprops=zfsprops)
    print(
        zpool.create(
            name="pool",
            disks=[Path("/dev/disk/by-id/diskA"), Path("/dev/disk/by-id/diskB")],
        )
    )
    print(
        zpool.create(
            name="pool",
            disks=[Path("/dev/disk/by-id/diskA"), Path("/dev/disk/by-id/diskB")],
            vdev_type="mirror",
        )
    )
    print()

    zfsprops = ZfsProps(prefix="o", canmount="off", mountpoint=Path("/"))
    zdataset = ZDataset(zfsprops=zfsprops)
    print(zdataset.create(Path("pool/root")))


if __name__ == "__main__":
    demo()
