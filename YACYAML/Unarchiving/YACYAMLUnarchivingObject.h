//
//  YACYAMLUnarchivingObject.h
//  YACYAML
//
//  Created by James Montgomerie on 24/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YACYAMLKeyedUnarchiver;

struct yaml_parser_s;
struct yaml_event_s;

@interface YACYAMLUnarchivingObject : NSObject

- (id)initWithParser:(struct yaml_parser_s *)parser
       forUnarchiver:(YACYAMLKeyedUnarchiver *)unarchiver;

@property (nonatomic, strong, readonly) id representedObject;
@property (nonatomic) BOOL anchorWasResolved;

// Where in the YAML this object starts, counting from 1.
@property (nonatomic, readonly) NSUInteger startLine;
@property (nonatomic, readonly) NSUInteger startColumn;

- (id)nextUnkeyedObject;
- (id)keyedObjectForKey:(id)key;

@end
