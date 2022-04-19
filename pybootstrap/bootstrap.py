from pybootstrap import partition
from pybootstrap import prepare


def main():
    config = prepare.prepare()
    partition.partition(config=config)


if __name__ == "__main__":
    main()
