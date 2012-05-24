//
//  YACYAMLKeyedArchiver.h
//  YACYAML
//
//  Created by James Montgomerie on 17/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const YACYAMLUnsupportedTypeException;
extern NSString * const YACYAMLUnsupportedMethodException;

typedef enum YACYAMLKeyedArchiverOptions {    
    YACYAMLKeyedArchiverOptionNone                   = 0x00,
    
    // Objects that appear more than once in an archive are output only
    // once, with subsequent uses encoded as a reference to the first (this
    // is important to allow cycles to be encoded, but also saves space
    // in the general case).  By default, 'isEqual' is used to compare
    // objects.  If this option is specified, only pointer equality will
    // be considered. 
    YACYAMLKeyedArchiverOptionDontUseObjectEquality  = 0x01,
    
    // By default, to aid human readability, native scalars (strings, numbers 
    // etc.) are always be output in full in the encoded YAML, even if they 
    // compare equal to earlier scalars.
    // With this option switched on, anchors will be used to ensure
    // that unique strings are output only once, as for other classes of
    // object (although note  this option will interact with 
    // YACYAMLKeyedArchiverOptionDontUseObjectEquality).
    // It might be a good idea to switch this on if you're not intending
    // your archive to be human-readable.
    YACYAMLKeyedArchiverOptionAllowScalarAnchors     = 0x02,
} YACYAMLKeyedArchiverOptions;

@interface YACYAMLKeyedArchiver : NSCoder

+ (NSData *)archivedDataWithRootObject:(id)rootObject;
+ (NSData *)archivedDataWithRootObject:(id)rootObject options:(YACYAMLKeyedArchiverOptions)options;

- (id)initForWritingWithMutableData:(NSMutableData *)data;
- (id)initForWritingWithMutableData:(NSMutableData *)data options:(YACYAMLKeyedArchiverOptions)options;

- (void)finishEncoding;

@end

@protocol YACYAMLArchivingScalar

- (NSString*)YACYAMLScalarString; 

@end

@protocol YACYAMLArchivingCustomEncoding

@property (nonatomic, assign, readonly) BOOL YACYAMLTagCanBePlainImplicit;
@property (nonatomic, assign, readonly) BOOL YACYAMLTagCanBeQuotedImplicit;
@property (nonatomic, weak, readonly) NSString *YACYAMLTag;

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder;

@end