//
//  YACYAMLKeyedArchiver.h
//  YACYAML
//
//  Created by James Montgomerie on 17/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, YACYAMLKeyedArchiverOptions) {
    YACYAMLKeyedArchiverOptionNone                      = 0x00,
    
    /*
     I'd like to implement this, and make it the default for the simple
     -YACYCAMLEncodedString and -YACYAMLEncodedData methods, but I can't
     work out a safe way to do it given that keys can me arbitrary objects
     of arbitrary classes, and might not implement -compare:, and even
     if they do, might not be comparabe to other keys.
     
    // Order output mapping elements by key, for human-readabiliy.
    YACYAMLKeyedArchiverOptionOrderMappingContentsByKey = 0x01,
    */
    
    // Objects that appear more than once in an archive are output only
    // once, with subsequent uses encoded as a reference to the first (this
    // is important to allow cycles to be encoded, but also saves space
    // in the general case).  By default, 'isEqual' is used to compare
    // objects.  If this option is specified, only pointer equality will
    // be considered. 
    YACYAMLKeyedArchiverOptionDontUseObjectEquality     = 0x02,
    
    // By default, to aid human readability, native scalars (strings, numbers 
    // etc.) are always be output in full in the encoded YAML, even if they 
    // compare equal to earlier scalars.
    // With this option switched on, anchors will be used to ensure
    // that unique strings are output only once, as for other classes of
    // object (although note  this option will interact with 
    // YACYAMLKeyedArchiverOptionDontUseObjectEquality), where that makes
    // the output smaller.  A scalar that is short, or not used often enough,
    // for an anchor to save space is still written out in full each time.
    // It might be a good idea to switch this on if you're not intending
    // your archive to be human-readable.
    YACYAMLKeyedArchiverOptionAllowScalarAnchors        = 0x04,
    
    // You would set this if you want to be sure that no local tags (the
    // YAML spec's name for tags that start with a single '!', like !ClassName)
    // are written, so that application classes, which are written with their
    // class name as a local tag, can't get into the output by accident.
    // YAML's own types, and classes that return a global tag (like
    // tag:yaml.org,2002:str, or one in your own domain) from their
    // YACYAMLArchivingTag, are still written.  Archiving an object that has a
    // local tag raises a YACYAMLUnsupportedObjectException, before anything is
    // output.
    // This is the archiving counterpart to
    // YACYAMLKeyedUnarchiverOptionDisallowLocalTags.
    YACYAMLKeyedArchiverOptionDisallowLocalTags         = 0x08,
};

NS_ASSUME_NONNULL_BEGIN

@interface YACYAMLKeyedArchiver : NSCoder

+ (NSData *)archivedDataWithRootObject:(id)rootObject NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
+ (NSData *)archivedDataWithRootObject:(id)rootObject options:(YACYAMLKeyedArchiverOptions)options NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

+ (NSString *)archivedStringWithRootObject:(id)rootObject NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
+ (NSString *)archivedStringWithRootObject:(id)rootObject options:(YACYAMLKeyedArchiverOptions)options NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

+ (BOOL)archiveRootObject:(id)rootObject toFile:(NSString *)path NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
+ (BOOL)archiveRootObject:(id)rootObject toFile:(NSString *)path options:(YACYAMLKeyedArchiverOptions)options NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

// These are like the above, but report what went wrong.  The errors are in
// NSCocoaErrorDomain, with the codes that NSKeyedArchiver and NSKeyedUnarchiver use
// (see YACYAMLConstants.h).  They return nil or NO, and fill in *error, if archiving
// failed.
// (Unlike the above, objects that can't be encoded cause an error to be returned,
// not an exception to be raised.)
+ (nullable NSData *)archivedDataWithRootObject:(id)rootObject error:(NSError **)error;
+ (nullable NSString *)archivedStringWithRootObject:(id)rootObject error:(NSError **)error;
+ (BOOL)archiveRootObject:(id)rootObject toFile:(NSString *)path error:(NSError **)error;

+ (nullable NSData *)archivedDataWithRootObject:(id)rootObject
                                        options:(YACYAMLKeyedArchiverOptions)options
                                          error:(NSError **)error;

+ (nullable NSString *)archivedStringWithRootObject:(id)rootObject
                                            options:(YACYAMLKeyedArchiverOptions)options
                                              error:(NSError **)error;

+ (BOOL)archiveRootObject:(id)rootObject
                   toFile:(NSString *)path
                  options:(YACYAMLKeyedArchiverOptions)options
                    error:(NSError **)error;

- (instancetype)initForWritingWithMutableData:(nullable NSMutableData *)data;
- (instancetype)initForWritingWithMutableData:(nullable NSMutableData *)data options:(YACYAMLKeyedArchiverOptions)options;

- (nullable instancetype)initForWritingToFile:(NSString *)path NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
- (nullable instancetype)initForWritingToFile:(NSString *)path error:(NSError **)error;
- (nullable instancetype)initForWritingToFile:(NSString *)path options:(YACYAMLKeyedArchiverOptions)options NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
- (nullable instancetype)initForWritingToFile:(NSString *)path
                                      options:(YACYAMLKeyedArchiverOptions)options
                                        error:(NSError **)error;

- (void)finishEncoding NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

// Like -finishEncoding, but returns NO and fills in *error if the output could
// not be written.
- (BOOL)finishEncodingWithError:(NSError **)error;

@end


// The below can be implemented in any classes you want to instantiate for 
// specific YAML tags.  Note that for application-specific classes that are 
// intended to be encoded with the regular encodeWithCoder: methods, it it 
// _not_ necessary to implement these! 

@protocol YACYAMLArchivingCustomEncoding

// The YAML tag for this object.
// For example, NSArray will return "tag:yaml.org,2002:seq", NSNumber will
// return "tag:yaml.org,2002:int", "tag:yaml.org,2002:float" etc. as 
// appropriate.
// nil for objects that are encoded as plain, untagged, YAML scalars (e.g. NSString).
@property (nonatomic, weak, readonly, nullable) NSString *YACYAMLArchivingTag;

// YES if the tag be skipped in non-quoted style output for this object.
@property (nonatomic, assign, readonly) BOOL YACYAMLArchivingTagCanBePlainImplicit;

// YES if the tag be skipped in quoted style output for this object.
@property (nonatomic, assign, readonly) BOOL YACYAMLArchivingTagCanBeQuotedImplicit;


@optional

// Implement this to encode a non-scalar object in a way that's custom to YAML.
// Will be called in place of encodeWithCoder:, if it's implemented.
// For example, an NSArray category overrides this to simple call:
// 
//  for(id obj in self) {
//      [coder encodeObject:obj];
//  }
- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder;

// Implement this to encode a scalar object in a way that's custom to YAML.
// Will be called in place of encodeWithCoder:, if it's implemented.
// For example, an NSNumber category overrides this to convert numbers to 
// YAML-spec-compliant string representations.
- (nullable NSString *)YACYAMLScalarString; 

@end

NS_ASSUME_NONNULL_END
