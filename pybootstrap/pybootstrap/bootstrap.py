from pybootstrap import configure, install, partition, prepare


def main():
    config = prepare.prepare()
    partition.partition(config=config)
    configure.configure(config=config)
    install.install(config=config)


if __name__ == "__main__":
    main()
