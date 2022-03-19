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
        echo "Disk $(printf "%${padding}s" $count) is $disk"
        ((count++))
    done < <(printf '%s\n' "$only_disks")
}
show_only_disks


function main2 () {
    while IFS= read -r disk; do
        echo $disk

        # echo "$(disk_by_id_kname "${disk[@]}")"
        # echo "$(disk_by_id_sympath "${disk[@]}")"

    done < <(printf '%s\n' "$(lsblk_filesystems)")
}
# main2


function main () {
    local all_disks=$(stat --format="%N" /dev/disk/by-id/* | column -t)

    local COUNT=1
    local disk_array=()
    while IFS= read -r disk; do
        # echo "Disk $disk"
        echo "Disk $(printf "%2s" $COUNT) is $disk"
        # echo "Disk $COUNT is $disk"
        disk_array+=($disk)
        COUNT=$((COUNT+1))
    done < <(printf '%s\n' "$all_disks")

    echo "$all_disks" | wc -l
}
# main
