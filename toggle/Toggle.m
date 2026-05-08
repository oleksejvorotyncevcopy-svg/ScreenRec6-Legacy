#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

BOOL isCapable() {
    return YES;
}

BOOL isEnabled() {
    return [[NSFileManager defaultManager] fileExistsAtPath:@"/tmp/ScreenRec.active"];
}

void setState(BOOL enable) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.vorotyntsev.screenrec6.toggle" object:nil];
}

float getDelayTime() {
    return 0.5f;
}