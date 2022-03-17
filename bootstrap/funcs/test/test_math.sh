#!/bin/bash

call_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$call_dir/../math.sh"


function test_func_with_arrays () {
    local funcname=$1
    local -n domains=$2
    local -n truths=$3

    declare -i COUNT=0
    for idx in "${!domains[@]}"; do
        local actual=$($1 "${domains[idx]}")
        local truth="${truths[idx]}"

        if [[ $(echo "$actual" != "$truth" | bc) -ne 0 ]]; then
            ((COUNT++))
            echo "$funcname: $actual not equal to $truth at index $idx"
        fi
    done

    if [[ $COUNT == 0 ]]; then
        echo "$funcname: passed with no failures"
    fi
}


function test_log10 () {
    declare -a ARRAY=(1 10 100 1000)
    declare -a TRUTH=(0  1   2    3)
    test_func_with_arrays log10 ARRAY TRUTH
}
test_log10


function test_floor () {
    declare -a ARRAY=(0 0.0 0.1 0.49 0.5 0.51 0.9 1 1.0 1.1 1.49 1.5 1.51 1.99 2.0 2.4 2.5)
    declare -a TRUTH=(0   0   0    0   0    0   0 1   1   1    1   1    1    1   2   2   2)
    test_func_with_arrays floor ARRAY TRUTH
}
test_floor


function test_ceil () {
    declare -a ARRAY=(0 0.0 0.1 0.49 0.5 0.51 0.9 1 1.0 1.1 1.49 1.5 1.51 1.99 2.0 2.4 2.5)
    declare -a TRUTH=(0   0   1    1   1    1   1 1   1   2    2   2    2    2   2   3   3)
    test_func_with_arrays ceil ARRAY TRUTH
}
test_ceil


function test_num_digits () {
    declare -a ARRAY=(1 5 9 10 15 99 100 501 999 1000)
    declare -a TRUTH=(1 1 1  2  2  2   3   3   3    4)
    test_func_with_arrays num_digits ARRAY TRUTH
}
test_num_digits
