#!/bin/bash

source ../math.sh


function test_log10 () {
    declare -a ARRAY=(1 10 100 1000)
    declare -a TRUTH=(0  1   2    3)

    declare -i COUNT=0

    for idx in "${!ARRAY[@]}"; do
        actual=$(log10 "${ARRAY[idx]}")
        if [[ $(echo "$actual" != "${TRUTH[idx]}" | bc) -ne 0 ]]; then
            ((COUNT++))
            echo "${FUNCNAME[0]}: $actual not equal to ${TRUTH[idx]} at index $idx"
        fi
    done

    if [[ $COUNT == 0 ]]; then
        echo "${FUNCNAME[0]}: passed with no failures"
    fi
}


function test_num_digits () {
    declare -a ARRAY=(1 5 9 10 15 99 100 501 999 1000)
    declare -a TRUTH=(1 1 1  2  2  2   3   3   3    4)

    declare -i COUNT=0

    for idx in "${!ARRAY[@]}"; do
        actual=$(num_digits "${ARRAY[idx]}")
        if [[ $(echo "$actual" != "${TRUTH[idx]}" | bc) -ne 0 ]]; then
            ((COUNT++))
            echo "${FUNCNAME[0]}: $actual not equal to ${TRUTH[idx]} at index $idx"
        fi
    done

    if [[ $COUNT == 0 ]]; then
        echo "${FUNCNAME[0]}: passed with no failures"
    fi
}

test_log10
test_num_digits