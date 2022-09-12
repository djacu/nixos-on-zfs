from unittest import TestCase

from testfixtures.comparison import compare
from testfixtures.popen import MockPopen
from testfixtures.replace import Replacer

from pybootstrap.disks import BlockDevice, get_block_devices


class TestBlockDevices(TestCase):
    def setUp(self):
        self.Popen = MockPopen()
        self.r = Replacer()
        self.r.replace("subprocess.Popen", self.Popen)
        self.addCleanup(self.r.restore)

    def test_example(self):
        # set up
        stdout = b"""
        {                                                                                                                                                             "blockdevices": [
                {
                    "name":"loop0",
                    "kname":"loop0",
                    "path":"/dev/loop0",
                    "model":null,
                    "serial":null,
                    "size":"4K",
                    "type":"loop"
                },
                {
                    "name":"loop1",
					"kname":"loop1",
					"path":"/dev/loop1",
					"model":null,
					"serial":null,
					"size":"113.9M",
					"type":"loop"
                },
                {
                    "name":"hda",
					"kname":"hda",
					"path":"/dev/hda",
					"model":"Toshiba_S300Pro",
					"serial":"1234567890",
					"size":"9.9TB",
					"type":"disk"
                },
                {
                    "name":"sda",
					"kname":"sda",
					"path":"/dev/sda",
					"model":"SanDisk_SD9SN8W512G",
					"serial":"183347423947",
					"size":"465.8G",
					"type":"disk"
                },
                {
                    "name":"nvme0n1",
					"kname":"nvme0n1",
					"path":"/dev/nvme0n1",
					"model":"Samsung SSD 970 PRO 1TB",
					"serial":"S462NF0K816201E",
					"size":"953.9G",
					"type":"disk"
                }
            ]
        }"""
        lsblk_cmd = "lsblk -d --json -o name,kname,path,model,serial,size,type"
        self.Popen.set_command(lsblk_cmd, stdout=stdout, stderr=b"e")

        # testing of results
        truth = [
            BlockDevice(
                name="hda",
                kname="hda",
                path="/dev/hda",
                model="Toshiba_S300Pro",
                serial="1234567890",
                size="9.9TB",
                type="disk",
                id="",
            ),
            BlockDevice(
                name="sda",
                kname="sda",
                path="/dev/sda",
                model="SanDisk_SD9SN8W512G",
                serial="183347423947",
                size="465.8G",
                type="disk",
                id="",
            ),
            BlockDevice(
                name="nvme0n1",
                kname="nvme0n1",
                path="/dev/nvme0n1",
                model="Samsung SSD 970 PRO 1TB",
                serial="S462NF0K816201E",
                size="953.9G",
                type="disk",
                id="",
            ),
        ]
        compare(get_block_devices(), truth)
