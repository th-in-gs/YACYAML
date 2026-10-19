//
//  YACYAMLKeyedUnarchiver_Package.h
//  YACYAML
//
//  Created by James Montgomerie on 24/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

struct yaml_parser_s; 
@class YACYAMLUnarchivingObject;

@interface YACYAMLKeyedUnarchiver ()

- (void)setUnarchivingObject:(YACYAMLUnarchivingObject *)unarchivingObject
                   forAnchor:(NSString *)anchor;
- (YACYAMLUnarchivingObject *)previouslyInstantiatedUnarchivingObjectForAnchor:(NSString *)anchor;

- (void)pushUnarchivingObject:(YACYAMLUnarchivingObject *)archivingObject;
- (void)popUnarchivingObject;
- (NSUInteger)unarchivingObjectStackDepth;

// Where in the YAML the object that is being decoded starts.  (The line is 0 if there isn't one.)
- (void)getLine:(NSUInteger *)line column:(NSUInteger *)column;

@property (nonatomic, readonly) BOOL localTagsDisallowed;

- (id)_decodeRootObjectWithError:(NSError **)error;

+ (Class)classForYAMLTag:(NSString *)tag;
+ (Class)classForYAMLScalarString:(NSString *)scalarString;

@end

