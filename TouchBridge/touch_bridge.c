#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define MT_FW "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"

typedef struct {
    int32_t frame, pad0;
    double timestamp;
    int32_t pathIndex, state, fingerID, handID;
    float norm_x, norm_y, vel_x, vel_y, size, pressure, angle;
    float majorAxis, minorAxis, density, abs_x, abs_vel_x, abs_vel_y;
    int32_t reserved1, reserved2;
    float zPressure;
} MTTouch;

typedef CFMutableArrayRef (*CreateListFn)(void);
typedef void (*ContactCallback)(void *, MTTouch *, int, double, int);
typedef void (*RegisterFn)(void *, ContactCallback);
typedef void (*StartFn)(void *, int);
typedef void (*StopFn)(void *);

static volatile sig_atomic_t running = 1;
static CFRunLoopRef runloop;

static void stop_handler(int sig) {
    (void)sig;
    running = 0;
    if (runloop) CFRunLoopStop(runloop);
}

static void contact_callback(void *device, MTTouch *touches, int count,
                             double timestamp, int frame) {
    (void)device;
    printf("{\"frame\":%d,\"timestamp\":%.6f,\"touches\":[", frame, timestamp);
    for (int i = 0; i < count; i++) {
        MTTouch *t = &touches[i];
        if (i) putchar(',');
        printf("{\"id\":%d,\"state\":%d,\"x\":%.5f,\"y\":%.5f,"
               "\"pressure\":%.4f,\"size\":%.4f,\"major\":%.4f,"
               "\"minor\":%.4f,\"density\":%.4f,\"zPressure\":%.4f}",
               t->pathIndex, t->state, t->norm_x, t->norm_y, t->pressure,
               t->size, t->majorAxis, t->minorAxis, t->density, t->zPressure);
    }
    puts("]}");
    fflush(stdout);
}

int main(void) {
    void *handle = dlopen(MT_FW, RTLD_LAZY);
    if (!handle) { fprintf(stderr, "framework_unavailable\n"); return 2; }
    CreateListFn createList = (CreateListFn)dlsym(handle, "MTDeviceCreateList");
    RegisterFn registerCallback = (RegisterFn)dlsym(handle, "MTRegisterContactFrameCallback");
    StartFn startDevice = (StartFn)dlsym(handle, "MTDeviceStart");
    StopFn stopDevice = (StopFn)dlsym(handle, "MTDeviceStop");
    if (!createList || !registerCallback || !startDevice || !stopDevice) {
        fprintf(stderr, "symbols_unavailable\n"); return 3;
    }
    CFMutableArrayRef devices = createList();
    if (!devices || CFArrayGetCount(devices) == 0) {
        fprintf(stderr, "no_trackpad\n"); return 4;
    }
    void *device = (void *)CFArrayGetValueAtIndex(devices, 0);
    signal(SIGTERM, stop_handler);
    signal(SIGINT, stop_handler);
    runloop = CFRunLoopGetCurrent();
    registerCallback(device, contact_callback);
    startDevice(device, 0);
    fprintf(stderr, "touchbridge_ready\n");
    while (running) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
    stopDevice(device);
    CFRelease(devices);
    dlclose(handle);
    return 0;
}
