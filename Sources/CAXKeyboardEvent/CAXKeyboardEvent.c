#include "CAXKeyboardEvent.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

AXError CAXPostKeyboardEvent(AXUIElementRef application, CGCharCode keyChar, CGKeyCode virtualKey, Boolean keyDown) {
    return AXUIElementPostKeyboardEvent(application, keyChar, virtualKey, keyDown);
}

#pragma clang diagnostic pop
