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
