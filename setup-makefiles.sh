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
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/vendor/pixel/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" true

# Warning headers and guards
write_headers "arm64"
sed -i 's|TARGET_DEVICE|TARGET_ARCH|g' "${ANDROIDMK}"
sed -i 's|vendor/pixel/gms/|vendor/pixel/gms/common|g' "${PRODUCTMK}"
sed -i 's|device/pixel/gms//setup-makefiles.sh|vendor/pixel/gms/setup-makefiles.sh|g' "${ANDROIDBP}" "${ANDROIDMK}" "${BOARDMK}" "${PRODUCTMK}"

write_makefiles "${MY_DIR}/proprietary-files.txt" true

printf '\n%s\n' 'ifneq ($(WITH_GMS_COMMS_SUITE),false)' >> "$PRODUCTMK"

write_makefiles "${MY_DIR}/proprietary-files_cellular.txt" true

printf '%s\n' 'endif' >> "$PRODUCTMK"

printf '\n%s\n' 'ifeq ($(WITH_GMS_AICORE),true)' >> "$PRODUCTMK"

write_makefiles "${MY_DIR}/proprietary-files_aicore.txt" true

printf '%s\n' 'endif' >> "$PRODUCTMK"

# Finish
write_footers

# Overlays
echo -e "\ninclude vendor/pixel/gms/common/overlays.mk" >> $PRODUCTMK

# TurboAdapter
sed -i '/libpowerstatshaldataprovider/d' "${PRODUCTMK}"
if grep -q 'name: "TurboAdapter"' "${ANDROIDBP}"; then
    sed -i '/android_app_import {/,/}/ s|\(.*name: "TurboAdapter".*\)|\1\n    required: ["LibPowerStatsSymLink"],|' "${ANDROIDBP}"
fi

process_optional_libs() {
    local libs_file="${MY_DIR}/optional-libs.txt"
    [[ ! -f "$libs_file" ]] && { echo "No optional-libs.txt found, skipping."; return; }

    echo "Processing optional uses libraries from $libs_file..."
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local apk_path libs
        apk_path=$(echo "$line" | cut -d';' -f1)
        libs=$(echo "$line" | sed -n 's/.*LIBS=\(.*\)/\1/p')

        if [[ -n "$apk_path" && -n "$libs" ]]; then
            local libs_array search_path libs_entry
            libs_array=$(echo "$libs" | sed 's/,/\", \"/g')
            libs_entry="    optional_uses_libs: [\"$libs_array\"],"
            search_path="apk: \"proprietary/$apk_path\""

            if grep -q "$search_path" "${ANDROIDBP}"; then
                awk -v search="$search_path" -v insert="$libs_entry" '
                { print }
                $0 ~ search { print insert }
                ' "${ANDROIDBP}" > "${ANDROIDBP}.tmp" && mv "${ANDROIDBP}.tmp" "${ANDROIDBP}"
            else
                echo "Warning: APK path $search_path not found in ${ANDROIDBP}, skipping."
            fi
        fi
    done < "$libs_file"
}

process_optional_libs
