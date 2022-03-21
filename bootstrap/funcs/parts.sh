#!/bin/bash


# Queries the user to specify a partition size and stores it in a given
# variable. Modifies the given variable by using namerefs to receive it
# by reference. The function requires a string to describe the partition
# as well as a default value.
#
# $1 - The variable name that will hold partition size.
# $2 - A descriptive name or title of the partition.
# $3 - The default value (in GB) for the partition.
#
# Examples
#
#   set_partition_size INST_PARTSIZE_ESP "ESP" 2
#       Set ESP partition size in GB [2]: 4
#   echo $INST_PARTSIZE_ESP
#       4
function set_partition_size()
{
    local -n ref=$1
    read -p "Set $2 partition size in GB [$3]: " ref
    ref=${ref:-$3}
}


# Returns the total amount of physical system memory.
#
# Options
#   -s  Converts the output to the size specified.
#       byte = bytes
#       kibi = kibibyte
#       mebi = mebibyte
#       gibi = gibibyte (default)
#       kilo = kilobyte
#       mega = megabyte
#       giga = gigabyte
#
# Examples
#   get_system_memory
#       31.29492568969726562500
#   get_system_memory -s byte
#       33602670592.00000000000000000000
#   get_system_memory -s kibi
#       32815108.00000000000000000000
#   get_system_memory -s mebi
#       32046.00390625000000000000
#   get_system_memory -s gibi
#       31.29492568969726562500
#
function get_system_memory()
{
    while getopts ":s:" opt; do
        case $opt in
            s)
                local size="$OPTARG"
                ;;
            \?)
                echo "Invalid option -$OPTARG" >&2;
                exit 1
                ;;
        esac
    done
    local size=${size:-gibi}
    local sys_mem=$(free --bytes | awk '/^Mem:/{print $2}')

    case $size in
        byte) echo "$sys_mem / 1" | bc -l;;
        kibi) echo "$sys_mem / (1024 ^ 1)" | bc -l;;
        mebi) echo "$sys_mem / (1024 ^ 2)" | bc -l;;
        gibi) echo "$sys_mem / (1024 ^ 3)" | bc -l;;
        kilo) echo "$sys_mem / (1000 ^ 1)" | bc -l;;
        mega) echo "$sys_mem / (1000 ^ 2)" | bc -l;;
        giga) echo "$sys_mem / (1000 ^ 3)" | bc -l;;
    esac
}
