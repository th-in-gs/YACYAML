//
//  YACYAMLExtensions.h
//  YACYAML
//
//  Created by James Montgomerie on 31/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (YACYAMLExtensions)

// Will return the results of encding this object with a YACYAMLKeyedArchiver.
// Like e.g. Ruby's "to_yaml".
- (NSString *)YACYAMLEncodedString NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
- (NSData *)YACYAMLEncodedData NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

// As above, but report errors (see YACYAMLErrorDomain in YACYAMLConstants.h)
// rather than raising exceptions for objects that can't be encoded.
- (nullable NSString *)YACYAMLEncodedStringWithError:(NSError **)error;
- (nullable NSData *)YACYAMLEncodedDataWithError:(NSError **)error;

@end

@interface NSString (YACYAMLExtensions)

// These are synonyms.  Will return the result of using a YACYAMLKeyedUnarchiver
// on the contents of the string, with the 
// YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder option turned on (so it
// will not instantiate objects using initWithCoder:)
- (nullable id)YACYAMLDecode NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
- (nullable id)YACYAMLDecodeBasic NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

// Will return the result of using a YACYAMLKeyedUnarchiver
// on the contents of the string, with the defaultOptions (so it _will_
// instantiate objects using initWithCoder:).
- (nullable id)YACYAMLDecodeAll NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

// As above, but report errors (see YACYAMLErrorDomain in YACYAMLConstants.h).
- (nullable id)YACYAMLDecodeWithError:(NSError **)error;
- (nullable id)YACYAMLDecodeBasicWithError:(NSError **)error;
- (nullable id)YACYAMLDecodeAllWithError:(NSError **)error;

@end

@interface NSData (YACYAMLExtensions)

// These are synonyms.  Will return the result of using a YACYAMLKeyedUnarchiver
// on the contents of the string, with the 
// YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder option turned on (so it
// will not instantiate objects using initWithCoder:)
- (nullable id)YACYAMLDecode NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
- (nullable id)YACYAMLDecodeBasic NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

// Will return the result of using a YACYAMLKeyedUnarchiver
// on the contents of the string, with the defaultOptions (so it _will_
// instantiate objects using initWithCoder:).
- (nullable id)YACYAMLDecodeAll NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

// As above, but report errors (see YACYAMLErrorDomain in YACYAMLConstants.h).
- (nullable id)YACYAMLDecodeWithError:(NSError **)error;
- (nullable id)YACYAMLDecodeBasicWithError:(NSError **)error;
- (nullable id)YACYAMLDecodeAllWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
