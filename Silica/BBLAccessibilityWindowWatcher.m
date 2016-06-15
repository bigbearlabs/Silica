//
//  BBLAccessibilityWindowWatcher.m
//  NMTest001
//
//  Created by ilo on 15/04/2016.
//
//

#import "BBLAccessibilityWindowWatcher.h"


@implementation BBLAccessibilityWindowWatcher
{
  NSMutableArray* watchedApps;
}

// return non-primitive type to work around RM interface botch.
-(NSNumber*) isExcludedApp:(NSRunningApplication*) application {
  return nil;
}

-(NSArray*) applicationsToObserve {
  return [[NSWorkspace sharedWorkspace] runningApplications];
}


-(void) watchWindows {
  // on didlaunchapplication notif, observe.
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidLaunchApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    
    NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
    if (![self isExcludedApp:app]) {
      SIApplication* application = [SIApplication applicationWithRunningApplication:app];
      [self watchNotificationsForApp:application];
    } else {
      NSLog(@"%@ is excluded from observation", app);
    }
  }];
  
  // on terminateapplication notif, unobserve.
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidTerminateApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
    if (![self isExcludedApp:app]) {
      SIApplication* application = [SIApplication applicationWithRunningApplication:app];
      [self unwatchApp:application];
    } else {
      NSLog(@"%@ is excluded from observation", app);
    }
  }];
  
  // for all current apps, observe.
  for (NSRunningApplication* application in [self applicationsToObserve]) {
    if (![self isExcludedApp:application]) {
      id app = [SIApplication applicationWithRunningApplication:application];
      [self watchNotificationsForApp:app];
    } else {
      NSLog(@"%@ is excluded from observation", application);
    }

  }
  
  NSLog(@"%@ is watching the windows", self);
  
  // NOTE it still takes a while for the notifs to actually invoke the handlers. at least with concurrent set up we don't hog the main thread as badly as before.
}

-(void) unwatchWindows {
  // naive impl that loops through the running apps

  for (id application in [self applicationsToObserve]) {
    id app = [SIApplication applicationWithRunningApplication:application];
    [self unwatchApp:app];
    // FIXME this contends with the unobservation on app terminate.
  }
}


-(void) watchNotificationsForApp:(SIApplication*)application {
  [self concurrently:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [application observeNotification:kAXApplicationActivatedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self onApplicationActivated:accessibilityElement];
                               }];
      
      [application observeNotification:kAXFocusedWindowChangedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self onFocusedWindowChanged:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXWindowCreatedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self onWindowCreated:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXTitleChangedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self onTitleChanged:accessibilityElement];
                               }];

      // ABORT we ended up with far too many notifs when using this.
      //  [application observeNotification:kAXFocusedUIElementChangedNotification
      //                       withElement:application
      //                           handler:^(SIAccessibilityElement *accessibilityElement) {
      //                             [self onFocusedElementChanged:accessibilityElement];
      //                           }];
      

      
      if (!watchedApps) {
        watchedApps = [@[] mutableCopy];
      }
      [watchedApps addObject:application];
      
      NSLog(@"setup observers for %@", application);
    });
  }];
}

-(void) unwatchApp:(SIApplication*)application {
  [application unobserveNotification:kAXFocusedWindowChangedNotification withElement:application];
  [application unobserveNotification:kAXWindowCreatedNotification withElement:application];
  [application unobserveNotification:kAXApplicationActivatedNotification withElement:application];
  [application unobserveNotification:kAXTitleChangedNotification withElement:application];
}


-(void) concurrently:(void(^)(void))block {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    block();
  });
}

#pragma mark - handlers

-(void) onApplicationActivated:(SIAccessibilityElement*)element {
  NSLog(@"app activated: %@", element);
}

-(void) onFocusedWindowChanged:(SIWindow*)window {
  NSLog(@"focus: %@", window);
}

-(void) onWindowCreated:(SIWindow*)window {
  NSLog(@"new window: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onTitleChanged:(SIAccessibilityElement*)element {
  NSLog(@"title changed: %@", element);
}

//-(void) onFocusedElementChanged:(SIAccessibilityElement*)element {
//  NSLog(@"focused element: %@", element.focusedElement);
//}
//

@end



