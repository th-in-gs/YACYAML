//
//  YACYAMLArchivingExtensions.m
//  YACYAML
//
//  Created by James Montgomerie on 18/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import "YACYAMLArchivingExtensions.h"

// See http://stackoverflow.com/questions/10663319/category-on-nsobject-implementing-protocol-causes-unimplemented-method-warnings
// for why this is named "YACYAMLArchivingExtensions__Workaround".
@implementation NSObject (YACYAMLArchivingExtensions__Workaround)

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder
{
    [(id<NSCoding>)self encodeWithCoder:coder];
}

@end

@implementation NSArray (YACYAMLArchivingExtensions) 

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder
{
    for(id obj in self) {
        [coder encodeObject:obj];
    }
}

@end

@implementation NSDictionary (YACYAMLArchivingExtensions) 

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder
{
    for(id key in [self keyEnumerator]) {
        [coder encodeObject:[self objectForKey:key]
                     forKey:key];
    }
}

@end

@implementation NSString (YACYAMLArchivingExtensions)

- (NSString *)YACYAMLScalarString
{
    return self;
}

@end

@implementation NSNumber (YACYAMLArchivingExtensions)

- (NSString *)YACYAMLScalarString
{
    return [self stringValue];
}

@end
