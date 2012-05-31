//
//  YACYAMLKeyedUnarchiver.h
//  YACYAML
//
//  Created by James Montgomerie on 24/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YACYAMLUnarchivingObject;

typedef enum YACYAMLKeyedUnarchiverOptions {    
    YACYAMLKeyedUnarchiverOptionNone                    = 0x00,
    YACYAMLKeyedUnarchiverOptionPresentDocumentsAsArray = 0x01,
    //YACYAMLKeyedUnarchiverOptionDontAllowInitWithCoder  = 0x01,
} YACYAMLKeyedUnarchiverOptions;


@interface YACYAMLKeyedUnarchiver : NSCoder

+ (id)unarchiveObjectWithString:(NSString *)string;
+ (id)unarchiveObjectWithString:(NSString *)data options:(YACYAMLKeyedUnarchiverOptions)options;

+ (id)unarchiveObjectWithData:(NSData *)data;
+ (id)unarchiveObjectWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options;

- (id)initForReadingWithData:(NSData *)data;
- (id)initForReadingWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options;

+ (void)registerUnarchivingClass:(Class)unarchivingClass;

@end

@protocol YACYAMLUnarchivingMapping

+ (NSArray *)YACYAMLUnarchivingTags;

- (void)YACYAMLUnarchivingSetObject:(YACYAMLUnarchivingObject *)object
                             forKey:(id)key;

@end

@protocol YACYAMLUnarchivingSequence

+ (NSArray *)YACYAMLUnarchivingTags;

- (void)YACYAMLUnarchivingAddObject:(YACYAMLUnarchivingObject *)object;

@end

@protocol YACYAMLUnarchivingScalar

+ (NSArray *)YACYAMLUnarchivingTags;

@optional

+ (NSArray *)YACYAMLUnarchivingScalarPredicates;

- (id)initWithYACYAMLScalarString:(NSString *)string;
- (id)initWithYACYAMLScalarUTF8String:(const char *)UTF8String length:(NSUInteger)length;

@end