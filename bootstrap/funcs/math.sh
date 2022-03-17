#!/bin/bash


function log10 () {
    local val=$1
    echo "l($val) / l(10)" | bc -l
}


function floor () {
    local val=$1
    echo "scale = 0; ($val) / 1" | bc
}


function ceil () {
    local val=$1
    echo "scale = 0; if ( $val % 1 ) $(floor $val) + 1 else $(floor $val)" | bc
}


function num_digits () {
    local val=$1
    echo "$( floor $( log10 $val ) ) + 1" | bc
}
