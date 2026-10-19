//
//  YACYAML_Package.m
//  YACYAML
//
//  Created by James Montgomerie on 25/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import "YACYAML_Package.h"

#define YACYAMLUnkeyedChildrenCString "___unkeyedChildren"

const char * const YACYAMLOriginalMapAnnotationKey = "___YACYAML_originalMap";

NSString * const YACYAMLUnkeyedChildrenKey = @YACYAMLUnkeyedChildrenCString;

const yaml_char_t *YACYAMLUnkeyedChildrenKeyChars = (yaml_char_t *)YACYAMLUnkeyedChildrenCString;
const int YACYAMLUnkeyedChildrenKeyCharsLength = sizeof(YACYAMLUnkeyedChildrenKeyChars) - 1;


#import "YACYAMLConstants.h"

// The errors that we return are in NSCocoaErrorDomain, with the codes that NSKeyedArchiver and
// NSKeyedUnarchiver use, so that callers can handle them in the same way.  Underneath, as
// NSUnderlyingErrorKey, is the YACYAMLErrorDomain error, which also has anything that Cocoa has
// no place for (the line and column of a parse error).
// The description is also in NSDebugDescriptionErrorKey, where NSKeyedUnarchiver and
// NSKeyedArchiver put the detail of their errors.
static NSError *WrappedError(NSInteger cocoaCode, YACYAMLError code, NSString *description, NSDictionary *extraInfo)
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:extraInfo];
    userInfo[NSLocalizedDescriptionKey] = description;
    userInfo[NSDebugDescriptionErrorKey] = description;
    
    NSError *underlying = [NSError errorWithDomain:YACYAMLErrorDomain
                                              code:code
                                          userInfo:[userInfo copy]];
    userInfo[NSUnderlyingErrorKey] = underlying;
    
    return [NSError errorWithDomain:NSCocoaErrorDomain
                               code:cocoaCode
                           userInfo:userInfo];
}

NSError *YACYAMLErrorForException(NSException *exception, BOOL writing)
{
    if([exception.name isEqualToString:NSInvalidUnarchiveOperationException]) {
        // Raised by -failWithError: (which classes' initWithCoder: methods may call), under the
        // default failure policy.  The error is in the userInfo, if it's there.
        id error = exception.userInfo[@"__NSCoderError"];
        if([error isKindOfClass:[NSError class]]) {
            return error;
        }
        NSString *description = exception.reason ?: exception.name;
        return [NSError errorWithDomain:NSCocoaErrorDomain
                                   code:NSCoderReadCorruptError
                               userInfo:@{ NSLocalizedDescriptionKey: description,
                                           NSDebugDescriptionErrorKey: description }];
    }
    
    NSArray *names = @[ YACYAMLUnsupportedTypeException,
                        YACYAMLUnsupportedMethodException,
                        YACYAMLUnsupportedObjectException,
                        YACYAMLAnchorReplacementException ];
    if(![names containsObject:exception.name]) {
        return nil;
    }
    // If it was raised while decoding, it has the position.
    NSMutableDictionary *position = [[NSMutableDictionary alloc] init];
    for(NSString *key in @[ YACYAMLErrorLineKey, YACYAMLErrorColumnKey ]) {
        if(exception.userInfo[key]) {
            position[key] = exception.userInfo[key];
        }
    }
    return WrappedError(writing ? NSCoderInvalidValueError : NSCoderReadCorruptError,
                        YACYAMLErrorUnsupported,
                        exception.reason ?: exception.name,
                        position);
}

static NSString *DescriptionWithPosition(NSString *description, NSUInteger line, NSUInteger column)
{
    return line ? [NSString stringWithFormat:@"%@ (line %lu, column %lu)", description, (unsigned long)line, (unsigned long)column] : description;
}

void YACYAMLRaiseDecodingException(NSString *name, NSString *reason, NSUInteger line, NSUInteger column)
{
    NSDictionary *userInfo = line ? @{ YACYAMLErrorLineKey: @(line), YACYAMLErrorColumnKey: @(column) } : nil;
    [[NSException exceptionWithName:name
                             reason:DescriptionWithPosition(reason, line, column)
                           userInfo:userInfo] raise];
    abort(); // Not reached.  This tells the compiler that.
}

void YACYAMLRaiseUnsupportedMethod(id object, SEL selector, NSString *advice)
{
    [NSException raise:YACYAMLUnsupportedMethodException
                format:@"%@ does not support -%@.  %@", [object class], NSStringFromSelector(selector), advice];
    abort(); // Not reached.  This tells the compiler that.
}

NSError *YACYAMLErrorForParser(yaml_parser_t *parser)
{
    NSString *problem = parser->problem ? [NSString stringWithUTF8String:parser->problem] : nil;
    NSString *context = parser->context ? [NSString stringWithUTF8String:parser->context] : nil;
    NSString *description = problem ?: @"Invalid YAML.";
    if(context) {
        description = [NSString stringWithFormat:@"%@ (%@)", description, context];
    }
    
    // Marks are zero-based; people count from one.
    yaml_mark_t mark = parser->problem ? parser->problem_mark : parser->mark;
    return WrappedError(NSCoderReadCorruptError,
                        YACYAMLErrorParse,
                        description,
                        @{ YACYAMLErrorLineKey: @(mark.line + 1),
                           YACYAMLErrorColumnKey: @(mark.column + 1) });
}

NSError *YACYAMLErrorForMissingDocument(void)
{
    return WrappedError(NSCoderReadCorruptError, YACYAMLErrorParse, @"No YAML document found.", nil);
}

NSError *YACYAMLErrorForUnexpectedClass(Class expectedClass, id object)
{
    return WrappedError(NSCoderReadCorruptError,
                        YACYAMLErrorUnsupported,
                        [NSString stringWithFormat:@"The decoded object is of class %@, not %@.", [object class], expectedClass],
                        nil);
}

NSError *YACYAMLErrorForEmitter(yaml_emitter_t *emitter)
{
    NSString *problem = emitter->problem ? [NSString stringWithUTF8String:emitter->problem] : @"Unable to write YAML.";
    return WrappedError(NSCoderInvalidValueError, YACYAMLErrorEmit, problem, nil);
}

NSError *YACYAMLErrorForFile(NSString *path, int errorNumber, BOOL writing)
{
    // The codes that NSData uses for the same failures.
    NSInteger code;
    switch(errorNumber) {
        case ENOENT:
            code = writing ? NSFileNoSuchFileError : NSFileReadNoSuchFileError;
            break;
        case EACCES:
        case EPERM:
            code = writing ? NSFileWriteNoPermissionError : NSFileReadNoPermissionError;
            break;
        case ENOSPC:
            code = writing ? NSFileWriteOutOfSpaceError : NSFileReadUnknownError;
            break;
        case EROFS:
            code = writing ? NSFileWriteVolumeReadOnlyError : NSFileReadUnknownError;
            break;
        default:
            code = writing ? NSFileWriteUnknownError : NSFileReadUnknownError;
            break;
    }
    return [NSError errorWithDomain:NSCocoaErrorDomain
                               code:code
                           userInfo:@{ NSFilePathErrorKey: path,
                                       NSUnderlyingErrorKey: [NSError errorWithDomain:NSPOSIXErrorDomain code:errorNumber userInfo:nil] }];
}
