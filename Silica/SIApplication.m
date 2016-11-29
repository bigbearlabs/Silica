//
//  SIApplication.m
//  Silica
//

#import "SIApplication.h"

#import "SIWindow.h"
#import "SIUniversalAccessHelper.h"

@interface SIApplicationObservation : NSObject
@property (nonatomic, strong) NSString *notification;
@property (nonatomic, copy) SIAXNotificationHandler handler;
@end

@implementation SIApplicationObservation
@end

@interface SIApplication ()
@property (nonatomic, assign) AXObserverRef observerRef;
@property (nonatomic, strong) NSMutableDictionary *elementToObservations;

@property (nonatomic, strong) NSMutableArray *cachedWindows;
@end

@implementation SIApplication

#pragma mark Lifecycle

+ (instancetype)applicationWithRunningApplication:(NSRunningApplication *)runningApplication {
    AXUIElementRef axElementRef = AXUIElementCreateApplication(runningApplication.processIdentifier);
    SIApplication *application = [[SIApplication alloc] initWithAXElement:axElementRef];
    CFRelease(axElementRef);
    return application;
}

+ (NSArray *)runningApplications {
    if (![SIUniversalAccessHelper isAccessibilityTrusted])
        return nil;

    NSMutableArray *apps = [NSMutableArray array];

    for (NSRunningApplication *runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
        SIApplication *app = [SIApplication applicationWithRunningApplication:runningApp];
        [apps addObject:app];
    }

    return apps;
}

- (void)dealloc {
    if (_observerRef) {
        for (SIAccessibilityElement *element in self.elementToObservations.allKeys) {
            for (SIApplicationObservation *observation in self.elementToObservations[element]) {
                AXObserverRemoveNotification(_observerRef, element.axElementRef, (__bridge CFStringRef)observation.notification);
            }
        }
        CFRelease(_observerRef);
    }
}

#pragma mark AXObserver

void observerCallback(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *refcon) {
  // reinitialise to more specific si element type.
  SIAccessibilityElement *siElement = [[SIAccessibilityElement alloc] initWithAXElement:element];
  if ([siElement.role isEqualToString:kAXWindowRole]) {
    siElement = [[SIWindow alloc] initWithAXElement:element];
  }
  else if ([siElement.role isEqualToString:kAXApplicationRole]) {
    siElement = [[SIApplication alloc] initWithAXElement:element];
  }

  SIApplicationObservation* observation = (__bridge SIApplicationObservation*)refcon;

  // ensure the pid is good before continuing.
  if ([NSRunningApplication runningApplicationWithProcessIdentifier:siElement.processIdentifier] != nil) {
    observation.handler(siElement);
  } else {
    NSLog(@"WARN no running application for pid %@, thought to be %@", @(siElement.processIdentifier), siElement.app);
    return;
  }
}

- (void)observeNotification:(CFStringRef)notification withElement:(SIAccessibilityElement *)accessibilityElement handler:(SIAXNotificationHandler)handler {
    if (!self.observerRef) {
        AXObserverRef observerRef;
        AXError error = AXObserverCreate(self.processIdentifier, &observerCallback, &observerRef);

        if (error != kAXErrorSuccess) return;

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observerRef), kCFRunLoopDefaultMode);

        self.observerRef = observerRef;
        self.elementToObservations = [NSMutableDictionary dictionaryWithCapacity:1];
    }

    SIApplicationObservation *observation = [[SIApplicationObservation alloc] init];
    observation.notification = (__bridge NSString *)notification;
    observation.handler = handler;

    if (!self.elementToObservations[accessibilityElement]) {
        self.elementToObservations[accessibilityElement] = [NSMutableArray array];
    }
    [self.elementToObservations[accessibilityElement] addObject:observation];

//    AXObserverAddNotification(self.observerRef, accessibilityElement.axElementRef, notification, (__bridge void *)observation.handler);
      AXObserverAddNotification(self.observerRef, accessibilityElement.axElementRef, notification, (__bridge void *)observation);
}

- (void)unobserveNotification:(CFStringRef)notification withElement:(SIAccessibilityElement *)accessibilityElement {
    for (SIApplicationObservation *observation in self.elementToObservations[accessibilityElement]) {
        AXObserverRemoveNotification(self.observerRef, accessibilityElement.axElementRef, (__bridge CFStringRef)observation.notification);
    }
    [self.elementToObservations removeObjectForKey:accessibilityElement];
}

#pragma mark Public Accessors

- (NSArray *)windows {
    if (!self.cachedWindows) {
        self.cachedWindows = [NSMutableArray array];
        NSArray *windowRefs = [self arrayForKey:kAXWindowsAttribute];
        for (NSUInteger index = 0; index < windowRefs.count; ++index) {
            AXUIElementRef windowRef = (__bridge AXUIElementRef)windowRefs[index];
            SIWindow *window = [[SIWindow alloc] initWithAXElement:windowRef];

            [self.cachedWindows addObject:window];
        }
    }
    return self.cachedWindows;
}

- (NSArray *)visibleWindows {
    return [self.windows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SIWindow *window, NSDictionary *bindings) {
        return ![[window app] isHidden] && ![window isWindowMinimized] && [window isNormalWindow];
    }]];
}

- (NSString *)title {
    return [self stringForKey:kAXTitleAttribute];
}

- (BOOL)isHidden {
    return [[self numberForKey:kAXHiddenAttribute] boolValue];
}

- (void)hide {
    [[NSRunningApplication runningApplicationWithProcessIdentifier:self.processIdentifier] hide];
}

- (void)unhide {
    [[NSRunningApplication runningApplicationWithProcessIdentifier:self.processIdentifier] unhide];
}

- (void)kill {
    [[NSRunningApplication runningApplicationWithProcessIdentifier:self.processIdentifier] terminate];
}

- (void)kill9 {
    [[NSRunningApplication runningApplicationWithProcessIdentifier:self.processIdentifier] forceTerminate];
}

- (void)dropWindowsCache {
    self.cachedWindows = nil;
}


-(NSRunningApplication*) runningApplication {
  return [NSRunningApplication runningApplicationWithProcessIdentifier:self.processIdentifier];
}
@end
