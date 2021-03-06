//
//  SIApplication.m
//  Silica
//

#import "SIApplication.h"

#import "SIWindow.h"
#import "SIUniversalAccessHelper.h"
#import "SISystemWideElement.h"
#import <BBLBasics/BBLBasics.h>



@implementation SIAXNotificationData
@end


@interface SIApplicationObservation : NSObject
@property (nonatomic, copy) NSString *notification;
@end

@implementation SIApplicationObservation
@end


@interface SIApplication ()

@property (nonatomic, assign) AXObserverRef observerRef;
@property (nonatomic, strong) NSMutableDictionary *elementToObservations;

@property (nonatomic, strong) NSMutableArray *cachedWindows;

@property(readonly) NSURL* bundleUrl;

@end


@implementation SIApplication

#pragma mark Lifecycle

// NOTE this method will implicitly instantiate new SIApplications.
// if the caller then uses these instances to observe elemnts, the instances then cease to act as value types.
// in fact, since SIAccessibilityElement's equality defers to the AXUIElement it wraps, value equality was never clear to begin with.
// so, beware that SIApplications which act as observers need to be well-managed by the caller.
+ (instancetype)applicationWithRunningApplication:(NSRunningApplication *)runningApplication {
  @autoreleasepool {
    AXUIElementRef axElementRef = AXUIElementCreateApplication(runningApplication.processIdentifier);
    if (axElementRef) {
      id path = runningApplication.bundleURL;
      SIApplication *application = [[SIApplication alloc] initWithAXElement:axElementRef bundleURL:path];
      CFRelease(axElementRef);
      return application;
    }
    else {
      return nil;
    }
  }
}

+ (instancetype)applicationForProcessIdentifier:(pid_t)processIdentifier {
  NSRunningApplication* runningApp = [NSRunningApplication runningApplicationWithProcessIdentifier:processIdentifier];
  return [self applicationWithRunningApplication:runningApp];
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

+(SIApplication* _Nullable) focusedApplication {
  SIAccessibilityElement* appElement = [SISystemWideElement.systemWideElement elementForKey:kAXFocusedApplicationAttribute];
  if (appElement) {
    SIApplication* application = [[SIApplication alloc] initWithAXElement:appElement.axElementRef];
    return application;
  }
  else {
    return nil;
  }
}


- (instancetype)initWithAXElement:(AXUIElementRef)axElementRef bundleURL:(NSURL*)url
{
  self = [super initWithAXElement:axElementRef];
  if (self) {
    _bundleUrl = url;
  }
  return self;
}

-(NSString*) description {
  return [NSString stringWithFormat:@"%@ %@", super.description, _bundleUrl.description];
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

void observerCallback(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, CFDictionaryRef info, void *refcon) {
  
  SIAccessibilityElement *siElement =  [[SIAccessibilityElement alloc] initWithAXElement:element];
  
  // create the most specific si element type possible.
  id role = siElement.role;
  if ([role isEqual:(NSString *)kAXWindowRole]) {
    siElement = [[SIWindow alloc] initWithAXElement:element];
  }
  else if ([role isEqual:(NSString *)kAXApplicationRole]) {
    siElement = [[SIApplication alloc] initWithAXElement:element];
  }
  
  // guard against invalid / terminated pids.
  if (siElement.processIdentifier == 0) {
    NSLog(@"WARN no running application for element: %@", siElement);
    return;
  }
  
  SIAXNotificationData* axData = [[SIAXNotificationData alloc] init];
  axData.axNotification = notification;
  axData.siElement = siElement;
  
  [NSNotificationCenter.defaultCenter
   postNotificationName:AX_EVENT_NOTIFICATION
   object:siElement
   userInfo:@{ AX_EVENT_NOTIFICATION_DATA: axData }];
}


- (BOOL)observeNotification:(CFStringRef)notification withElement:(SIAccessibilityElement *)accessibilityElement {
  
  if (!self.observerRef) {
    AXObserverRef observerRef;
    AXError error = AXObserverCreateWithInfoCallback(self.processIdentifier, &observerCallback, &observerRef);
    if (error != kAXErrorSuccess) return NO;
    
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observerRef), kCFRunLoopDefaultMode);
    
    self.observerRef = observerRef;
    self.elementToObservations = [NSMutableDictionary dictionaryWithCapacity:1];
  }
  
  SIApplicationObservation *observation = [[SIApplicationObservation alloc] init];
  
  observation.notification = (__bridge NSString *)notification;
  
  AXError error = AXObserverAddNotification(self.observerRef, accessibilityElement.axElementRef, notification, nil);
  
  if (error != kAXErrorSuccess) return NO;
  
  if (!self.elementToObservations[accessibilityElement]) {
    self.elementToObservations[accessibilityElement] = [NSMutableArray array];
  }
  [self.elementToObservations[accessibilityElement] addObject:observation];
  
  return YES;
}

- (void)unobserveNotification:(CFStringRef)notification withElement:(SIAccessibilityElement *)accessibilityElement {
    for (SIApplicationObservation *observation in self.elementToObservations[accessibilityElement]) {
        if ([observation.notification isEqualToString:(__bridge NSString*) notification]) {
            AXObserverRemoveNotification(self.observerRef, accessibilityElement.axElementRef, notification);
        }
    }
}

#pragma mark Public Accessors

- (NSArray<SIWindow *> *)windows {
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
  
  return [self.windows filterWith:^BOOL(SIWindow* window) {
    return window.isVisible;
  }];

}

-(SIWindow* _Nullable) focusedWindow {
//  return self.visibleWindows.firstObject;
// TMP
//  return [SIWindow focusedWindow];
  
//  if (applicationRef) {
  CFTypeRef windowRef;
  
  AXError result = AXUIElementCopyAttributeValue(self.axElementRef, kAXFocusedWindowAttribute, &windowRef);
    
//    CFRelease(applicationRef);
  SIWindow* window = nil;
  if (result == kAXErrorSuccess) {
    window = [[SIWindow alloc] initWithAXElement:windowRef];
    
    if ([window isSheet]) {
      SIAccessibilityElement *parent = [window elementForKey:kAXParentAttribute];
      if (parent) {
        window = [[SIWindow alloc] initWithAXElement:parent.axElementRef];
      }
    }
    
  }
//  }
  
  if (windowRef) CFRelease(windowRef);
  
  return window;
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
