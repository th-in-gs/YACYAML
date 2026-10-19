//
//  YACYAMLSwiftTestSupport.m
//  YACYAMLTests
//

#import "YACYAMLSwiftTestSupport.h"

#import <YACYAML/YACYAML.h>

NSException * _Nullable YACYAMLSwiftCatchException(NS_NOESCAPE void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return exception;
    }
    return nil;
}

YACYAMLKeyedUnarchiver *YACYAMLSwiftCapturedUnarchiver = nil;

@implementation YACYAMLSwiftSelfReplacingObject

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // Return a DIFFERENT object.
    return (id)[[NSObject alloc] init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end

@implementation YACYAMLSwiftCapturingReplacingObject

- (instancetype)initWithCoder:(NSCoder *)coder
{
    YACYAMLSwiftCapturedUnarchiver = (YACYAMLKeyedUnarchiver *)coder;
    return (id)[[NSObject alloc] init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end

@implementation YACYAMLSwiftReplacingLayer

- (instancetype)initWithCoder:(NSCoder *)coder
{
    YACYAMLSwiftReplacingLayer *decoded = [super initWithCoder:coder];
    
    // Return a DIFFERENT object, carrying the decoded state over.
    YACYAMLSwiftReplacingLayer *replacement = [[YACYAMLSwiftReplacingLayer alloc] init];
    replacement.name = decoded.name;
    replacement.bounds = decoded.bounds;
    replacement.partner = [coder decodeObjectForKey:@"partner"];
    return replacement;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:self.partner forKey:@"partner"];
}

@end
