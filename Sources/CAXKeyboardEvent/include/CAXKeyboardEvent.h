#ifndef CAXKeyboardEvent_h
#define CAXKeyboardEvent_h

#include <ApplicationServices/ApplicationServices.h>

/// Wrapper around the deprecated AXUIElementPostKeyboardEvent.
/// Posts a keyboard event to the specified application element.
AXError CAXPostKeyboardEvent(AXUIElementRef application, CGCharCode keyChar, CGKeyCode virtualKey, Boolean keyDown);

#endif
