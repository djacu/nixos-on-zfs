# nixos-dotfiles-work
A collection of setup scripts for installing NixOS root on ZFS.

## Bootstrap

Run the following commands:

```shell
# If you are running on a live ISO, you must use sudo to update the correct channel.
sudo nix-channel --update

nix-shell

poetry install

nix-build

sudo $(nix-build --no-out-link)/bin/python
```

This should put you in an interactive python shell. Now run the following:

```python
from pybootstrap import bootstrap
bootstrap.main()
```

Follow the interactive prompts and reboot the system when it's done.