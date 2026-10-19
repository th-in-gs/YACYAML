//
//  YACYAMLConstants.h
//  YACYAML
//
//  Created by James Montgomerie on 31/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSExceptionName const YACYAMLUnsupportedTypeException NS_SWIFT_NAME(yacyamlUnsupportedType);
extern NSExceptionName const YACYAMLUnsupportedMethodException NS_SWIFT_NAME(yacyamlUnsupportedMethod);
extern NSExceptionName const YACYAMLUnsupportedObjectException NS_SWIFT_NAME(yacyamlUnsupportedObject);
extern NSExceptionName const YACYAMLAnchorReplacementException NS_SWIFT_NAME(yacyamlAnchorReplacement);

// Errors returned by the methods that take an NSError ** are in NSCocoaErrorDomain,
// with the same codes that NSKeyedArchiver and NSKeyedUnarchiver use, so that they
// can be handled in the same way:
//  - NSCoderReadCorruptError: the input was not valid YAML, or there was no document
//    in it, or something in it could not be decoded.
//  - NSCoderInvalidValueError: an object could not be encoded, or the output could
//    not be written.
//  - The NSFile... errors, with the path in NSFilePathErrorKey, if a file could not
//    be read or written.  The POSIX error is their NSUnderlyingErrorKey.
// The error underneath (NSUnderlyingErrorKey) for the first two is in this domain, with the
// YACYAMLError code that says which of YACYAML's failures it was.
extern NSString * const YACYAMLErrorDomain;

// For parse errors, the 1-based position in the input at which the problem was
// found.  They are in the userInfo of the error, and of the one underneath it.
extern NSString * const YACYAMLErrorLineKey;
extern NSString * const YACYAMLErrorColumnKey;

typedef NS_ERROR_ENUM(YACYAMLErrorDomain, YACYAMLError) {
    // The input was not valid YAML, or there was no document in it.
    YACYAMLErrorParse       = 1,
    
    // The output could not be written.
    YACYAMLErrorEmit        = 2,
    
    // An object could not be encoded or decoded. This is what the
    // YACYAMLUnsupported...Exceptions, and the YACYAMLAnchorReplacementException,
    // become when the method used returns an NSError.
    YACYAMLErrorUnsupported = 3,
};
