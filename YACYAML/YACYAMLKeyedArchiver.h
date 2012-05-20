//
//  YACYAML.h
//  YACYAML
//
//  Created by James Montgomerie on 17/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const YACYAMLUnsupportedTypeException;
extern NSString * const YACYAMLUnsupportedMethodException;

@interface YACYAMLKeyedArchiver : NSCoder

+ (NSData *)archivedDataWithRootObject:(id)rootObject;
- (id)initForWritingWithMutableData:(NSMutableData *)data;

@end

@protocol YACYAMLArchivingScalar <NSObject>

- (NSString*)YACYAMLScalarString; 

@end

@protocol YACYAMLArchivingCustomEncoding <NSObject>

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder;

@end