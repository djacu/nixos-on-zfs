import json
import logging
import subprocess
from typing import Dict, List, NamedTuple

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
