//
//  YACYAMLKeyedUnarchiver.h
//  YACYAML
//
//  Created by James Montgomerie on 24/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, YACYAMLKeyedUnarchiverOptions) {
    YACYAMLKeyedUnarchiverOptionNone                    = 0x00,
    
    // Usually, the first (perhaps implicit) document in the YAML file is read
    // and its contents are presented as the top-level contents of the archive.
    // This matches the behaviour of YACYAMLKeyedArchiver, which places the 
    // archived contents into an implicit single document.  
    // If you're using this class to parse YAML that will have multiple documents
    // in a stream, switching this on causes each document to be a top-level
    // object, instantiated as an NSArray.
    YACYAMLKeyedUnarchiverOptionPresentDocumentsAsArray = 0x01,
    
    // You would set this to YES if the YAML file you're parsing is from an 
    // unknown source, and you don't want the unarchiver to be instantiating
    // objects of arbitrary types and calling initWithCoder: on them. (Making
    // your own initWithCoder: methods safe isn't enough: a tag can name any
    // class in the process, including system and third-party ones.)
    YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder   = 0x02,
    
    // Ignore local tags (the YAML spec's name for tags that start with a single
    // '!', like !ClassName), so that they never cause a class to be
    // instantiated: whatever has one is read as if it had no tag, so mappings
    // and sequences become NSDictionarys and NSArrays, and scalars become
    // strings.  Global tags (like tag:yaml.org,2002:int, or one in your own
    // domain) are still honoured.
    // This is stricter than YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder
    // in that it applies to classes that you have registered with a local tag
    // too, but it does not stop -initWithCoder: being called for a class that
    // you have registered with a global tag.  Use the two options together for both.
    // This is the unarchiving counterpart to
    // YACYAMLKeyedArchiverOptionDisallowLocalTags.
    YACYAMLKeyedUnarchiverOptionDisallowLocalTags       = 0x04,
};

NS_ASSUME_NONNULL_BEGIN

@interface YACYAMLKeyedUnarchiver : NSCoder

// See comments in YACYAMLKeyedUnarchiverOptions.
@property (nonatomic, readonly, getter = isInitWithCoderDisallowed) BOOL initWithCoderDisallowed;

// These return nil if the YAML could not be read.
+ (nullable id)unarchiveObjectWithString:(NSString *)string NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
+ (nullable id)unarchiveObjectWithString:(NSString *)data options:(YACYAMLKeyedUnarchiverOptions)options NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

+ (nullable id)unarchiveObjectWithData:(NSData *)data NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
+ (nullable id)unarchiveObjectWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

+ (nullable id)unarchiveObjectWithFile:(NSString *)path NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
+ (nullable id)unarchiveObjectWithFile:(NSString *)path options:(YACYAMLKeyedUnarchiverOptions)options NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");

// These are like the above, but report what went wrong.  The errors are in
// NSCocoaErrorDomain, with the codes that NSKeyedArchiver and NSKeyedUnarchiver use
// (see YACYAMLConstants.h).  They return nil, and fill in *error, if the YAML could 
// not be read, even if only part of it was bad.
// (Unlike the above, objects that can't be decoded cause an error to be returned,
// not an exception to be raised.  Exceptions raised by initWithCoder: methods
// are not caught.)
+ (nullable id)unarchiveObjectWithString:(NSString *)string error:(NSError **)error NS_SWIFT_NAME(unarchivedObject(from:));
+ (nullable id)unarchiveObjectWithData:(NSData *)data error:(NSError **)error NS_SWIFT_NAME(unarchivedObject(from:));
+ (nullable id)unarchiveObjectWithFile:(NSString *)path error:(NSError **)error NS_SWIFT_NAME(unarchivedObject(fromFile:));

+ (nullable id)unarchiveObjectWithString:(NSString *)string
                                 options:(YACYAMLKeyedUnarchiverOptions)options
                                   error:(NSError **)error NS_SWIFT_NAME(unarchivedObject(from:options:));

+ (nullable id)unarchiveObjectWithData:(NSData *)data
                               options:(YACYAMLKeyedUnarchiverOptions)options
                                 error:(NSError **)error NS_SWIFT_NAME(unarchivedObject(from:options:));

+ (nullable id)unarchiveObjectWithFile:(NSString *)path
                               options:(YACYAMLKeyedUnarchiverOptions)options
                                 error:(NSError **)error NS_SWIFT_NAME(unarchivedObject(fromFile:options:));

- (nullable instancetype)initForReadingWithData:(NSData *)data NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
- (nullable instancetype)initForReadingWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
// (This is the name NSKeyedUnarchiver gives it.)
- (nullable instancetype)initForReadingFromData:(NSData *)data error:(NSError **)error;
- (nullable instancetype)initForReadingWithData:(NSData *)data
                                        options:(YACYAMLKeyedUnarchiverOptions)options
                                          error:(NSError **)error;

- (nullable instancetype)initForReadingWithFile:(NSString *)path NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
- (nullable instancetype)initForReadingWithFile:(NSString *)path error:(NSError **)error;
- (nullable instancetype)initForReadingWithFile:(NSString *)path options:(YACYAMLKeyedUnarchiverOptions)options NS_SWIFT_UNAVAILABLE("Use the variant that takes an error, which Swift imports as throwing.");
- (nullable instancetype)initForReadingWithFile:(NSString *)path
                                        options:(YACYAMLKeyedUnarchiverOptions)options
                                          error:(NSError **)error;


// Like NSKeyedUnarchiver's, these check that the decoded object is of a class (or a subclass of
// it), returning nil, and an error, if it isn't.  Unlike NSKeyedUnarchiver's, this does not limit
// what is instantiated, and so is not a safeguard against untrusted YAML: the check is made after the
// YAML has been decoded.  (See YACYAMLKeyedUnarchiverOptionDisallowLocalTags.)
+ (nullable id)unarchivedObjectOfClass:(Class)cls
                              fromData:(NSData *)data
                                 error:(NSError **)error NS_SWIFT_NAME(unarchivedObject(ofClass:from:));

+ (nullable id)unarchivedObjectOfClass:(Class)cls
                              fromData:(NSData *)data
                               options:(YACYAMLKeyedUnarchiverOptions)options
                                 error:(NSError **)error NS_SWIFT_NAME(unarchivedObject(ofClass:from:options:));


// Use this to register classes that should be handled specially by the 
// unarchiver (see below).
+ (void)registerUnarchivingClass:(Class)unarchivingClass;

@end


// The below can be implemented in any classes you want to instantiate for 
// specific YAML tags.  Note that for application-specific classes encoded with 
// the encodeWithCoder: methods, it it _not_ necessary to implement these! 
// They're intended to give more specific control only if necessary.
// Remember to call [YACYAMLUnarchiver registerUnarchivingClass:] for any 
// classes you implement these on before trying to decode!

@protocol YACYAMLUnarchivingSequence

// This class will be instantiated for any YAML tags in this array.
// For example, to handle YAML sequences, a category is defined on 
// NSMutableArray that returns:
//     [NSArray arrayWithObject: @"tag:yaml.org,2002:seq"];
// Then, for any YAML entity that has the @"tag:yaml.org,2002:seq" tag, 
// an NSMutableArray is instantiated, and its elements are set with the 
// YACYAMLUnarchivingSetObject... instance method, below.
+ (NSArray<NSString *> *)YACYAMLUnarchivingTags;

// Should construct and return an object that YACYAMLUnarchivingAddObject: can 
// be called on to add elements.
+ (id)objectForYACYAMLUnarchiving;

// Called for each decoded child of the sequence.
- (void)YACYAMLUnarchivingAddObject:(id)object;

@end

// Similar to the above, but for classes represented by YAML mappings.
@protocol YACYAMLUnarchivingMapping

+ (NSArray<NSString *> *)YACYAMLUnarchivingTags;


// Should construct and return an object that YACYAMLUnarchivingSetObject:forKey:
// can be called on to add elements. 
+ (id)objectForYACYAMLUnarchiving;

// Called for each decoded child of the sequence. For fully spec-compliant YAML
// decoding, this should /not/ copy the keys as a normal NSDictionary's
// setObject:forKey: would.
- (void)YACYAMLUnarchivingSetObject:(id)object
                             forKey:(id)key;

@end


// Used to provide support for mapping YAML scalars to ObjC objects.
@protocol YACYAMLUnarchivingScalar

// This class will be instantiated for any YAML tags in this array.
// For example, to handle YAML sequences, a category is defined on NSData
// that returns:
//     [NSArray arrayWithObject: @"tag:yaml.org,2002:binary"];
// Then, for any YAML entity that has the @"tag:yaml.org,2002:binary" tag, 
// an NSMutableArray is instantiated, and its elements are set with the 
// init methods defined below.
+ (NSArray<NSString *> *)YACYAMLUnarchivingTags;

@optional

// Should this class be instantiated for a given scalar string with no tag?
// For example, a class representing YAML's "tag:yaml.org,2002:float" scalar
// would return YES for strings matching a
//     [-+]?([0-9][0-9_]*)?\\.[0-9.]*([eE][-+][0-9]+)?|[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+\\.[0-9_]*
// regex (as specified in the YAML spec).
// [Note that, in reality, "tag:yaml.org,2002:float" is already handled by a 
// category on NSNumber].
+ (BOOL)YACYAMLImplicitlyMatchesScalarString:(NSString *)scalarString;

// Used to construct objects matching the YAML tag or scalars with strings
// matching the NSPredicate, above.
+ (nullable id)objectWithYACYAMLScalarString:(NSString *)string;
+ (nullable id)objectWithYACYAMLScalarUTF8String:(const char *)UTF8String length:(NSUInteger)length;

@end

NS_ASSUME_NONNULL_END

