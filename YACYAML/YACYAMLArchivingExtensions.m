//
//  YACYAMLArchivingExtensions.m
//  YACYAML
//
//  Created by James Montgomerie on 18/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import "YACYAMLArchivingExtensions.h"

#import <resolv.h>

@implementation NSObject (YACYAMLArchivingExtensions)

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder
{
    [(id<NSCoding>)self encodeWithCoder:coder];
}

- (BOOL)YACYAMLTagCanBePlainImplicit
{
    return NO;
}

- (BOOL)YACYAMLTagCanBeQuotedImplicit
{
    return NO;
}

- (NSString *)YACYAMLTag
{
    return [@"!" stringByAppendingString:NSStringFromClass([self class])];
}

@end


@implementation NSString (YACYAMLArchivingExtensions)

- (BOOL)YACYAMLTagCanBePlainImplicit
{
    return YES;
}

- (BOOL)YACYAMLTagCanBeQuotedImplicit
{
    return YES;
}

- (NSString *)YACYAMLTag
{
    return @"tag:yaml.org,2002:str";
}

- (NSString *)YACYAMLScalarString
{
    return self;
}

@end



@implementation NSNumber (YACYAMLArchivingExtensions)

- (BOOL)YACYAMLTagCanBePlainImplicit
{
    return YES;
}

- (BOOL)YACYAMLArchivingExtensions_isBoolean
{
    const char *objCType = self.objCType;
    if(objCType[0] == 'B' && !objCType[1]) {
        return YES;
    } 

    if([NSStringFromClass([self class]) rangeOfString:@"Boolean"].location != NSNotFound) {
        // This is a hack.  At least on 32-bit runtimes - including iOS - 
        // booleans are not specifically encoded when stored in NSNumbers. 
        // NSNumbers created with e.g. [NSNumber numberWithBool:] report their
        // objCType as /char/.  Correct at machine level, but not correct as
        // far as human-readable-output is concerned.  The class they're stored
        // as, however, reports ots name as '__NSCFBoolean', so we look at the 
        // class name.  This is a bit fragile, but the worst that will happen
        // is that if Apple renames the __NSCFBoolean class, this will start
        // reporting NO, and we'll encode as char, which is where we'd be anyway
        // without this check.
        
        return YES;
    }

    return NO;
}

- (NSString *)YACYAMLTag
{
    NSString *tag = nil;

    if([self YACYAMLArchivingExtensions_isBoolean]) {
        tag = @"tag:yaml.org,2002:bool";
    } else {
        const char *objCType = self.objCType;
        
        if(objCType[0] && !objCType[1]) {
            switch(objCType[0]) {
                {
                default: 
                    NSLog(@"Warning: Unknown ObjC type encountered in number, %s, encoding as double", objCType);
                    // Fall through.
                    
                case 'f': // A float
                case 'd': // A double
                    tag = @"tag:yaml.org,2002:float";
                    break;

                case 'c': // A char
                case 's': // A short
                case 'i': // An int
                case 'l': // A long (treated as a 32-bit quantity on 64-bit).
                case 'q': // A long long
                case 'C': // An unsigned char
                case 'S': // An unsigned short
                case 'I': // An unsigned int
                case 'L': // An unsigned long
                case 'Q': // An unsigned long long
                    tag = @"tag:yaml.org,2002:int";
                    break;

                case 'B': // A C++ bool or a C99 _Bool
                    tag = @"tag:yaml.org,2002:bool";
                    break;
                }
            }
        }
        
        if(!tag) {
            NSLog(@"Warning: Unknown ObjC type encountered in number, %s, encoding as string", objCType);
            tag = @"tag:yaml.org,2002:str";
        }
    }
    
    return tag;
}

- (NSString *)YACYAMLScalarString
{
    if([self YACYAMLArchivingExtensions_isBoolean]) {
        return self.boolValue ? @"y" : @"n";
    } else {
        return [self stringValue];
    }
}

@end



@implementation NSArray (YACYAMLArchivingExtensions) 

- (BOOL)YACYAMLTagCanBePlainImplicit
{
    return YES;
}

- (BOOL)YACYAMLTagCanBeQuotedImplicit
{
    return YES;
}

- (NSString *)YACYAMLTag
{
    return @"tag:yaml.org,2002:seq";
}

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder
{
    for(id obj in self) {
        [coder encodeObject:obj];
    }
}

@end



@implementation NSDictionary (YACYAMLArchivingExtensions) 

- (BOOL)YACYAMLTagCanBePlainImplicit
{
    return YES;
}

- (BOOL)YACYAMLTagCanBeQuotedImplicit
{
    return YES;
}

- (NSString *)YACYAMLTag
{
    return @"tag:yaml.org,2002:map";
}

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder
{
    // Note that NSCoder requires our keys to be strings, but we know that,
    // underneath, a YACYAMLArchivingObject can deal with keys of arbitraty 
    // types, so we take advantege of that when we store NSDictionaries as
    // native YAML mappings.
    for(id key in [self keyEnumerator]) {
        [coder encodeObject:[self objectForKey:key]
                     forKey:key];
    }
}

@end


@implementation NSNull (YACYAMLArchivingExtensions)

- (NSString *)YACYAMLTag
{
    return @"tag:yaml.org,2002:NULL";
}

- (BOOL)YACYAMLTagCanBePlainImplicit
{
    return YES;
}

- (BOOL)YACYAMLTagCanBeQuotedImplicit
{
    return YES;
}

- (NSString *)YACYAMLScalarString
{
    return nil;
}

@end



@implementation NSSet (YACYAMLArchivingExtensions) 

- (BOOL)YACYAMLTagCanBePlainImplicit
{
    return NO;
}

- (BOOL)YACYAMLTagCanBeQuotedImplicit
{
    return NO;
}

- (NSString *)YACYAMLTag
{
    return @"tag:yaml.org,2002:set";
}

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder
{
    // In YAML, a set is a mapping with all-null objects.
    for(id object in self) {
        [coder encodeObject:[NSNull null]
                     forKey:object];
    }
}

@end


@implementation NSData (YACYAMLArchivingExtensions)

- (NSString *)YACYAMLTag
{
    return @"tag:yaml.org,2002:binary";
}

- (NSString *)YACYAMLScalarString
{
    NSString *encodedString= nil;
    
    NSUInteger dataToEncodeLength = self.length;
    
    // Last +1 below to accommodate trailing '\0':
    NSUInteger encodedBufferLength = ((dataToEncodeLength + 2) / 3) * 4 + 1; 
    
    char *encodedBuffer = malloc(encodedBufferLength);
    
    int encodedRealLength = b64_ntop(self.bytes, dataToEncodeLength, 
                                     encodedBuffer, encodedBufferLength);
    
    if(encodedRealLength >= 0) {
        // In real life, you might not want the nul-termination byte, so you 
        // might not want the '+ 1'. 
        encodedString = [[NSString alloc] initWithBytesNoCopy:encodedBuffer
                                                       length:encodedRealLength
                                                     encoding:NSASCIIStringEncoding
                                                 freeWhenDone:YES];
    } else {
        free(encodedBuffer);
    }    
    
    return encodedString;
}

@end