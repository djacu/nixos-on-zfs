import os

from pybootstrap import configure, install, partition, prepare


def _verify_root():
    if os.geteuid() != 0:
        exit(
            "\n".join(
                [
                    "You need to have root privileges to run this script.",
                    "Please try again, this time using 'sudo'. Exiting.",
                ]
            )
        )


def main():
    # _verify_root()
    config = prepare.prepare()
    partition.partition(config=config)
    configure.configure(config=config)
    install.install(config=config)


if __name__ == "__main__":
    main()
