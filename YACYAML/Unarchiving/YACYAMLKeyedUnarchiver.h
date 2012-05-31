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
    
    // Usually, the first (perhaps implicit) document in the YAML file is read
    // and its contents are presented as the top-level contents of the archive.
    // This matches the behaviour of YACYAMLKeyedArchiver, which places the 
    // archived contents into an implicit single document.  
    // If you're using this class to parse YAML that will have mutiple documents
    // in a stream, switching this on causes each document to be a top-level
    // object, instantiated as an NSArray.
    YACYAMLKeyedUnarchiverOptionPresentDocumentsAsArray = 0x01,
    
    // You whould set this to YES if the YAML file you're parsing is from an 
    // unknown source, and you don't want the unarchiver to be instantiating
    // objects of arbitraty types and calling initWithCoder: on them (of course,
    // a better strategy might be to make sure all your initWithCoder: methods
    // are safe...).
    YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder   = 0x02,
} YACYAMLKeyedUnarchiverOptions;


@interface YACYAMLKeyedUnarchiver : NSCoder

@property (nonatomic, readonly, getter = isInitWithCoderDisallowed) BOOL initWithCoderDisallowed;

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