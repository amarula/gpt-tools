#!/bin/bash -e

# set -x 

PARAMETER_FILE=${1:-parameter.txt}

GPT_IMG=gpt.img

LOADER1_START=64

declare -a PARTITION_NAME_LIST
declare -a PARTITION_LENGTH

PARTITION_NAME_LIST[0]="idbloader"
PARTITION_LENGTH[0]=$((0x4000))

IMAGE_LENGTH=$((0x4000))

REAL_LENGHT=$((IMAGE_LENGHT + 35 + 2 * 2 * 1024))

function get_partition(){
    num=1
	while read line; do
		i=0
		for token in ${line}; do
			case $i in
				0) partition_name=${token} ;;
				1) partition_lenght=${token} ;;
				2) partition_offset=${token} ;;
			esac
			let "i += 1"
		done
		[[ "${i}" -ne 3 ]] && echo "invalid parameter file" && exit 0
		
		PARTITION_NAME_LIST[${num}]=${partition_name}
		PARTITION_LENGTH[$num]=$((partition_lenght))
		PARTITION_NAME_OFFSET[$num]=$((partition_offset))
        IMAGE_LENGTH=$(($IMAGE_LENGTH + $partition_lenght))
		let "num += 1"
	done < "${PARAMETER_FILE}"
}

get_partition
echo ${PARTITION_LENGTH}

IMAGE_LENGTH=$((IMAGE_LENGTH + REAL_LENGTH))

echo "IMAGE_LENGTH:${IMAGE_LENGTH}"

dd if=/dev/zero of=${GPT_IMG} bs=512 count=0 seek=${IMAGE_LENGTH} status=none
parted -s ${GPT_IMG} mklabel gpt

for((i=0;i<${#PARTITION_NAME_LIST[*]};i++))
do
    partition_name=${PARTITION_NAME_LIST[$i]}
    partition_start=${PARTITION_NAME_OFFSET[$i]}
    partition_end=$((${partition_start} + ${PARTITION_LENGTH[$i]} - 1))
    if [ "$i" == "0" ];then
            partition_start=${LOADER1_START}
    fi
    printf "%-15s %-15s %-15s %-15sMB\n" ${partition_name}   ${partition_start}    ${partition_end} $(echo "scale=4;${PARTITION_LENGTH[$i]} / 2048" | bc)

    if [ "$i" == "$((${#PARTITION_NAME_LIST[*]} -1))" ];then
        parted -s ${GPT_IMG} -- unit s mkpart ${partition_name} ${partition_start}  -34s
    else
        parted -s ${GPT_IMG} unit s mkpart ${partition_name} ${partition_start} ${partition_end}
        if [ "${partition_name}" == "idbloader" ];then
            parted -s ${GPT_IMG} set $(($i + 1)) boot on
        fi
    fi

    if [ "${partition_name}" == "rootfs" ];then
        PARTID=$(($i + 1))
    fi
done

sgdisk --partition-guid=${PARTID}:614e0000-0000 ${GPT_IMG}
truncate -s ${REAL_LENGHT} ${GPT_IMG}