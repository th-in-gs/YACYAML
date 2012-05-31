//
//  YACYAMLKeyedUnarchiver_Package.h
//  YACYAML
//
//  Created by James Montgomerie on 24/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

struct yaml_parser_s; 
@class YACYAMLUnarchivingObject;

@interface YACYAMLKeyedUnarchiver ()

@property (nonatomic, assign, readonly) struct yaml_parser_s *parser;

- (void)setUnrchivingObject:(YACYAMLUnarchivingObject *)unarchivingObject
                  forAnchor:(NSString *)anchor;
- (YACYAMLUnarchivingObject *)previouslyInstantiatedUnarchivingObjectForAnchor:(NSString *)anchor;

- (void)pushUnarchivingObject:(YACYAMLUnarchivingObject *)archivingObject;
- (void)popUnarchivingObject;

+ (Class)classForYAMLTag:(NSString *)tag;
+ (Class)classForYAMLScalarString:(NSString *)scalarString;

@end
