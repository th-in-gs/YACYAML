//
//  YACYAMLKeyedUnarchiver.m
//  YACYAML
//
//  Created by James Montgomerie on 24/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import "YACYAML.h"

#import "YACYAMLKeyedUnarchiver.h"
#import "YACYAMLKeyedUnarchiver_Package.h"

#import "YACYAMLUnarchivingObject.h"
#import "YACYAMLUnarchivingExtensions.h"

#import <libYAML/yaml.h>

#import <pthread.h>

pthread_mutex_t sTagsToClassesMutex = PTHREAD_MUTEX_INITIALIZER;
NSMutableDictionary *sTagsToClasses = nil;

pthread_mutex_t sPredicatesToClassesMutex = PTHREAD_MUTEX_INITIALIZER;
NSMutableArray *sPredicatesToClasses = nil;

@implementation YACYAMLKeyedUnarchiver {
    NSData *_archivedData;
    yaml_parser_t _parser;
    CFMutableDictionaryRef _anchoredObjects;
    NSMutableArray *_unarchivingObjectStack;
    
    BOOL _initWithCoderDisallowed;
}

@synthesize initWithCoderDisallowed = _initWithCoderDisallowed;

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
            sPredicatesToClasses = [[NSMutableArray alloc] init];
        }
        if([unarchivingClass respondsToSelector:@selector(YACYAMLUnarchivingTags)]) {
            for(NSString *tag in [unarchivingClass YACYAMLUnarchivingTags]) {
                [sTagsToClasses setObject:unarchivingClass forKey:tag];
            }
        }
    }
    pthread_mutex_unlock(&sTagsToClassesMutex);
    
    pthread_mutex_lock(&sPredicatesToClassesMutex);
    {
        if(!sPredicatesToClasses) {
            sPredicatesToClasses = [[NSMutableArray alloc] init];
        }
        if([unarchivingClass respondsToSelector:@selector(YACYAMLUnarchivingScalarPredicates)]) {
            for(NSPredicate *predicate in [unarchivingClass YACYAMLUnarchivingScalarPredicates]) {
                [sPredicatesToClasses addObject:predicate];
                [sPredicatesToClasses addObject:unarchivingClass];
            }
        }
    }
    pthread_mutex_unlock(&sPredicatesToClassesMutex);
}

+ (id)unarchiveObjectWithString:(NSString *)string
{
    return [self unarchiveObjectWithString:string options:YACYAMLKeyedUnarchiverOptionNone];
}

+ (id)unarchiveObjectWithString:(NSString *)string options:(YACYAMLKeyedUnarchiverOptions)options
{
    return [self unarchiveObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:options];
}

+ (id)unarchiveObjectWithData:(NSData *)data options:(YACYAMLKeyedUnarchiverOptions)options
{
    return [[[self alloc] initForReadingWithData:data options:options] decodeObject];
}

+ (id)unarchiveObjectWithData:(NSData *)data
{
    return [self unarchiveObjectWithData:data options:YACYAMLKeyedUnarchiverOptionNone];
}

- (id)initForReadingWithData:(NSData *)data
                     options:(YACYAMLKeyedUnarchiverOptions)options
{
    if((self = [super init])) {
        _initWithCoderDisallowed = (options & YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder) == YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder;
        
        _archivedData = data;
        
        _unarchivingObjectStack = [[NSMutableArray alloc] init];
        
        // Create a dictionary that won't retain its objects.
        _anchoredObjects = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                     0,
                                                     &kCFTypeDictionaryKeyCallBacks,
                                                     &(const CFDictionaryValueCallBacks) {
                                                         0,
                                                         NULL,
                                                         NULL,
                                                         kCFTypeDictionaryValueCallBacks.copyDescription,
                                                         NULL
                                                     });
        
        yaml_parser_initialize(&_parser);
        
        const unsigned char *bytes = data.bytes;
        size_t size = data.length;
        
        if(size > 0 && bytes[size - 1] == 0) {
            // Don't feed a trailing nul byte to the parser.
            size -= 1;
        }
        
        yaml_parser_set_input_string(&_parser, bytes, size);
    
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
                    self = nil;
                    keepParsing = NO;
                }
            }
        }
    
        if(self) {
            // This object will represent the entire document.
            [_unarchivingObjectStack addObject:[[YACYAMLUnarchivingObject alloc] initWithParser:&_parser
                                                                                  forUnarchiver:self]];
        }
    }
    
    return self;
}

- (id)initForReadingWithData:(NSData *)data
{
    return [self initForReadingWithData:data options:YACYAMLKeyedUnarchiverOptionNone];
}

- (void)dealloc
{
    yaml_parser_delete(&_parser);
}

- (BOOL)allowsKeyedCoding
{
    return YES;
}

- (yaml_parser_t *)parser
{
    return &_parser;
}

- (void)setUnrchivingObject:(YACYAMLUnarchivingObject *)unarchivingObject
                  forAnchor:(NSString *)anchor
{
    CFDictionarySetValue(_anchoredObjects, (__bridge void *)anchor, (__bridge void *)unarchivingObject);
}

- (YACYAMLUnarchivingObject *)previouslyInstantiatedUnarchivingObjectForAnchor:(NSString *)anchor
{
    return (__bridge YACYAMLUnarchivingObject *)CFDictionaryGetValue(_anchoredObjects, (__bridge void *)anchor);
}

- (void)pushUnarchivingObject:(YACYAMLUnarchivingObject *)archivingObject
{
    [_unarchivingObjectStack addObject:archivingObject];
}

- (void)popUnarchivingObject
{
    [_unarchivingObjectStack removeLastObject];
}

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
    Class ret = nil;
    
    pthread_mutex_lock(&sPredicatesToClassesMutex);
    {
        NSUInteger count = sPredicatesToClasses.count;
        for(int i = 0; i < count; i +=2) {
            NSPredicate *predicate = [sPredicatesToClasses objectAtIndex:i];
            if([predicate evaluateWithObject:scalarString]) {
                ret =[sPredicatesToClasses objectAtIndex:i + 1];
                break;
            }
        }
    }
    pthread_mutex_unlock(&sPredicatesToClassesMutex);
    
    return ret;
}

#pragma mark - Keyed unarchiving methods

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
    *lengthp = data.length;
    return data.bytes;
}

#pragma mark - Non-keyed unarchiving methods

- (id)decodeObject
{
    return [[_unarchivingObjectStack lastObject] nextUnkeyedObject];
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
                __autoreleasing NSData *stringData = object;
                *(const char **)data = stringData.bytes;
            }
            break;
        case ':': // SEL
            *((const char **)data) = (char *)NSSelectorFromString(object);
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
            [NSException raise:YACYAMLUnsupportedTypeException format:@"Tried to decode value of unhandled type"];
    }
}

- (NSData *)decodeDataObject
{
    return [self decodeObject];
}
                         
@end
