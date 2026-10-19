//
//  YACYAMLSwiftTests-Bridging-Header.h
//  YACYAMLTests
//
//  What the Swift tests (YACYAMLSwift*.swift) can see of the Objective-C library and C libYAML.
//

#import <Foundation/Foundation.h>

#import <libYAML/yaml.h>

#import <YACYAML/YACYAML.h>
#import <YACYAML/YACYAMLConstants.h>

#import "YACYAMLSwiftTestSupport.h"

// Not in the library's public headers; the Objective-C tests declare them too.
@interface YACYAMLKeyedArchiver (SwiftTesting)
- (NSString *)generateAnchor;
@end

@interface YACYAMLKeyedUnarchiver (SwiftTesting)
- (NSUInteger)unarchivingObjectStackDepth;
@end
