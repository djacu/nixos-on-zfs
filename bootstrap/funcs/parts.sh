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
