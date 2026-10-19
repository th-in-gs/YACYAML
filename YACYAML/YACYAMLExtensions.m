//
//  YACYAMLExtensions.m
//  YACYAML
//
//  Created by James Montgomerie on 31/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import "YACYAMLExtensions.h"
#import "YACYAMLKeyedArchiver.h"
#import "YACYAMLKeyedUnarchiver.h"

@implementation NSObject (YACYAMLExtensions)

- (NSString *)YACYAMLEncodedString
{
    return [YACYAMLKeyedArchiver archivedStringWithRootObject:self];
}

- (NSData *)YACYAMLEncodedData
{
    return [YACYAMLKeyedArchiver archivedDataWithRootObject:self];
}

- (NSString *)YACYAMLEncodedStringWithError:(NSError **)error
{
    return [YACYAMLKeyedArchiver archivedStringWithRootObject:self options:YACYAMLKeyedArchiverOptionNone error:error];
}

- (NSData *)YACYAMLEncodedDataWithError:(NSError **)error
{
    return [YACYAMLKeyedArchiver archivedDataWithRootObject:self options:YACYAMLKeyedArchiverOptionNone error:error];
}

@end

            
@implementation NSString (YACYAMLExtensions)

- (id)YACYAMLDecode
{
    return [self YACYAMLDecodeBasic];
}

- (id)YACYAMLDecodeBasic
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithString:self options:YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder];
}

- (id)YACYAMLDecodeAll
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithString:self];
}

- (id)YACYAMLDecodeWithError:(NSError **)error
{
    return [self YACYAMLDecodeBasicWithError:error];
}

- (id)YACYAMLDecodeBasicWithError:(NSError **)error
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithString:self options:YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder error:error];
}

- (id)YACYAMLDecodeAllWithError:(NSError **)error
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithString:self options:YACYAMLKeyedUnarchiverOptionNone error:error];
}

@end

            
@implementation NSData (YACYAMLExtensions)

- (id)YACYAMLDecode
{
    return [self YACYAMLDecodeBasic];
}

- (id)YACYAMLDecodeBasic
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithData:self options:YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder];
}

- (id)YACYAMLDecodeAll
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithData:self];
}

- (id)YACYAMLDecodeWithError:(NSError **)error
{
    return [self YACYAMLDecodeBasicWithError:error];
}

- (id)YACYAMLDecodeBasicWithError:(NSError **)error
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithData:self options:YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder error:error];
}

- (id)YACYAMLDecodeAllWithError:(NSError **)error
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithData:self options:YACYAMLKeyedUnarchiverOptionNone error:error];
}

@end
