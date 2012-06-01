//
//  YACYAMLUnarchivingExtensions.m
//  YACYAML
//
//  Created by James Montgomerie on 29/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import "YACYAMLUnarchivingExtensions.h"

#include <xlocale.h>
#include <resolv.h>

/*
@implementation NSString (YACYAMLArchivingExtensions)
@end
*/

void YACYAMLUnarchivingExtensionsRegister(void)
{
    [YACYAMLKeyedUnarchiver registerUnarchivingClass:[NSNumber class]];
    [YACYAMLKeyedUnarchiver registerUnarchivingClass:[NSMutableArray class]];
    [YACYAMLKeyedUnarchiver registerUnarchivingClass:[NSMutableDictionary class]];
    [YACYAMLKeyedUnarchiver registerUnarchivingClass:[NSMutableSet class]];
    [YACYAMLKeyedUnarchiver registerUnarchivingClass:[NSData class]];
    [YACYAMLKeyedUnarchiver registerUnarchivingClass:[NSNull class]];
}

@implementation NSNumber (YACYAMLUnarchivingExtensions)

+ (NSArray *)YACYAMLUnarchivingTags
{
    return [[NSArray alloc] initWithObjects:
            @"tag:yaml.org,2002:float",
            @"tag:yaml.org,2002:int",
            @"tag:yaml.org,2002:bool",
            nil];
}

static NSPredicate *YACYAMLIntPredicate(void)
{
    // http://yaml.org/type/int.html
    // [-+]?0b[0-1_]+ # (base 2)
    // |[-+]?0[0-7_]+ # (base 8)
    // |[-+]?(0|[1-9][0-9_]*) # (base 10)
    // |[-+]?0x[0-9a-fA-F_]+ # (base 16)
    // |[-+]?[1-9][0-9_]*(:[0-5]?[0-9])+ # (base 60)
    
    static NSPredicate *predicate;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
                     @"[-+]?0b[0-1_]+|[-+]?0[0-7_]+|[-+]?(0|[1-9][0-9_]*)|[-+]?0x[0-9a-fA-F_]+|[-+]?[1-9][0-9_]*(:[0-5]?[0-9])+"];
    });
    
    return predicate;
}

static NSPredicate *YACYAMLFloatPredicate(void)
{
    // http://yaml.org/type/float.html
    // [-+]?([0-9][0-9_]*)?\.[0-9.]*([eE][-+][0-9]+)? (base 10)
    // |[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+\.[0-9_]* (base 60)
    
    static NSPredicate *predicate;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
                     @"[-+]?([0-9][0-9_]*)?\\.[0-9.]*([eE][-+][0-9]+)?|[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+\\.[0-9_]*"];
    });
    
    return predicate;
}

static NSPredicate *YACYAMLInfinityPredicate(void)
{
    // http://yaml.org/type/float.html
    // [-+]?\.(inf|Inf|INF) # (infinity)
    
    static NSPredicate *predicate;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
                     @"[-+]?\\.(inf|Inf|INF)"];
    });
    
    return predicate;
}

static NSPredicate *YACYAMLNotANumberPredicate(void)
{
    // http://yaml.org/type/float.html
    // \.(nan|NaN|NAN)
    
    static NSPredicate *predicate;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
                     @"\\.(nan|NaN|NAN)"];
    });
    
    return predicate;

}

static NSPredicate *YACYAMLBoolTruePredicate(void)
{
    // http://yaml.org/type/bool.html
    // y|Y|yes|Yes|YES|n|N|no|No|NO
    // |true|True|TRUE|false|False|FALSE
    // |on|On|ON|off|Off|OFF
    
    static NSPredicate *predicate;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
                      @"y|Y|yes|Yes|YES|true|True|TRUE|on|On|ON"];
    });
    
    return predicate;
}

static NSPredicate *YACYAMLBoolFalsePredicate(void)
{
    // http://yaml.org/type/bool.html
    // y|Y|yes|Yes|YES|n|N|no|No|NO
    // |true|True|TRUE|false|False|FALSE
    // |on|On|ON|off|Off|OFF
    
    static NSPredicate *predicate;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
                     @"n|N|no|No|NO|false|False|FALSE|off|Off|OFF"];
    });
    
    return predicate;
}


+ (BOOL)YACYAMLImplicitlyMatchesScalarString:(NSString *)scalarString;
{
    return [YACYAMLIntPredicate() evaluateWithObject:scalarString] || 
           [YACYAMLFloatPredicate() evaluateWithObject:scalarString] || 
           [YACYAMLInfinityPredicate() evaluateWithObject:scalarString] || 
           [YACYAMLNotANumberPredicate() evaluateWithObject:scalarString] || 
           [YACYAMLBoolTruePredicate() evaluateWithObject:scalarString] || 
           [YACYAMLBoolFalsePredicate() evaluateWithObject:scalarString];
}


- (id)initWithYACYAMLScalarString:(NSString *)string
{
    if([YACYAMLIntPredicate() evaluateWithObject:string]) {
        long long integer = 0;
        
        const char *chars = [string UTF8String];
        const char *cursor = chars;            

        if(*cursor) {
            if(strchr(chars, ':') != NULL) {
                BOOL negative = NO;
                
                if(*cursor == '-') {
                    negative = YES;
                    ++cursor;
                } else if(*cursor == '+') {
                    ++cursor;
                }
                
                long long last60part = 0;
                while(*cursor && *cursor != '.') {
                    if(*cursor != '_') {
                        if(*cursor == ':') {
                            last60part *= 60;
                            last60part += integer;
                            integer = 0;
                        } else {
                            integer *= 10;
                            integer += *cursor - '0';
                        }
                    }
                    ++cursor;
                }
                
                last60part *= 60;
                integer += last60part;
                
                if(negative) {
                    integer = -integer;
                }
            } else {
                BOOL isBinary = NO;
                
                // Strip out '_' characters, which YAML allows for spacing.
                char *canonicalString = calloc(strlen(cursor) + 1, 1);
                char *canonicalCursor = canonicalString;
                while(*cursor) {
                    if(*cursor != '_') {
                        if(*cursor == 'b') {
                            isBinary = YES;
                        } else {
                            *canonicalCursor++ = *cursor;
                        }
                    }
                    ++cursor;
                } 
                
                // Explicitly pass the base in if we know it's binary,
                // otherwise let strtoll_l parse the base.
                integer = strtoll_l(canonicalString, NULL, isBinary ? 2 : 0, _c_locale);

                free(canonicalString);
            }
        }
        
        return [self initWithLongLong:integer];
    } else if([YACYAMLFloatPredicate() evaluateWithObject:string]) {
        const char *chars = [string UTF8String];
        const char *cursor = chars;            

        // YAML allows the part before the decimal point to be
        // in 'base 60' - e.g. 190:20:30.15 == 685230.15.
        // Here, we work out the base 60 part if necessary, before
        // leaving the C library to do the conversion for the rest of
        // the number.  We'll add the two numebrs together at the end.
        double base60Part = 0;
        if(strchr(chars, ':') != NULL) {
            BOOL negative = NO;
            
            if(*cursor == '-') {
                negative = YES;
                ++cursor;
            } else if(*cursor == '+') {
                ++cursor;
            }
            
            double last60part = 0;
            while(*cursor && *cursor != '.') {
                if(*cursor != '_') {
                    if(*cursor == ':') {
                        last60part *= 60;
                        last60part += base60Part;
                        base60Part = 0;
                    } else {
                        base60Part *= 10;
                        base60Part += *cursor - '0';
                    }
                }
                ++cursor;
            }
            
            last60part *= 60;
            base60Part += last60part;
            
            if(negative) {
                base60Part = -base60Part;
            }
        }

        double d = 0;
        if(*cursor) {
            // Use strtod to do the conversion so that we don't need to worry
            // about canonical string -> double conversion ourselves.
            // First, we strip out '_' characters, which YAML allows for
            // spacing.
            char *canonicalString = calloc(strlen(cursor) + 1, 1);
            char *canonicalCursor = canonicalString;
            while(*cursor) {
                if(*cursor != '_') {
                    *canonicalCursor++ = *cursor;
                }
                ++cursor;
            }
            d = strtod_l(canonicalString, NULL, _c_locale);
            free(canonicalString);
        }
        
        if(base60Part) {
            if(base60Part < 0) {
                d = base60Part - d;
            } else {
                d += base60Part;
            }
        }
        
        return [self initWithDouble:d];
    } else if([YACYAMLInfinityPredicate() evaluateWithObject:string]) {
        if([string characterAtIndex:0] == '-') {
            return (__bridge NSNumber *)kCFNumberNegativeInfinity;
        } else {
            return (__bridge NSNumber *)kCFNumberPositiveInfinity;
        }
    } else if([YACYAMLNotANumberPredicate() evaluateWithObject:string]) {
        return (__bridge NSNumber *)kCFNumberNaN;
    } else if([YACYAMLBoolTruePredicate() evaluateWithObject:string]) {
        return (__bridge NSNumber *)kCFBooleanTrue;
    } else if([YACYAMLBoolFalsePredicate() evaluateWithObject:string]) {
        return (__bridge NSNumber *)kCFBooleanFalse;
    } else {
        NSLog(@"Warning: Could not parse string \"%@\" to NSNumber, using string as-is", string);
        return (NSNumber *)string;
    }
}

@end


@implementation NSData (YACYAMLUnarchivingExtensions)

+ (NSArray *)YACYAMLUnarchivingTags
{
    return [[NSArray alloc] initWithObjects:
            @"tag:yaml.org,2002:binary",
            nil];
}

- (id)initWithYACYAMLScalarUTF8String:(const char *)UTF8String length:(NSUInteger)length
{
    NSData *decodedData = nil;
    
    NSUInteger decodedBufferLength = length * 3 / 4;
    uint8_t* decodedBuffer = malloc(decodedBufferLength);
    
    int decodedBufferRealLength = b64_pton(UTF8String, 
                                           decodedBuffer, 
                                           decodedBufferLength);
    
    if(decodedBufferRealLength >= 0) {
        decodedData = [[NSData alloc] initWithBytesNoCopy:decodedBuffer 
                                                   length:decodedBufferRealLength 
                                             freeWhenDone:YES];
    } else {
        free(decodedBuffer);
    }    
    
    return decodedData;
}

@end

@implementation NSNull (YACYAMLUnarchivingExtensions)

+ (NSArray *)YACYAMLUnarchivingTags
{
    return [[NSArray alloc] initWithObjects:
            @"tag:yaml.org,2002:null",
            nil];
}

static NSPredicate *YACYAMLNullPredicate(void)
{
    // http://yaml.org/type/null.html
    // ~ # (canonical)
    // |null|Null|NULL # (English)
    // | # (Empty)
    
    static NSPredicate *predicate;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
                     @"~|null|Null|NULL|"];
    });
    
    return predicate;
}

+ (BOOL)YACYAMLImplicitlyMatchesScalarString:(NSString *)scalarString;
{
    return [YACYAMLNullPredicate() evaluateWithObject:scalarString];
}

- (id)initWithYACYAMLScalarString:(NSString *)string;
{
    return [NSNull null];
}

@end

@implementation NSMutableArray (YACYAMLUnarchivingExtensions)

+ (NSArray *)YACYAMLUnarchivingTags
{
    return [[NSArray alloc] initWithObjects:
            @"tag:yaml.org,2002:seq",
            nil];
}

- (void)YACYAMLUnarchivingAddObject:(id)object
{
    [self addObject:object];
}

@end

@implementation NSMutableDictionary (YACYAMLUnarchivingExtensions)

+ (NSArray *)YACYAMLUnarchivingTags
{
    return [[NSArray alloc] initWithObjects:
            @"tag:yaml.org,2002:map",
            nil];
}

- (void)YACYAMLUnarchivingSetObject:(id)object forKey:(id)key
{
    [self setObject:object forKey:key];
}

@end

@implementation NSMutableSet (YACYAMLUnarchivingExtensions)

+ (NSArray *)YACYAMLUnarchivingTags
{
    return [[NSArray alloc] initWithObjects:
            @"tag:yaml.org,2002:set",
            nil];
}

- (void)YACYAMLUnarchivingSetObject:(id)object forKey:(id)key
{
    // YAML represents sets as mappings of the contents to nil objects.
    [self addObject:key];
}

@end

