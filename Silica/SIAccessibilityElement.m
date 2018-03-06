//
//  SIAccessibilityElement.m
//  Silica
//

#import "SIAccessibilityElement.h"

#import "SISystemWideElement.h"
#import "SIApplication.h"

@interface SIAccessibilityElement ()
@property (nonatomic, assign) AXUIElementRef axElementRef;
@end

@implementation SIAccessibilityElement

#pragma mark Lifecycle

- (id)init { return nil; }

- (id)initWithAXElement:(AXUIElementRef)axElementRef {
    self = [super init];
    if (self) {
        self.axElementRef = CFRetain(axElementRef);
    }
    return self;
}

- (void)dealloc {
    CFRelease(_axElementRef);
}

#pragma mark NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ <Title: %@> <pid: %d>, %@, %@, %@", super.description, self.title, self.processIdentifier, [self class], self.role, self.subrole];
}

- (BOOL)isEqual:(id)object {
    if (!object)
        return NO;

    if (![object isKindOfClass:[self class]])
        return NO;

    SIAccessibilityElement *otherElement = object;
    if (CFEqual(self.axElementRef, otherElement.axElementRef))
        return YES;

    return NO;
}

- (NSUInteger)hash {
    return CFHash(self.axElementRef);
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithAXElement:self.axElementRef];
}

#pragma mark Public Accessors

- (BOOL)isResizable {
    Boolean sizeWriteable = false;
    AXError error = AXUIElementIsAttributeSettable(self.axElementRef, kAXSizeAttribute, &sizeWriteable);
    if (error != kAXErrorSuccess) return NO;
    
    return sizeWriteable;
}

- (BOOL)isMovable {
    Boolean positionWriteable = false;
    AXError error = AXUIElementIsAttributeSettable(self.axElementRef, kAXPositionAttribute, &positionWriteable);
    if (error != kAXErrorSuccess) return NO;
    
    return positionWriteable;
}

- (NSString *)stringForKey:(CFStringRef)accessibilityValueKey {
    CFTypeRef valueRef = NULL;
    AXError error;

    error = AXUIElementCopyAttributeValue(self.axElementRef, accessibilityValueKey, &valueRef);

    if (error != kAXErrorSuccess) {
      // this can happen with a title query onto xcode. errors are not considered abnormal.
    }
    else if (CFGetTypeID(valueRef) != CFStringGetTypeID()) {
    }

    NSString * result = nil;
    if (valueRef) {
      result = (__bridge NSString*)valueRef;
    }
  
    if (valueRef) CFRelease(valueRef);
  
    return result;
}

- (NSNumber *)numberForKey:(CFStringRef)accessibilityValueKey {
    CFTypeRef valueRef = NULL;
    AXError error;

    error = AXUIElementCopyAttributeValue(self.axElementRef, accessibilityValueKey, &valueRef);

  if (error != kAXErrorSuccess || !valueRef) {
  }
  else if (CFGetTypeID(valueRef) != CFNumberGetTypeID() && CFGetTypeID(valueRef) != CFBooleanGetTypeID()) {
  }

  NSNumber* result = nil;
  if (valueRef) {
    result = (__bridge NSNumber*) valueRef;
  }
  
  if (valueRef) CFRelease(valueRef);

  return result;
}

-(BOOL)boolForKey:(CFStringRef)accessibilityValueKey {
  return [[self numberForKey:accessibilityValueKey] boolValue];
}

- (NSArray *)arrayForKey:(CFStringRef)accessibilityValueKey {
    CFArrayRef arrayRef;
    AXError error;

    error = AXUIElementCopyAttributeValues(self.axElementRef, accessibilityValueKey, 0, 100, &arrayRef);

    if (error != kAXErrorSuccess) {
      NSLog(@"%@: ax error %@ retrieving value for %@", self, @(error), accessibilityValueKey);
    }

    NSArray* result = nil;
    if (arrayRef) {
      result = (__bridge NSArray*) arrayRef;
    }

    if (arrayRef) CFRelease(arrayRef);
    
    return result;
}

- (SIAccessibilityElement *)elementForKey:(CFStringRef)accessibilityValueKey {
    CFTypeRef valueRef;
    AXError error;

    error = AXUIElementCopyAttributeValue(self.axElementRef, accessibilityValueKey, &valueRef);

  if (error != kAXErrorSuccess || !valueRef) {
  }
  else if (CFGetTypeID(valueRef) != AXUIElementGetTypeID()) {
  }
  
  SIAccessibilityElement *element = nil;
  if (valueRef){
    element = [[SIAccessibilityElement alloc] initWithAXElement:(AXUIElementRef)valueRef];
  }
  
  if (valueRef) CFRelease(valueRef);
  
  return element;
}

- (CGRect)frame {
  CGRect result = CGRectNull;
  
    CFTypeRef pointRef;
    CFTypeRef sizeRef;
    AXError error;
    
    error = AXUIElementCopyAttributeValue(self.axElementRef, kAXPositionAttribute, &pointRef);
    if (error != kAXErrorSuccess || !pointRef) return CGRectNull;
    
    error = AXUIElementCopyAttributeValue(self.axElementRef, kAXSizeAttribute, &sizeRef);
    if (error != kAXErrorSuccess || !sizeRef) return CGRectNull;
    
    CGPoint point;
    CGSize size;
    bool success;
    
    success = AXValueGetValue(pointRef, kAXValueCGPointType, &point);
    if (success) {
      success = AXValueGetValue(sizeRef, kAXValueCGSizeType, &size);
      if (success) {
        result = CGRectMake(point.x, point.y, size.width, size.height);
      }
    }

    if (pointRef) CFRelease(pointRef);
    if (sizeRef) CFRelease(sizeRef);
  
    return result;
}

- (void)setFrame:(CGRect)frame {
    // We only want to set the size if the size has actually changed.
    BOOL shouldSetSize = YES;
    CGRect currentFrame = self.frame;
    if (self.isResizable) {
        if (fabs(currentFrame.size.width - frame.size.width) < 25) {
            if (fabs(currentFrame.size.height - frame.size.height) < 25) {
                shouldSetSize = NO;
            }
        }
    } else {
        shouldSetSize = NO;
    }

    // We set the size before and after setting the position because the
    // accessibility APIs are really finicky with setting size.
    // Note: this still occasionally silently fails to set the correct size.
    if (shouldSetSize) {
        self.size = frame.size;
    }

    self.position = frame.origin;

    if (shouldSetSize) {
        self.size = frame.size;
    }
}

- (void)setPosition:(CGPoint)position {
    AXValueRef positionRef = AXValueCreate(kAXValueCGPointType, &position);
    AXError error;
    
    if (!CGPointEqualToPoint(position, [self frame].origin)) {
        error = AXUIElementSetAttributeValue(self.axElementRef, kAXPositionAttribute, positionRef);
        if (error != kAXErrorSuccess) {
            // debug here.
        }
    }
  
    if (positionRef) CFRelease(positionRef);
}

- (void)setSize:(CGSize)size {
    AXValueRef sizeRef = AXValueCreate(kAXValueCGSizeType, &size);
    AXError error;
    
    if (!CGSizeEqualToSize(size, [self frame].size)) {
        error = AXUIElementSetAttributeValue(self.axElementRef, kAXSizeAttribute, sizeRef);
        if (error != kAXErrorSuccess) {
          // debug here.
        }
    }

    if (sizeRef) CFRelease(sizeRef);
}

- (pid_t)processIdentifier {
    pid_t processIdentifier;
    AXError error;
    
    error = AXUIElementGetPid(self.axElementRef, &processIdentifier);
    
    if (error != kAXErrorSuccess) return -1;
    
    return processIdentifier;
}


-(SIAccessibilityElement*) focusedElement {
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(self.axElementRef, kAXFocusedUIElementAttribute, (CFTypeRef *)&result);
  if (result) {
    id elem = [[SIAccessibilityElement alloc] initWithAXElement:result];
    CFRelease(result);
    return elem;
  } else {
    NSLog(@"no focused element for %@", self);
    return nil;
  }
}


- (NSString *)title {
  return [self stringForKey:kAXTitleAttribute];
}


- (NSString *)role {
  return [self stringForKey:kAXRoleAttribute];
}

- (NSString *)subrole {
  return [self stringForKey:kAXSubroleAttribute];
}

- (NSArray *)children
{
  return [self arrayForKey:kAXChildrenAttribute];
}

@end
