#!/bin/bash


# Calculates log10 of a given value.
#
# $1 - The given value.
#
# Examples
#
#   log10 1
#       0
#   log10 2
#       .30102999566398119521
#   log10 10
#       1.00000000000000000000
function log10 () {
    local val=$1
    echo "l($val) / l(10)" | bc -l
}


# Calculates floor of a given value. Only verified for positive values.
#
# $1 - The given value.
#
# Examples
#
#   floor 1
#       0
#   floor 1.4
#       1
#   floor 2.999999999999999
#       2
function floor () {
    local val=$1
    echo "scale = 0; ($val) / 1" | bc
}


# Calculates ceil of a given value. Only verified for positive values.
#
# $1 - The given value.
#
# Examples
#
#   ceil 1
#       1
#   ceil 1.4
#       2
#   ceil 2.000000000000001
#       3
function ceil () {
    local val=$1
    echo "scale = 0; if ( $val % 1 ) $(floor $val) + 1 else $(floor $val)" | bc
}


# Finds the number of digits of a given value. Only verified for positive values.
#
# $1 - The given value.
#
# Examples
#
#   num_digits 1
#       1
#   num_digits 10
#       2
#   num_digits 999
#       3
function num_digits () {
    local val=$1
    echo "$( floor $( log10 $val ) ) + 1" | bc
}
