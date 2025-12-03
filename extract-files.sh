#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=common
VENDOR=pixel/gms

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/vendor/pixel/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function overlay_magic() {
    "${MY_DIR}/rro-utils/overlayMagic.sh" "$1" "$2" &
}

FWK_INSTALLED=0

overlay_install_fwk() {
    if [ "$FWK_INSTALLED" -eq 0 ]; then
        if [ -f "${SRC}/system/framework/framework-res.apk" ]; then
            apktool if "${SRC}/system/framework/framework-res.apk"
        fi
        if [ -f "${SRC}/system/system/framework/framework-res.apk" ]; then
            apktool if "${SRC}/system/system/framework/framework-res.apk"
        fi
        FWK_INSTALLED=1
    fi
}

function update_extservices() {
    "${MY_DIR}/extract-GoogleExtServices.sh" "$1" > /dev/null 2>&1 &
}

function beautify_rro() {
    local overlay_dir="${MY_DIR}/common/proprietary/product/overlay"

    find "$overlay_dir" -mindepth 1 -maxdepth 1 -type d | xargs -P"$(nproc)" -I {} "${MY_DIR}/rro-utils/beautify_rro.sh" "{}" > /dev/null 2>&1

    find "$overlay_dir" -type d \( -name "values*" -o -name "mipmap*" -o -name "drawable*" -o -name "raw*" \) | while read -r sub_dir; do
        if [ -z "$(ls -A "$sub_dir")" ]; then
            rm -r "$sub_dir"
        fi
    done
}

function blob_fixup() {
    case "${1}" in
        product/overlay/*apk)
            overlay_install_fwk
            overlay_magic "$1" "$2"
            ;;
        system/priv-app/GoogleExtServices/GoogleExtServices.apk)
            touch "${2}"
            ;;
    esac
}


if [ -z "$SRC" ]; then
    echo "Path to system dump not specified! Specify one with --path"
    exit 1
fi

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
extract "${MY_DIR}/proprietary-files_aicore.txt" "${SRC}" "${KANG}" --section "${SECTION}"
extract "${MY_DIR}/proprietary-files_cellular.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"

echo "Waiting for extraction"
wait
echo "Updating GoogleExtServices"
update_extservices "${SRC}"
echo "Beautifying rro's"
beautify_rro
echo "All done"
