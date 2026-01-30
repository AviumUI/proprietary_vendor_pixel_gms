#
# Copyright (C) 2020 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Google Battery
TARGET_DOES_NOT_SUPPORT_GOOGLE_BATTERY ?= true

# Include TurboAdapter without Google Battery support
ifeq ($(TARGET_DOES_NOT_SUPPORT_GOOGLE_BATTERY),true)
PRODUCT_PACKAGES += \
    TurboAdapter_NoBatt \
    libpowerstatshaldataprovider
endif

# GMS Props
PRODUCT_PRODUCT_PROPERTIES += \
    ro.opa.eligible_device=true

# GMS RRO overlay
PRODUCT_PACKAGES += \
	GoogleSettingsOverlay

$(call inherit-product, vendor/pixel/gms/common/common-vendor.mk)
