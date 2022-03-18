#!/bin/bash


function disks_by_id_symbolic () {
    echo "$(stat --format="%N" /dev/disk/by-id/* | column -t)"
}


function disk_by_id_kname () {
    # echo $1
    disk=$1
    # cut1="${disk##*">  '../../"}"
    # echo "${cut1%"'"*}"

    echo $disk | grep -oP "(?<='../../).*?(?=')"
    # echo $disk | grep -oP "'.*?'"
}


function disk_by_id_sympath () {
    # echo $1
    disk=$1
    # cut1="${disk##*">  '../../"}"
    # echo "${cut1%"'"*}"

    echo $disk | grep -oP "(?<=').*?(?=' ->)"
    # echo $disk | grep -oP "'.*?'"
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
declare temp=$(lsblk_filesystems)
filter_lsblk_by_disk "${temp[@]}"

# echo $(lsblk_filesystems)
# declare filtered_lsblk=$(filter_lsblk_by_disk "${temp[@]}")
# echo ${filtered_lsblk[@]}


function main2 () {
    while IFS= read -r disk; do
        echo $disk

        # echo "$(disk_by_id_kname "${disk[@]}")"
        # echo "$(disk_by_id_sympath "${disk[@]}")"

    done < <(printf '%s\n' "$(lsblk_filesystems)")
}


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
# main2
# disks_by_id_symbolic