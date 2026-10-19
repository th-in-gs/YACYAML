//
//  YACYAMLKeyedArchiver.m
//  YACYAML
//
//  Created by James Montgomerie on 17/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import "YACYAMLKeyedArchiver.h"
#import "YACYAMLKeyedArchiver_Package.h"

#import "YACYAMLConstants.h"
#import "YACYAML_Package.h"

#import "YACYAMLArchivingObject.h"

#import <libYAML/yaml.h>

// Equality for the table of archived objects.  NSNumbers of different kinds are equal to
// each other as far as isEqual: is concerned ([@1 isEqual:@1.0] and [@1 isEqual:@YES] are
// both YES), but they're written differently, and are read back as different things.  An
// anchor for one must not be used as the other, so they're also required to be written
// as the same kind of thing (an integer, a float or a boolean).
static Boolean YACYAMLArchivedObjectsEqual(const void *value1, const void *value2)
{
    id object1 = (__bridge id)value1;
    id object2 = (__bridge id)value2;
    
    if(![object1 isEqual:object2]) {
        return false;
    }
    if([object1 isKindOfClass:[NSNumber class]]) {
        return [[object1 YACYAMLArchivingTag] isEqual:[object2 YACYAMLArchivingTag]];
    }
    return true;
}

@implementation YACYAMLKeyedArchiver {
    NSMutableData *_dataForWriting;
    FILE *_fileForWriting;
    
    BOOL _scalarAnchorsAllowed;
    BOOL _localTagsDisallowed;
    
    YACYAMLArchivingObject *_rootObject;
    NSMutableArray *_archivingObjectStack;

    CFMutableDictionaryRef _archivedObjectToItem;
    NSMutableArray *_nonAnchoringObjects;
    
    // The placeholders for objects that are only to be encoded if they're encoded elsewhere.
    NSMutableArray *_conditionalArchivingObjects;
    
    NSUInteger _generatedAnchorCount;
}

@synthesize scalarAnchorsAllowed = _scalarAnchorsAllowed;
@synthesize localTagsDisallowed = _localTagsDisallowed;


#pragma mark - Convenince methods

+ (NSData *)archivedDataWithRootObject:(id)rootObject options:(YACYAMLKeyedArchiverOptions)options
{
    NSMutableData *ret = [[NSMutableData alloc] init];
    YACYAMLKeyedArchiver *archiver = [[[self class] alloc] initForWritingWithMutableData:ret options:options];
    [archiver encodeRootObject:rootObject];
    [archiver finishEncoding];
    return ret;
}

+ (NSData *)archivedDataWithRootObject:(id)rootObject
{
    return [self archivedDataWithRootObject:rootObject 
                                    options:YACYAMLKeyedArchiverOptionNone];
}

+ (NSData *)archivedDataWithRootObject:(id)rootObject
                               options:(YACYAMLKeyedArchiverOptions)options
                                 error:(NSError **)error
{
    NSMutableData *ret = [[NSMutableData alloc] init];
    YACYAMLKeyedArchiver *archiver = [[[self class] alloc] initForWritingWithMutableData:ret options:options];
    @try {
        [archiver encodeRootObject:rootObject];
    } @catch(NSException *exception) {
        NSError *failure = YACYAMLErrorForException(exception, YES);
        if(!failure) {
            @throw;
        }
        if(error) {
            *error = failure;
        }
        return nil;
    }
    return [archiver finishEncodingWithError:error] ? ret : nil;
}

+ (NSString *)archivedStringWithRootObject:(id)rootObject options:(YACYAMLKeyedArchiverOptions)options
{
    return [[NSString alloc] initWithData:[self archivedDataWithRootObject:rootObject 
                                                                   options:options]
                                 encoding:NSUTF8StringEncoding];
}

+ (NSData *)archivedDataWithRootObject:(id)rootObject error:(NSError **)error
{
    return [self archivedDataWithRootObject:rootObject options:YACYAMLKeyedArchiverOptionNone error:error];
}

+ (NSString *)archivedStringWithRootObject:(id)rootObject error:(NSError **)error
{
    return [self archivedStringWithRootObject:rootObject options:YACYAMLKeyedArchiverOptionNone error:error];
}

+ (BOOL)archiveRootObject:(id)rootObject toFile:(NSString *)path error:(NSError **)error
{
    return [self archiveRootObject:rootObject toFile:path options:YACYAMLKeyedArchiverOptionNone error:error];
}

+ (NSString *)archivedStringWithRootObject:(id)rootObject
                                   options:(YACYAMLKeyedArchiverOptions)options
                                     error:(NSError **)error
{
    NSData *data = [self archivedDataWithRootObject:rootObject options:options error:error];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

+ (NSString *)archivedStringWithRootObject:(id)rootObject
{
    return [self archivedStringWithRootObject:rootObject
                                      options:YACYAMLKeyedArchiverOptionNone];
}

+ (BOOL)archiveRootObject:(id)rootObject 
                   toFile:(NSString *)path
                  options:(YACYAMLKeyedArchiverOptions)options
{
    BOOL success = NO;
    YACYAMLKeyedArchiver *archiver = [[[self class] alloc] initForWritingToFile:path options:options];
    if(archiver) {
        [archiver encodeRootObject:rootObject];
        [archiver finishEncoding];
        success = YES;
    }
    return success;
}

+ (BOOL)archiveRootObject:(id)rootObject
                   toFile:(NSString *)path
                  options:(YACYAMLKeyedArchiverOptions)options
                    error:(NSError **)error
{
    YACYAMLKeyedArchiver *archiver = [[[self class] alloc] initForWritingToFile:path options:options error:error];
    if(!archiver) {
        return NO;
    }
    @try {
        [archiver encodeRootObject:rootObject];
    } @catch(NSException *exception) {
        NSError *failure = YACYAMLErrorForException(exception, YES);
        if(!failure) {
            @throw;
        }
        if(error) {
            *error = failure;
        }
        return NO;
    }
    return [archiver finishEncodingWithError:error];
}

+ (BOOL)archiveRootObject:(id)rootObject toFile:(NSString *)path
{
    return [self archiveRootObject:rootObject toFile:path options:YACYAMLKeyedArchiverOptionNone];
}


#pragma mark - Initialization/destruction

- (void)_setupForWritingWithOptions:(YACYAMLKeyedArchiverOptions)options
{
    _rootObject = [[YACYAMLArchivingObject alloc] initWithRepresentedObject:nil
                                                                forArchiver:self];
    _archivingObjectStack = [[NSMutableArray alloc] init];
    [_archivingObjectStack addObject:_rootObject];
    
    
    // Don't retain the key here - it's the representedObject that's stored
    // in the YACYAMLArchivingObject that's the value.
    // Also, set up the equality and hash operations to the correct thing
    // to implements the user's choice of using object equality 
    // vs pointer equality (via the
    // YACYAMLKeyedArchiverOptionDontUseObjectEquality option).
    _archivedObjectToItem = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                      0,
                                                      &(const CFDictionaryKeyCallBacks) {
                                                          0,
                                                          NULL,
                                                          NULL,
                                                          kCFTypeDictionaryKeyCallBacks.copyDescription,
                                                          (options & YACYAMLKeyedArchiverOptionDontUseObjectEquality) == YACYAMLKeyedArchiverOptionDontUseObjectEquality ?
                                                            NULL : YACYAMLArchivedObjectsEqual,
                                                          (options & YACYAMLKeyedArchiverOptionDontUseObjectEquality) == YACYAMLKeyedArchiverOptionDontUseObjectEquality ?
                                                            NULL : kCFTypeDictionaryKeyCallBacks.hash,
                                                      },
                                                      &kCFTypeDictionaryValueCallBacks);
    
    // Use to store objects that are not allowed to be used as anchors,
    // since they won't be retained in the _archivedObjectToItem dictionary.
    _nonAnchoringObjects = [[NSMutableArray alloc] init];
    
    _conditionalArchivingObjects = [[NSMutableArray alloc] init];
    
    _scalarAnchorsAllowed = ((options & YACYAMLKeyedArchiverOptionAllowScalarAnchors) == YACYAMLKeyedArchiverOptionAllowScalarAnchors);
    
    _localTagsDisallowed = ((options & YACYAMLKeyedArchiverOptionDisallowLocalTags) == YACYAMLKeyedArchiverOptionDisallowLocalTags);
}

- (id)initForWritingWithMutableData:(NSMutableData *)mdata options:(YACYAMLKeyedArchiverOptions)options
{
    if((self = [super init])) {
        _dataForWriting = mdata;
        [self _setupForWritingWithOptions:options];
    }
    return self;
}

- (id)initForWritingWithMutableData:(NSMutableData *)data
{
    return [self initForWritingWithMutableData:data options:YACYAMLKeyedArchiverOptionNone];
}


- (id)initForWritingToFile:(NSString *)path options:(YACYAMLKeyedArchiverOptions)options error:(NSError **)error
{
    if((self = [super init])) {
        _fileForWriting = fopen([path fileSystemRepresentation], "w");
        if(_fileForWriting) {
            [self _setupForWritingWithOptions:options];
        } else {
            if(error) {
                *error = YACYAMLErrorForFile(path, errno, YES);
            }
            self = nil;
        }
    }
    return self;
}

- (id)initForWritingToFile:(NSString *)path error:(NSError **)error
{
    return [self initForWritingToFile:path options:YACYAMLKeyedArchiverOptionNone error:error];
}

- (id)initForWritingToFile:(NSString *)path options:(YACYAMLKeyedArchiverOptions)options
{
    return [self initForWritingToFile:path options:options error:NULL];
}

- (id)initForWritingToFile:(NSString *)path
{
    return [self initForWritingToFile:path options:YACYAMLKeyedArchiverOptionNone];
}

- (void)dealloc
{
    CFBridgingRelease(_archivedObjectToItem);
}

static int EmitToNSMutableData(void *ext, unsigned char *buffer, size_t size)
{
    [(__bridge NSMutableData *)ext appendBytes:buffer length:size];
    return 1;
}

- (BOOL)_finishEncodingWithError:(NSError **)error
{
    BOOL success = YES;
    
    [self _resolveConditionalArchivingObjects];
    
    yaml_emitter_t emitter;
    yaml_emitter_initialize(&emitter);
    
    @try {
        // Wonder should expose some of these options should be exposed?
        yaml_emitter_set_encoding(&emitter, YAML_UTF8_ENCODING);
        yaml_emitter_set_unicode(&emitter, 1);
        yaml_emitter_set_width(&emitter, 72);
        
        if(_fileForWriting) {
            yaml_emitter_set_output_file(&emitter, _fileForWriting); 
        } else {
            yaml_emitter_set_output(&emitter, EmitToNSMutableData, (__bridge void *)_dataForWriting);  
        }
        
        yaml_event_t event;
        
        yaml_stream_start_event_initialize(&event, YAML_UTF8_ENCODING);
        yaml_emitter_emit(&emitter, &event);
        
        [_rootObject emitWithEmitter:&emitter];
        
        yaml_stream_end_event_initialize(&event);
        yaml_emitter_emit(&emitter, &event);
        
        // Once an emitter has failed, it fails every later call too, so
        // checking here catches anything that went wrong along the way.
        if(emitter.error != YAML_NO_ERROR) {
            if(error) {
                *error = YACYAMLErrorForEmitter(&emitter);
            }
            success = NO;
        }
    } @finally {
        yaml_emitter_delete(&emitter);
        
        if(_fileForWriting) {
            fclose(_fileForWriting);
            _fileForWriting = NULL;
        }
    }
    
    return success;
}

- (void)finishEncoding 
{
    [self _finishEncodingWithError:NULL];
}

- (BOOL)finishEncodingWithError:(NSError **)error
{
    @try {
        return [self _finishEncodingWithError:error];
    } @catch(NSException *exception) {
        NSError *failure = YACYAMLErrorForException(exception, YES);
        if(!failure) {
            @throw;
        }
        if(error) {
            *error = failure;
        }
        return NO;
    }
}


#pragma mark - Package scope, used by YACYAMLUnarchivingObject during unarchiving

- (void)pushArchivingObject:(YACYAMLArchivingObject *)archivingObject
{
    CFDictionaryAddValue(_archivedObjectToItem,
                         (__bridge void *)(archivingObject.representedObject),
                         (__bridge void *)archivingObject);
    [_archivingObjectStack addObject:archivingObject];
}

- (void)popArchivingObject
{
    [_archivingObjectStack removeLastObject];
}

- (void)noteNonAnchoringObject:(YACYAMLArchivingObject *)archivingObject
{
    [_nonAnchoringObjects addObject:archivingObject];
}

- (void)noteConditionalArchivingObject:(YACYAMLArchivingObject *)placeholder
{
    [_conditionalArchivingObjects addObject:placeholder];
}

// Now that everything has been encoded, we know which of the objects that were only to be
// encoded if they were encoded elsewhere were.
- (void)_resolveConditionalArchivingObjects
{
    for(YACYAMLArchivingObject *placeholder in _conditionalArchivingObjects) {
        YACYAMLArchivingObject *target = [self previouslySeenArchivingObjectForObject:placeholder.representedObject];
        [placeholder.conditionalParent resolveConditionalChild:placeholder withTarget:target];
    }
    [_conditionalArchivingObjects removeAllObjects];
}

- (YACYAMLArchivingObject *)previouslySeenArchivingObjectForObject:(id)object
{
    return (__bridge YACYAMLArchivingObject *)CFDictionaryGetValue(_archivedObjectToItem, (__bridge void *)object);
}

- (NSString *)_anchorStringForNumber:(NSUInteger)number
{
    // Base-52 encoding with alphabet a-z, A-Z.
    // a = 0, z = 25, A = 26, Z = 51, aa = 52, ab = 53, ...
    //
    // Conceptually, this is a bijective base-52 encoding of number + 1,
    // with the digit values mapped to 1...52. We avoid actually adding 1
    // so that NSUIntegerMax can be encoded without overflow.
    //
    // Maximum buffer length:
    // A k-character encoding can represent 52 + 52^2 + ... + 52^k
    // distinct values, numbered from 0 through
    //
    //   52 + 52^2 + ... + 52^k - 1 = (52^(k+1) - 52) / 51 - 1.
    //
    // NSUInteger has w bits and can represent 2^w distinct values,
    // from 0 through 2^w - 1. We therefore need the smallest k satisfying
    //
    //   (52^(k+1) - 52) / 51 - 1 >= 2^w - 1
    //       (52^(k+1) - 52) / 51 >= 2^w
    //
    // Equivalently:
    //   k = ceil(log_52(51 * 2^w + 52)) - 1
    //
    // 32-bit: k = ceil(log_52(51 * 2^32 + 52)) - 1 = 6
    // 64-bit: k = ceil(log_52(51 * 2^64 + 52)) - 1 = 12
    enum {
        kMaxAnchorDigits = (sizeof(NSUInteger) == 4) ? 6 : 12,
        _NSUIntegerMustBe32Or64Bit = 1 / (sizeof(NSUInteger) == 4 || sizeof(NSUInteger) == 8)
    };
    
    unichar buffer[kMaxAnchorDigits];
    NSUInteger n = number;

    NSUInteger start = kMaxAnchorDigits;
    do {
        NSUInteger remainder = n % 52;
        buffer[--start] = remainder < 26 ? 'a' + remainder : 'A' + (remainder - 26);

        if (n < 52)
            break;

        n = n / 52 - 1;
    } while (YES);

    return [NSString stringWithCharacters:buffer + start
                                   length:kMaxAnchorDigits - start];
}

- (NSString *)generateAnchor
{
    return [self _anchorStringForNumber:_generatedAnchorCount++];
}

- (NSUInteger)nextAnchorLength
{
    return [self _anchorStringForNumber:_generatedAnchorCount].length;
}


#pragma mark - NSCoder

- (BOOL)allowsKeyedCoding
{
	return YES;
}

#pragma mark - Keyed archiving

- (void)_encodeObject:(id)obj forKey:(NSString *)key
{
    // This private method allows the _key_ to be nil
    // (the public NSCoder method requires a non-NULL key).

    // It seems more correct to not encode the object at all if nil is passed as the object.
    // When unarchiving, this will result in a nil-return from the unarchiving methods.
    // There are certainly methods within UIKit that will encode 'nil' and expect
    // to see 'nil' when unarchiving - as if the key was never encoded.
    // Note that an _explicit_ NSNull will be encoded.
    
    if(obj != nil) {
        [[_archivingObjectStack lastObject] encodeChild:obj ?: [NSNull null]
                                                 forKey:key];
    }
}

- (void)encodeObject:(id)obj forKey:(NSString *)key
{
    [self _encodeObject:obj forKey:key];
}

- (void)encodeConditionalObject:(id)objv forKey:(NSString *)key
{
    // Classes use this for links to objects that they don't own, like AppKit's views do for their
    // superview and next responder.  The object is only encoded if it's encoded (with
    // encodeObject:forKey: etc) somewhere else in the archive.  (As for -_encodeObject:forKey:,
    // nothing is encoded for nil.)
    if(objv != nil) {
        [[_archivingObjectStack lastObject] encodeConditionalChild:objv forKey:key];
    }
}

- (void)encodeConditionalObject:(id)object
{
    if(object != nil) {
        [[_archivingObjectStack lastObject] encodeConditionalChild:object forKey:nil];
    }
}

- (void)encodeBool:(BOOL)boolv forKey:(NSString *)key
{
    [self encodeObject:(__bridge id)(boolv ? kCFBooleanTrue : kCFBooleanFalse) 
                forKey:key];
}

- (void)encodeInt:(int)intv forKey:(NSString *)key
{
    [self encodeObject:[NSNumber numberWithInt:intv] forKey:key];
}

- (void)encodeInt32:(int32_t)intv forKey:(NSString *)key
{
    [self encodeObject:[NSNumber numberWithInt:intv] forKey:key];
}

- (void)encodeInt64:(int64_t)intv forKey:(NSString *)key
{
    [self encodeObject:[NSNumber numberWithLongLong:intv] forKey:key];
}

- (void)encodeFloat:(float)realv forKey:(NSString *)key
{
    [self encodeObject:[NSNumber numberWithFloat:realv] forKey:key];
}

- (void)encodeDouble:(double)realv forKey:(NSString *)key
{
    [self encodeObject:[NSNumber numberWithDouble:realv] forKey:key];
}

- (void)encodeBytes:(const uint8_t *)bytesp length:(NSUInteger)lenv forKey:(NSString *)key
{
    [self encodeObject:[NSData dataWithBytes:bytesp length:lenv] forKey:key];
}

- (void)encodeInteger:(NSInteger)intv forKey:(NSString *)key
{
    [self encodeObject:[NSNumber numberWithInteger:intv] forKey:key];
}


#pragma mark - Old-school non-keyed archiving

- (void)encodeValueOfObjCType:(const char *)type at:(const void *)addr
{
    id toEncode = nil;
    
    switch(type[0])
	{
		case '@': // object
		case '#': // class
			toEncode = (__bridge id)*((void **)addr);
			break;
		case '*': // (char *) string
            {
                // Written as data, with its terminating NUL, so that any bytes can be
                // encoded, not just valid UTF-8.
                const char *string = *(const char **)addr;
                if(!string) {
                    [NSException raise:YACYAMLUnsupportedObjectException format:@"Tried to encode a NULL C string"];
                }
                toEncode = [NSData dataWithBytes:string length:strlen(string) + 1];
            }
			break;
		case ':': // SEL
			toEncode = NSStringFromSelector(*((SEL *)addr));
			break;
        case 'c': // A char
            toEncode = [NSNumber numberWithChar:*(char *)addr];
            break;
        case 's': // A short
            toEncode = [NSNumber numberWithShort:*(short *)addr];
            break;
        case 'i': // An int
        case 'l': // A long (treated as a 32-bit quantity on 64-bit).
            toEncode = [NSNumber numberWithInt:*(int *)addr];
            break;
        case 'q': // A long long
            toEncode = [NSNumber numberWithLongLong:*(long long *)addr];
            break;
        case 'C': // An unsigned char
            toEncode = [NSNumber numberWithUnsignedChar:*(unsigned char *)addr];
            break;
        case 'S': // An unsigned short
            toEncode = [NSNumber numberWithUnsignedShort:*(unsigned short *)addr];
            break;
        case 'I': // An unsigned int
        case 'L': // An unsigned long
            toEncode = [NSNumber numberWithUnsignedInt:*(unsigned int *)addr];
            break;
        case 'Q': // An unsigned long long
            toEncode = [NSNumber numberWithUnsignedLongLong:*(unsigned long long *)addr];
            break;
        case 'f': // A float
            toEncode = [NSNumber numberWithFloat:*(float *)addr];
            break;
        case 'd': // A double
            toEncode = [NSNumber numberWithDouble:*(double *)addr];
            break;
        case 'B': // A C++ bool or a C99 _Bool
            toEncode = (__bridge id)(*(_Bool *)addr ? kCFBooleanTrue : kCFBooleanFalse);
            break;
		default: 
            [NSException raise:YACYAMLUnsupportedTypeException format:@"Tried to encode value of unhandled type"];
	}
    
    [self _encodeObject:toEncode forKey:nil];
}

- (void)encodeDataObject:(NSData *)data
{
    [self _encodeObject:data forKey:nil];
}


#pragma mark - Methods of NSCoder that are not supported

// These are historical, or don't fit with YAML.  Anything that has the same effect
// as something that is supported raises, rather than being implemented a second way.

- (void)encodeBytes:(const void *)byteaddr length:(NSUInteger)length
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Use -encodeBytes:length:forKey:, or encode an NSData with -encodeObject:.");
}

- (void)encodeArrayOfObjCType:(const char *)type count:(NSUInteger)count at:(const void *)array
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Encode an NSArray with -encodeObject:, or encode the values one at a time.");
}

- (void)encodePropertyList:(id)aPropertyList
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Use -encodeObject: or -encodeObject:forKey:.  Strings, numbers, dates, data, arrays and dictionaries are written as standard YAML types.");
}

- (NSInteger)versionForClassName:(NSString *)className
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Class versions are not written, and are not used with keyed coders.");
}

@end
