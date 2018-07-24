//
//  NSRunningApplication+Manageable.m
//  Silica
//

#import "NSRunningApplication+Silica.h"

@implementation NSRunningApplication (Silica)

// TODO reimplement using NSRunningApplication#activationPolicy instead.
- (BOOL)isAgent {
    NSURL *bundleInfoPath = [[self.bundleURL URLByAppendingPathComponent:@"Contents"] URLByAppendingPathComponent:@"Info.plist"];
    NSDictionary *applicationBundleInfoDictionary = [NSDictionary dictionaryWithContentsOfURL:bundleInfoPath];
    return [applicationBundleInfoDictionary[@"LSUIElement"] boolValue];
}

@end
