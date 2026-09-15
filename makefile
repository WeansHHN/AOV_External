# export THEOS=/var/mobile/theos
ARCHS := arm64
# TARGET = iphone:clang:latest:16.5
TARGET = iphone:clang:15.6:14.0
export THEOS_USE_MODERN_BUILD_SYSTEM = 1
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
INSTALL_TARGET_PROCESSES := AOV_External

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := AOV_External

$(APPLICATION_NAME)_USE_MODULES := 0

$(APPLICATION_NAME)_FILES += $(wildcard sources/*.mm sources/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard sources/KIF/*.mm sources/KIF/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard esp/drawing_view/*.m esp/drawing_view/*.mm esp/drawing_view/*.cpp)
$(APPLICATION_NAME)_FILES += $(wildcard esp/helpers/*.m esp/helpers/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard esp/unity_api/*.m esp/unity_api/*.mm)

sources/KIF/UITouch-KIFAdditions.m_CFLAGS := $(filter-out -mllvm -enable-fco,$(AOV_External_CFLAGS))

ADDITIONAL_CCFLAGS += -std=c++17
ADDITIONAL_CCFLAGS += -stdlib=libc++
ADDITIONAL_CCFLAGS += -fobjc-arc

$(APPLICATION_NAME)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-module-import-in-extern-c
$(APPLICATION_NAME)_OBJCCFLAGS += -fobjc-arc

$(APPLICATION_NAME)_CXXFLAGS += -std=c++17
$(APPLICATION_NAME)_OBJCXXFLAGS += -std=c++17

$(APPLICATION_NAME)_CFLAGS += -Iheaders
$(APPLICATION_NAME)_CFLAGS += -Isources
$(APPLICATION_NAME)_CFLAGS += -Isources/KIF
$(APPLICATION_NAME)_CFLAGS += -DNOTIFY_DESTROY_HUD="\"dev.metaware.external.hud.destroy\""
$(APPLICATION_NAME)_CFLAGS += -DPID_PATH="@\"/var/mobile/Library/Caches/dev.metaware.external.pid\""

$(APPLICATION_NAME)_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit AVFoundation AudioToolbox CoreMedia
$(APPLICATION_NAME)_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices

$(APPLICATION_NAME)_CODESIGN_FLAGS += -Slayout/entitlements.plist
$(APPLICATION_NAME)_RESOURCE_DIRS = ./layout/Resources

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-all::
	@rm -rf packages
	@mkdir -p Payload
	@cp -R .theos/obj/$(APPLICATION_NAME).app Payload
	@zip -rq $(APPLICATION_NAME).tipa Payload
	@rm -rf Payload
	@mkdir -p packages
	@mv $(APPLICATION_NAME).tipa packages