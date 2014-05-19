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