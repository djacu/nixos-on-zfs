#!/bin/bash


function log10 () {
    local val=$1
    echo "l($val) / l(10)" | bc -l
    # echo 5
}


function floor () {
    local val=$1
    # echo "$val+0.5" | bc -l
    # echo "$(printf %.0f $(echo "$val+0.5" | bc -l))"
    echo "scale = 0; ($val) / 1" | bc
    # echo $val
    # echo $((val+1))
}


function ceil () {
    local val=$1
    # echo "scale = 0; ($val + 0.5) / 1" | bc
    # echo "scale = 0; if ( $val % 1 ) $val / 1 + 1 else $val / 1" | bc
    echo "scale = 0; if ( $val % 1 ) $(floor $val) + 1 else $(floor $val)" | bc
}


function num_digits () {
    local val=$1
    echo "$( floor $( log10 $val ) ) + 1" | bc
}
