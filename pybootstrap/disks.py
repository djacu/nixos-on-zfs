import glob
import json
import logging
import os
import subprocess
from typing import List, NamedTuple

logger = logging.getLogger(__name__)


class BlockDevice(NamedTuple):
    """Information about a block device."""

    name: str  # device name
    kname: str  # internal kernel device name
    path: str  # path to the device node
    model: str  # device identifier
    serial: str  # disk serial number
    size: str  # size of the device
    type: str  # device type
    id: str = ""  # disk-by-id (not from lsblk)


class DiskById(NamedTuple):
    """Information about disks by ID."""

    id: str
    path: str


def get_block_devices() -> List[BlockDevice]:
    """Creates a list of block devices that are disk types.

    Returns:
        A list of block devices.
    """
    # pylint: disable=no-member
    # pylint: disable=protected-access
    blk_fields = BlockDevice._fields
    non_blk_fields = BlockDevice._field_defaults.keys()
    lsblk_cols = ",".join((key for key in blk_fields if key not in non_blk_fields))

    with subprocess.Popen(
        f"lsblk -d --json -o {lsblk_cols}".split(), stdout=subprocess.PIPE
    ) as process:
        stdout_data, _ = process.communicate()
        process.terminate()

    block_devices = json.loads(stdout_data.decode("utf-8"))["blockdevices"]
    block_devices = [BlockDevice(**dev) for dev in block_devices]
    disks_only = list(filter(lambda dev: dev.type == "disk", block_devices))
    return disks_only


def get_disks_by_id() -> List[DiskById]:
    """Creates a list of block devices containing their 'by-id' path and
    /dev/ absolute path.

    Returns:
        A list of disks.
    """
    disks_by_id = glob.glob("/dev/disk/by-id/*")
    sym_links = [os.path.realpath(disk) for disk in disks_by_id]

    disks_with_symlink = [
        DiskById(id=id, path=path) for id, path in zip(disks_by_id, sym_links)
    ]
    return disks_with_symlink
