export TARGET = iphone:clang:6.1:6.1
export ARCHS = armv7
export THEOS_DEVICE_IP = 192.168.X.X 

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ScreenRec6

ScreenRec6_FILES = Tweak.xm
ScreenRec6_FRAMEWORKS = UIKit Foundation AVFoundation QuartzCore CoreMedia CoreVideo CoreGraphics
ScreenRec6_PRIVATE_FRAMEWORKS = IOSurface IOMobileFramebuffer

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += toggle

include $(THEOS_MAKE_PATH)/aggregate.mk