//
//  SIApplication.m
//  Silica
//

#import "SIApplication.h"

#import "SIWindow.h"
#import "SIUniversalAccessHelper.h"
#import <BBLBasics/BBLBasics.h>



@interface SIApplicationObservation : NSObject
@property (nonatomic, copy) NSString *notification;
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
  @autoreleasepool {
    AXUIElementRef axElementRef = AXUIElementCreateApplication(runningApplication.processIdentifier);
    if (axElementRef) {
      SIApplication *application = [[SIApplication alloc] initWithAXElement:axElementRef];
      CFRelease(axElementRef);
      return application;
    }
    else {
      return nil;
    }
  }
}

+ (NSArray *)runningApplications {
    if (![SIUniversalAccessHelper isAccessibilityTrusted])
        return nil;


  @autoreleasepool {
    NSMutableArray *apps = [NSMutableArray array];
      for (NSRunningApplication *runningApp in [[NSWorkspace sharedWorkspace] runningApplications]) {
          SIApplication *app = [SIApplication applicationWithRunningApplication:runningApp];
          [apps addObject:app];
      }
  
    return apps;
  }
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
  SIAccessibilityElement *siElement = [[SIAccessibilityElement alloc] initWithAXElement:element];

  // reinitialise to more specific si element type.
  if ([siElement.role isEqualToString:(NSString *)kAXWindowRole]) {
    siElement = [[SIWindow alloc] initWithAXElement:element];
  }
  else if ([siElement.role isEqualToString:(NSString *)kAXApplicationRole]) {
    siElement = [[SIApplication alloc] initWithAXElement:element];
  }
  
  // guard against invalid pids.
  id runningApp = [NSRunningApplication runningApplicationWithProcessIdentifier:siElement.processIdentifier];
  if (runningApp != nil && siElement.processIdentifier > 0) {
    SIAXNotificationHandler handler = (__bridge SIAXNotificationHandler)(refcon);
    handler(siElement);
  } else {
    NSLog(@"WARN no running application for pid %@. details: %@", @(siElement.processIdentifier), [runningApp debugDescription]);
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

    AXObserverAddNotification(self.observerRef, accessibilityElement.axElementRef, notification, (__bridge void *)observation.handler);
}

- (void)unobserveNotification:(CFStringRef)notification withElement:(SIAccessibilityElement *)accessibilityElement {
    for (SIApplicationObservation *observation in self.elementToObservations[accessibilityElement]) {
        if ([observation.notification isEqualToString:(__bridge NSString*) notification]) {
            AXObserverRemoveNotification(self.observerRef, accessibilityElement.axElementRef, notification);
        }
    }
}

#pragma mark Public Accessors

- (NSArray *)windows {
  @autoreleasepool {

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
}

- (NSArray *)visibleWindows {
  
  pid_t pid = self.processIdentifier;
  return [self.windows filterWith:^BOOL(SIWindow* window) {
    return window.isVisible;
  }];

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
