//
//  YACYAMLSwiftTestSupport.h
//  YACYAMLTests
//
//  The things the Swift tests need that Swift can't do: catch Objective-C exceptions, and
//  write classes that return a different object from -initWithCoder: (Swift initializers can
//  only return self or nil).
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

@class YACYAMLKeyedUnarchiver;

NS_ASSUME_NONNULL_BEGIN

/// Runs the block, returning the Objective-C exception that it raised, if any.
NSException * _Nullable YACYAMLSwiftCatchException(NS_NOESCAPE void (^block)(void));

/// The unarchiver that a YACYAMLSwiftCapturingReplacingObject was last decoded with.
extern YACYAMLKeyedUnarchiver * _Nullable YACYAMLSwiftCapturedUnarchiver;

/// Returns a different object from -initWithCoder: (as some Cocoa classes do).
@interface YACYAMLSwiftSelfReplacingObject : NSObject <NSCoding>
@end

/// Like YACYAMLSwiftSelfReplacingObject, but records the unarchiver it was given.
@interface YACYAMLSwiftCapturingReplacingObject : NSObject <NSCoding>
@end

/// A CALayer that replaces itself in -initWithCoder:, and can refer to another layer, so
/// that layers can form cycles.
@interface YACYAMLSwiftReplacingLayer : CALayer
@property (nonatomic, strong, nullable) id partner;
@end

NS_ASSUME_NONNULL_END
