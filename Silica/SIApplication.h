//
//  SIApplication.h
//  Silica
//

#import "SIAccessibilityElement.h"
#import "SIWindow.h"



#define AX_EVENT_NOTIFICATION @"AX_EVENT_NOTIFICATION"
#define AX_EVENT_NOTIFICATION_DATA @"AX_EVENT_NOTIFICATION_DATA"


@interface SIAXNotificationData : NSObject

@property CFStringRef _Nonnull axNotification;
@property SIAccessibilityElement* _Nonnull siElement;

@end

NS_ASSUME_NONNULL_BEGIN

/**
 *  Block type for the handling of accessibility notifications.
 *
 *  @param accessibilityElement The accessibility element that the accessibility notification pertains to. Will always be an element either owned by the application or the application itself.
 */
typedef void (^SIAXNotificationHandler)(SIAccessibilityElement *accessibilityElement);

/**
 *  Accessibility wrapper for application elements.
 */
@interface SIApplication : SIAccessibilityElement

/**
 *  Attempts to construct an accessibility wrapper from an NSRunningApplication instance.
 *
 *  @param runningApplication A running application in the shared workspace.
 *
 *  @return A SIApplication instance if an accessibility element could be constructed from the running application instance. Returns nil otherwise.
 */
+ (instancetype)applicationWithRunningApplication:(NSRunningApplication *)runningApplication;


+ (instancetype)applicationForProcessIdentifier:(pid_t)processIdentifier;


/**
 *  Returns all SIApplication instaces for all running applications.
 *
 *  @return All SIApplication instaces for all running applications.
 */
+ (nullable NSArray *)runningApplications;

/**
 *  Returns the currently active application.
 *
 *  @return The currently active application.
 */
+(instancetype _Nullable) focusedApplication;



/**
 *  Returns an array of SIWindow objects for all windows in the application.
 *
 *  @return An array of SIWindow objects for all windows in the application.
 */
@property(readonly) NSArray<SIWindow *> *windows;

/**
 *  Registers a notification handler for an accessibility notification.
 *
 *  the notification handler is a function defined in the implementation of this class which posts an NSNotification with name AX_EVENT_NOTIFICATION, user info with key AX_EVENT_DATA_NOTIFICATION.
 *
 *  @param notification         The notification to register a handler for.
 *  @param accessibilityElement The accessibility element associated with the notification. Must be an element owned by the application or the application itself.
 *  @return YES if adding the observer succeeded, NO otherwise
 */
- (BOOL)observeNotification:(CFStringRef)notification withElement:(SIAccessibilityElement *)accessibilityElement;

/**
 *  Unregisters a notification handler for an accessibility notification.
 *
 *  If a notification handler was previously registered for the notification and accessibility element the application will unregister the notification handler and release its reference to the handler block and any captured state therein.
 *
 *  @param notification         The notification to unregister a handler for.
 *  @param accessibilityElement The accessibility element associated with the notification. Must be an element owned by the application or the application itself.
 */
- (void)unobserveNotification:(CFStringRef)notification withElement:(SIAccessibilityElement *)accessibilityElement;


/**
 *  Returns an array of SIWindow objects for all windows in the application that are currently visible.
 *
 *  @return An array of SIWindow objects for all windows in the application that are currently visible.
 */
- (NSArray *)visibleWindows;


-(SIWindow* _Nullable) focusedWindow;


/**
 *  Returns the title of the application.
 *
 *  @return The title of the application.
 */
- (nullable NSString *)title;

/**
 *  Returns a BOOL indicating whether or not the application is hidden.
 *
 *  @return YES if the application is hidden and NO otherwise.
 */
- (BOOL)isHidden;

/**
 *  Hides the application.
 */
- (void)hide;

/**
 *  Unhides the application.
 */
- (void)unhide;

/**
 *  Sends the application a kill signal.
 */
- (void)kill;

/**
 *  Sends the application a kill -9 signal.
 */
- (void)kill9;

/**
 *  Drops any cached windows so that the windows returned by a call to windows will be representative of the most up to date state of the application.
 */
- (void)dropWindowsCache;


-(NSRunningApplication*) runningApplication;


@end

NS_ASSUME_NONNULL_END
