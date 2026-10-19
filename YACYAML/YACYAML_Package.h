//
//  YACYAML_Package.h
//  YACYAML
//
//  Created by James Montgomerie on 25/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libYAML/yaml.h>

extern const char * const YACYAMLOriginalMapAnnotationKey;

extern NSString * const YACYAMLUnkeyedChildrenKey;

extern const yaml_char_t *YACYAMLUnkeyedChildrenKeyChars;
extern const int YACYAMLUnkeyedChildrenKeyCharsLength;

// Errors for the methods that take an NSError **.  These return nil if the
// exception is not one of ours (or one raised by -failWithError:), so that it can be rethrown.
extern NSError *YACYAMLErrorForException(NSException *exception, BOOL writing);
extern NSError *YACYAMLErrorForParser(yaml_parser_t *parser);
extern NSError *YACYAMLErrorForMissingDocument(void);
extern NSError *YACYAMLErrorForUnexpectedClass(Class expectedClass, id object);
extern NSError *YACYAMLErrorForEmitter(yaml_emitter_t *emitter);
extern NSError *YACYAMLErrorForFile(NSString *path, int errorNumber, BOOL writing);

// For failures while decoding: where in the YAML the node that was being decoded starts (a line
// of 0 means that it isn't known).  The position goes in the reason of the exception, and in its
// userInfo, under YACYAMLErrorLineKey and YACYAMLErrorColumnKey.  It's added where it's raised,
// not later, so that the exception keeps its call stack.
extern void YACYAMLRaiseDecodingException(NSString *name, NSString *reason, NSUInteger line, NSUInteger column) __attribute__((noreturn));

// Raises a YACYAMLUnsupportedMethodException, for a method of NSCoder that is not supported.
extern void YACYAMLRaiseUnsupportedMethod(id object, SEL selector, NSString *advice) __attribute__((noreturn));
