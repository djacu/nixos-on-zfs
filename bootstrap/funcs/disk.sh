#!/bin/bash

source ./math.sh


function disks_by_id_symbolic () {
    echo "$(stat --format="%N" /dev/disk/by-id/*)"
}


function disk_by_id_kname () {
    disk=$1
    echo $disk | grep -oP "(?<='../../).*?(?=')"
}


function disk_by_id_sympath () {
    disk=$1
    echo $disk | grep -oP "(?<=').*?(?=' ->)"
}


function lsblk_filesystems () (
    echo "$(lsblk -o kname,type)"
)


function filter_lsblk_by_disk () {
    declare devices=$1
    declare -a filtered=()

    while IFS= read -r disk; do
        local line=($disk)
        local kname=${line[0]}
        local type=${line[1]}

        if [[ $type == "disk" ]]; then
            filtered+=("$kname")
        fi
    done < <(printf '%s\n' "$devices")

    echo ${filtered[@]}
}


function get_only_disks () {
    local all_disks=$(disks_by_id_symbolic)

    declare filesystems=$(lsblk_filesystems)
    declare fs_disks=$(filter_lsblk_by_disk "${filesystems[@]}")

    while IFS= read -r disk; do
        local kname="$(disk_by_id_kname "${disk[@]}")"

        if [[ " ${fs_disks[*]} " =~ " ${kname} " ]]; then
            echo "${disk[@]}"
        fi
    done < <(printf '%s\n' "$all_disks")
}


function show_only_disks () {
    local only_disks=$(get_only_disks | column -t)
    local num_disks=$(get_only_disks | wc -l)
    local padding=$(num_digits "$num_disks")

    local count=1
    while IFS= read -r disk; do
        echo "Disk $(printf "%${padding}s" $count) is $disk" >&2
        ((count++))
    done < <(printf '%s\n' "$only_disks")
}


function select_only_disks_by_idx () {
    local idx=$1

    local only_disks=$(get_only_disks | column -t)
    local count=1
    while IFS= read -r disk; do
        if [[ $idx == $count ]]; then
            disk_by_id_sympath "${disk[@]}"
            break
        fi
        ((count++))
    done < <(printf '%s\n' "$only_disks")
}


function ask_for_disk_by_idx () {
    while true; do
        read -p "Select a disk by number. Return 0 or nothing to finish: " user_idx

        if [ -z $user_idx ]; then
            echo $user_idx
            break
        fi

        if [ $user_idx -eq 0 ]; then
            echo $user_idx
            break
        fi

        local re='^[0-9]+$'
        if ! [[ $user_idx =~ $re ]]; then
            echo "Not a number!" >&2
            continue
        fi

        local num_disks=$(get_only_disks | wc -l)
        if ! (( $user_idx >= 1 && $user_idx <= $num_disks )); then
            echo "$user_idx is out of bounds! Upper bound is $num_disks" >&2
            continue
        fi

        echo $user_idx
        break
    done
}


function add_disks_to_pool () {
    show_only_disks

    declare -a pool=()
    while true; do
        local idx=$(ask_for_disk_by_idx)

        if [ -z $idx ]; then
            break
        fi

        if [ $idx -eq 0 ]; then
            break
        fi

        local disk=$(select_only_disks_by_idx $idx)
        pool+=($disk)
    done
    echo ${pool[@]}
}


function ask_user_for_disks () {
    while true; do
        local disks=$(add_disks_to_pool)

        echo "" >&2
        echo "Are you satisfied with your disk(s) selection?" >&2
        echo "${disks[@]}" >&2
        select yn in "Yes" "No";
        do
            case $yn in
                Yes ) echo "${disks[@]}"; break 2;;
                No ) echo "" >&2; break 1;;
            esac
        done

    done
}


function main() {
    local DISK=$(ask_user_for_disks)
    echo ${DISK[@]}
}
main
