//
//  YACYAMLKeyedUnarchiver.m
//  YACYAML
//
//  Created by James Montgomerie on 24/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import "YACYAMLKeyedUnarchiver.h"
#import "YACYAMLKeyedUnarchiver_Package.h"

#import "YACYAMLConstants.h"
#import "YACYAML_Package.h"

#import "YACYAMLUnarchivingObject.h"
#import "YACYAMLUnarchivingExtensions.h"

#import <libYAML/yaml.h>

#import <pthread.h>

pthread_mutex_t sTagsToClassesMutex = PTHREAD_MUTEX_INITIALIZER;
NSMutableDictionary *sTagsToClasses = nil;

pthread_mutex_t sImplicitScalarClassesMutex = PTHREAD_MUTEX_INITIALIZER;
NSMutableArray *sImplicitScalarClasses = nil;

@implementation YACYAMLKeyedUnarchiver {
    NSData *_archivedData;
    FILE *_archivedFile;
    
    yaml_parser_t _parser;
    NSMutableDictionary *_anchoredObjects;
    NSMutableArray *_unarchivingObjectStack;
    
    BOOL _initWithCoderDisallowed;
    BOOL _localTagsDisallowed;
}

@synthesize initWithCoderDisallowed = _initWithCoderDisallowed;
@synthesize localTagsDisallowed = _localTagsDisallowed;


#pragma mark - Global setup

+ (void)initialize
{
    if(self == [YACYAMLKeyedUnarchiver class]) {
        YACYAMLUnarchivingExtensionsRegister();
    }
}

+ (void)registerUnarchivingClass:(Class)unarchivingClass
{
    pthread_mutex_lock(&sTagsToClassesMutex);
    {
        if(!sTagsToClasses) {
            sTagsToClasses = [[NSMutableDictionary alloc] init];
        }
        if([unarchivingClass respondsToSelector:@selector(YACYAMLUnarchivingTags)]) {
            for(NSString *tag in [unarchivingClass YACYAMLUnarchivingTags]) {
                [sTagsToClasses setObject:unarchivingClass forKey:tag];
            }
        }
    }
    pthread_mutex_unlock(&sTagsToClassesMutex);
    
    pthread_mutex_lock(&sImplicitScalarClassesMutex);
    {
        if(!sImplicitScalarClasses) {
            sImplicitScalarClasses = [[NSMutableArray alloc] init];
        }
        if([unarchivingClass respondsToSelector:@selector(YACYAMLImplicitlyMatchesScalarString:)]) {
            [sImplicitScalarClasses addObject:unarchivingClass];
        }
    }
    pthread_mutex_unlock(&sImplicitScalarClassesMutex);
}


#pragma mark - Convenience methods

+ (id)unarchiveObjectWithString:(NSString *)string options:(YACYAMLKeyedUnarchiverOptions)options
{
    return [self unarchiveObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:options];
}

+ (id)unarchiveObjectWithString:(NSString *)string
{
    return [self unarchiveObjectWithString:string options:YACYAMLKeyedUnarchiverOptionNone];
}


+ (id)unarchiveObjectWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options
{
    return [[[self alloc] initForReadingWithData:data options:options] decodeObject];
}

+ (id)unarchiveObjectWithData:(NSData *)data
{
    return [self unarchiveObjectWithData:data options:YACYAMLKeyedUnarchiverOptionNone];
}

+ (id)unarchiveObjectWithFile:(NSString *)path options:(YACYAMLKeyedUnarchiverOptions)options
{
    return [[[self alloc] initForReadingWithFile:path options:options] decodeObject];
}

+ (id)unarchiveObjectWithFile:(NSString *)path
{
    return [self unarchiveObjectWithFile:path options:YACYAMLKeyedUnarchiverOptionNone];
}

+ (id)unarchiveObjectWithString:(NSString *)string error:(NSError **)error
{
    return [self unarchiveObjectWithString:string options:YACYAMLKeyedUnarchiverOptionNone error:error];
}

+ (id)unarchiveObjectWithData:(NSData *)data error:(NSError **)error
{
    return [self unarchiveObjectWithData:data options:YACYAMLKeyedUnarchiverOptionNone error:error];
}

+ (id)unarchiveObjectWithFile:(NSString *)path error:(NSError **)error
{
    return [self unarchiveObjectWithFile:path options:YACYAMLKeyedUnarchiverOptionNone error:error];
}

+ (id)unarchivedObjectOfClass:(Class)cls fromData:(NSData *)data error:(NSError **)error
{
    return [self unarchivedObjectOfClass:cls fromData:data options:YACYAMLKeyedUnarchiverOptionNone error:error];
}

+ (id)unarchivedObjectOfClass:(Class)cls fromData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options error:(NSError **)error
{
    id object = [self unarchiveObjectWithData:data options:options error:error];
    if(object && ![object isKindOfClass:cls]) {
        if(error) {
            *error = YACYAMLErrorForUnexpectedClass(cls, object);
        }
        return nil;
    }
    return object;
}

+ (id)unarchiveObjectWithString:(NSString *)string options:(YACYAMLKeyedUnarchiverOptions)options error:(NSError **)error
{
    return [self unarchiveObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:options error:error];
}

+ (id)unarchiveObjectWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options error:(NSError **)error
{
    return [[[self alloc] initForReadingWithData:data options:options error:error] _decodeRootObjectWithError:error];
}

+ (id)unarchiveObjectWithFile:(NSString *)path options:(YACYAMLKeyedUnarchiverOptions)options error:(NSError **)error
{
    return [[[self alloc] initForReadingWithFile:path options:options error:error] _decodeRootObjectWithError:error];
}


#pragma mark - Initialization/destruction

// If convertExceptions is YES, errors that occur while reading (the whole document is read
// here, so that's where e.g. a failing initWithCoder: is called) are returned in *error: parse
// errors, and our own exceptions (which are otherwise raised).
- (BOOL)_setupForReadingWithOptions:(YACYAMLKeyedUnarchiverOptions)options
                              error:(NSError **)error
                   convertExceptions:(BOOL)convertExceptions
{
    BOOL success = YES;
    
    _initWithCoderDisallowed = (options & YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder) == YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder;
    _localTagsDisallowed = (options & YACYAMLKeyedUnarchiverOptionDisallowLocalTags) == YACYAMLKeyedUnarchiverOptionDisallowLocalTags;
    
    _anchoredObjects = [[NSMutableDictionary alloc] init];
    
    _unarchivingObjectStack = [[NSMutableArray alloc] init];
    
    // Parse to after the stream starts, unless we've been asked to 
    // unarchive multiple documents as an array.
    if((options & YACYAMLKeyedUnarchiverOptionPresentDocumentsAsArray) != YACYAMLKeyedUnarchiverOptionPresentDocumentsAsArray) {
        BOOL keepParsing = YES;
        while(keepParsing) {
            yaml_event_t event;
            if(yaml_parser_parse(&_parser, &event)) {
                if(event.type == YAML_STREAM_START_EVENT) {
                    keepParsing = NO;
                }
                yaml_event_delete(&event);
            } else {
                if(error) {
                    *error = YACYAMLErrorForParser(&_parser);
                }
                success = NO;
                keepParsing = NO;
            }
        }
    }
    
    if(success) {
        @try {
            YACYAMLUnarchivingObject *obj = [[YACYAMLUnarchivingObject alloc] initWithParser:&_parser
                                                                               forUnarchiver:self];
            if (obj) {
                // This object will represent the entire document.
                [_unarchivingObjectStack addObject:obj];
            }
            if(convertExceptions && _parser.error != YAML_NO_ERROR) {
                // The document has been read, but it ended in an error.  (The older
                // methods return whatever was read before that.)
                if(error) {
                    *error = YACYAMLErrorForParser(&_parser);
                }
                success = NO;
            }
        } @catch(NSException *exception) {
            NSError *failure = convertExceptions ? YACYAMLErrorForException(exception, NO) : nil;
            if(!failure) {
                @throw;
            }
            if(error) {
                *error = failure;
            }
            success = NO;
        }
    }
    
    return success;
}

- (id)_initForReadingWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options error:(NSError **)error convertExceptions:(BOOL)convertExceptions
{
    if((self = [super init])) {
        _archivedData = data;
        
        yaml_parser_initialize(&_parser);
        
        const unsigned char *bytes = data.bytes;
        size_t size = data.length;
        
        if(size > 0 && bytes[size - 1] == 0) {
            // Don't feed a trailing nul byte to the parser.
            size -= 1;
        }
        
        yaml_parser_set_input_string(&_parser, bytes, size);
        
        if(![self _setupForReadingWithOptions:options error:error convertExceptions:convertExceptions]) {
            self = nil;
        }
    }
    
    return self;
}

- (id)initForReadingWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options error:(NSError **)error
{
    return [self _initForReadingWithData:data options:options error:error convertExceptions:YES];
}

- (id)initForReadingFromData:(NSData *)data error:(NSError **)error
{
    return [self initForReadingWithData:data options:YACYAMLKeyedUnarchiverOptionNone error:error];
}

- (id)initForReadingWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options
{
    return [self _initForReadingWithData:data options:options error:NULL convertExceptions:NO];
}

- (id)initForReadingWithData:(NSData *)data
{
    return [self initForReadingWithData:data options:YACYAMLKeyedUnarchiverOptionNone];
}


- (id)_initForReadingWithFile:(NSString *)path options:(YACYAMLKeyedUnarchiverOptions)options error:(NSError **)error convertExceptions:(BOOL)convertExceptions
{
    if((self = [super init])) {
        _archivedFile = fopen([path fileSystemRepresentation], "r");
        
        if(_archivedFile) {
            yaml_parser_initialize(&_parser);
            yaml_parser_set_input_file(&_parser, _archivedFile);
            
            if(![self _setupForReadingWithOptions:options error:error convertExceptions:convertExceptions]) {
                self = nil;
            }
        } else {
            if(error) {
                *error = YACYAMLErrorForFile(path, errno, NO);
            }
            self = nil;
        }
    }
    
    return self;
}

- (id)initForReadingWithFile:(NSString *)path options:(YACYAMLKeyedUnarchiverOptions)options error:(NSError **)error
{
    return [self _initForReadingWithFile:path options:options error:error convertExceptions:YES];
}

- (id)initForReadingWithFile:(NSString *)path error:(NSError **)error
{
    return [self initForReadingWithFile:path options:YACYAMLKeyedUnarchiverOptionNone error:error];
}

- (id)initForReadingWithFile:(NSString *)path options:(YACYAMLKeyedUnarchiverOptions)options
{
    return [self _initForReadingWithFile:path options:options error:NULL convertExceptions:NO];
}

- (id)initForReadingWithFile:(NSString *)path
{
    return [self initForReadingWithFile:path options:YACYAMLKeyedUnarchiverOptionNone];
}

- (void)dealloc
{
    if(_archivedFile) {
        fclose(_archivedFile);
    }
    yaml_parser_delete(&_parser);
}


#pragma mark - Package scope, Used by YACYAMLUnarchivingObject during unarchiving

+ (Class)classForYAMLTag:(NSString *)tag
{
    Class ret = nil;
    
    pthread_mutex_lock(&sTagsToClassesMutex);
    {
        ret = [sTagsToClasses objectForKey:tag];
    }
    pthread_mutex_unlock(&sTagsToClassesMutex);
    
    if(!ret) {
        if(tag.length > 1 &&
           [tag characterAtIndex:0] == '!') {
            ret = NSClassFromString([tag substringFromIndex:1]);
        }
    }
    
    return ret;
}

+ (Class)classForYAMLScalarString:(NSString *)scalarString
{
    if(![scalarString length]) {
        // An optimisation from experience.  This is an extremely cheap test in
        // the normal case, and in the case of large !sets, which are encoded
        // as mappings with all-NULL objects, saves a lot of time as we don't 
        // need to check all the objects as potentially matching scalars.
        return [NSNull class];
    }
    
    Class ret = nil;
    pthread_mutex_lock(&sImplicitScalarClassesMutex);
    {
        for(id class in sImplicitScalarClasses) {
            if([(Class)class YACYAMLImplicitlyMatchesScalarString:scalarString]) {
                ret = (Class)class;
                break;
            }
        }
    }
    pthread_mutex_unlock(&sImplicitScalarClassesMutex);
    return ret;
}


- (void)setUnarchivingObject:(YACYAMLUnarchivingObject *)unarchivingObject
                   forAnchor:(NSString *)anchor
{
    [_anchoredObjects setObject:unarchivingObject forKey:anchor];
}

- (YACYAMLUnarchivingObject *)previouslyInstantiatedUnarchivingObjectForAnchor:(NSString *)anchor
{
    YACYAMLUnarchivingObject *obj = [_anchoredObjects valueForKey:anchor];
    if (obj) {
        obj.anchorWasResolved = YES;
    }
    return obj;
}


- (void)pushUnarchivingObject:(YACYAMLUnarchivingObject *)archivingObject
{
    [_unarchivingObjectStack addObject:archivingObject];
}

- (void)popUnarchivingObject
{
    [_unarchivingObjectStack removeLastObject];
}

- (NSUInteger)unarchivingObjectStackDepth
{
    return _unarchivingObjectStack.count;
}

- (void)getLine:(NSUInteger *)line column:(NSUInteger *)column
{
    YACYAMLUnarchivingObject *current = [_unarchivingObjectStack lastObject];
    *line = current.startLine;
    *column = current.startColumn;
}


#pragma mark - Keyed unarchiving

- (BOOL)allowsKeyedCoding
{
    return YES;
}

- (BOOL)containsValueForKey:(NSString *)key
{
    return [[_unarchivingObjectStack lastObject] keyedObjectForKey:key] != nil;
}

- (id)decodeObjectForKey:(NSString *)key
{
    return [[_unarchivingObjectStack lastObject] keyedObjectForKey:key];
}

- (BOOL)decodeBoolForKey:(NSString *)key
{
    return [[self decodeObjectForKey:key] boolValue] ? YES : NO;
}

- (int)decodeIntForKey:(NSString *)key
{
    return [[self decodeObjectForKey:key] intValue];
}

- (int32_t)decodeInt32ForKey:(NSString *)key
{
    return [[self decodeObjectForKey:key] intValue];
}

- (int64_t)decodeInt64ForKey:(NSString *)key
{
    return [[self decodeObjectForKey:key] longLongValue];
}

- (float)decodeFloatForKey:(NSString *)key
{
    return [[self decodeObjectForKey:key] floatValue];
}

- (double)decodeDoubleForKey:(NSString *)key
{
    return [[self decodeObjectForKey:key] doubleValue];
}

- (NSInteger)decodeIntegerForKey:(NSString *)key
{
    return [[self decodeObjectForKey:key] integerValue];
}

- (const uint8_t *)decodeBytesForKey:(NSString *)key 
                      returnedLength:(NSUInteger *)lengthp
{
    __autoreleasing NSData *data = [self decodeObjectForKey:key];
    if(lengthp) {
        *lengthp = data.length;
    }
    return data.bytes;
}

#pragma mark - Old-school non-keyed unarchiving

- (id)decodeObject
{
    return [[_unarchivingObjectStack lastObject] nextUnkeyedObject];
}

// For the methods that return errors: decodes the root object, turning anything that went 
// wrong into an error.  (If initialization failed, it will have set the error already, and 
// this will be called on nil, so will do nothing.)
- (id)_decodeRootObjectWithError:(NSError **)error
{
    id object = nil;
    NSError *failure = nil;
    @try {
        object = [self decodeObject];
    } @catch(NSException *exception) {
        failure = YACYAMLErrorForException(exception, NO);
        if(!failure) {
            @throw;
        }
    }
    
    if(!failure && _parser.error != YAML_NO_ERROR) {
        // Parse errors part-way through leave us with whatever was read before them.
        failure = YACYAMLErrorForParser(&_parser);
    }
    if(!failure && !object) {
        failure = YACYAMLErrorForMissingDocument();
    }
    
    if(failure) {
        if(error) {
            *error = failure;
        }
        return nil;
    }
    return object;
}

- (void)_raiseUnsupportedType:(NSString *)reason
{
    NSUInteger line, column;
    [self getLine:&line column:&column];
    YACYAMLRaiseDecodingException(YACYAMLUnsupportedTypeException, reason, line, column);
}

- (void)decodeValueOfObjCType:(const char *)type 
                           at:(void *)data
{
    id object = [self decodeObject];
    
    switch(type[0])
    {
        case '@': // object
        case '#': // class
            // This method is documented as returning objects with a +1
            // retain  count(!).
            *((CFTypeRef *)data) = CFBridgingRetain(object);
            break;
        case '*': // (char *) string
            {
                // The caller will treat what we return as a C string, so it must end in a NUL.
                // The archiver always writes one, but YAML from elsewhere need not have one, and
                // without it the caller would read off the end of the buffer.  We accept strings
                // as well as data, so that hand-written YAML can be read.
                __autoreleasing id stringObject = object;
                if([stringObject isKindOfClass:[NSData class]]) {
                    NSData *stringData = stringObject;
                    if(stringData.length == 0 || ((const char *)stringData.bytes)[stringData.length - 1] != '\0') {
                        NSMutableData *terminated = [NSMutableData dataWithData:stringData];
                        [terminated appendBytes:"" length:1];
                        stringObject = terminated;
                    }
                    *(const char **)data = [(NSData *)stringObject bytes];
                } else if([stringObject isKindOfClass:[NSString class]]) {
                    *(const char **)data = [(NSString *)stringObject UTF8String];
                } else if(!stringObject) {
                    *(const char **)data = NULL;
                } else {
                    [self _raiseUnsupportedType:[NSString stringWithFormat:@"Tried to decode a C string from something that was not a string or data, %@", [stringObject class]]];
                }
            }
            break;
        case ':': // SEL
            *(SEL*)data = NSSelectorFromString(object);
            break;
        case 'c': // A char
            *(char *)data = [object charValue];
            break;
        case 's': // A short
            *(short *)data = [object shortValue];
            break;
        case 'i': // An int
        case 'l': // A long (treated as a 32-bit quantity on 64-bit).
            *(int *)data = [object intValue];
            break;
        case 'q': // A long long
            *(long long *)data = [object longLongValue];
            break;
        case 'C': // An unsigned char
            *(unsigned char *)data = [object unsignedCharValue];
            break;
        case 'S': // An unsigned short
            *(unsigned short *)data = [object unsignedShortValue];
            break;
        case 'I': // An unsigned int
        case 'L': // An unsigned long
            *(unsigned int *)data = [object unsignedIntValue];
            break;
        case 'Q': // An unsigned long long
            *(unsigned long long *)data = [object unsignedLongLongValue];
            break;
        case 'f': // A float
            *(float *)data = [object floatValue];
            break;
        case 'd': // A double
            *(double *)data = [object doubleValue];
            break;
        case 'B': // A C++ bool or a C99 _Bool
            *(bool *)data = [object boolValue] ? true : false;
            break;
        default: 
            [self _raiseUnsupportedType:@"Tried to decode value of unhandled type"];
    }
}

- (NSData *)decodeDataObject
{
    return [self decodeObject];
}


#pragma mark - Methods of NSCoder that are not supported

// These are historical, or don't fit with YAML.  Anything that has the same effect
// as something that is supported raises, rather than being implemented a second way.

- (void *)decodeBytesWithReturnedLength:(NSUInteger *)lengthp
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Use -decodeBytesForKey:returnedLength:, or decode an NSData with -decodeObject.");
}

- (void *)decodeBytesWithMinimumLength:(NSUInteger)length
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Use -decodeBytesForKey:minimumLength:, or decode an NSData with -decodeObject.");
}

- (void)decodeArrayOfObjCType:(const char *)itemType count:(NSUInteger)count at:(void *)array
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Decode an NSArray with -decodeObject, or decode the values one at a time.");
}

- (id)decodePropertyList
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Use -decodeObject or -decodeObjectForKey:.  To decode without creating arbitrary classes from local tags (!ClassName), create the unarchiver with YACYAMLKeyedUnarchiverOptionDisallowLocalTags.  Only standard YAML types are then instantiated.");
}

- (id)decodePropertyListForKey:(NSString *)key
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Use -decodeObject or -decodeObjectForKey:.  To decode without creating arbitrary classes from local tags (!ClassName), create the unarchiver with YACYAMLKeyedUnarchiverOptionDisallowLocalTags.  Only standard YAML types are then instantiated.");
}

- (NSInteger)versionForClassName:(NSString *)className
{
    YACYAMLRaiseUnsupportedMethod(self, _cmd, @"Class versions are not written, and are not used with keyed coders.");
}
                         
@end
