// Send the configured Ctrl+Option+Arrow through the hardware event route.
// Hammerspoon's normal keyStroke posts private-source events at the session tap.
#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 2) {
        fputs("usage: space-key left|right|--check\n", stderr);
        return 64;
    }
    if (!CGPreflightPostEventAccess()) {
        fputs("Event posting is not authorized for the helper's responsible application\n", stderr);
        return 77;
    }
    if (strcmp(argv[1], "--check") == 0) return 0;
    CGKeyCode key;
    if (strcmp(argv[1], "left") == 0) key = 123;
    else if (strcmp(argv[1], "right") == 0) key = 124;
    else return 64;

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (!source) return 70;
    CGEventSourceSetLocalEventsSuppressionInterval(source, 0);
    CGEventRef down = CGEventCreateKeyboardEvent(source, key, true);
    CGEventRef up = CGEventCreateKeyboardEvent(source, key, false);
    if (!down || !up) {
        if (down) CFRelease(down);
        if (up) CFRelease(up);
        CFRelease(source);
        return 70;
    }
    CGEventFlags flags = kCGEventFlagMaskControl | kCGEventFlagMaskAlternate
                      | kCGEventFlagMaskSecondaryFn | kCGEventFlagMaskNumericPad;
    CGEventSetFlags(down, flags);
    CGEventSetFlags(up, flags);
    CGEventPost(kCGHIDEventTap, down);
    usleep(50000);
    CGEventPost(kCGHIDEventTap, up);
    CFRelease(down);
    CFRelease(up);
    CFRelease(source);
    return 0;
}
