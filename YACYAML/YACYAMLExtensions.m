//
//  YACYAMLExtensions.m
//  YACYAML
//
//  Created by James Montgomerie on 31/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import "YACYAMLExtensions.h"
#import "YACYAMLKeyedArchiver.h"
#import "YACYAMLKeyedUnarchiver.h"

@implementation NSObject (YACYAMLExtensions)

- (NSString *)YACYAMLArchiveString
{
    return [YACYAMLKeyedArchiver archivedStringWithRootObject:self];
}

- (NSData *)YACYAMLArchiveData
{
    return [YACYAMLKeyedArchiver archivedDataWithRootObject:self];
}

@end

            
@implementation NSString (YACYAMLExtensions)

- (id)YACYAMLUnarchive
{
    return [self YACYAMLUnarchiveBasic];
}

- (id)YACYAMLUnarchiveBasic
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithString:self options:YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder];
}

- (id)YACYAMLUnarchiveAll
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithString:self];
}

@end

            
@implementation NSData (YACYAMLExtensions)

- (id)YACYAMLUnarchive
{
    return [self YACYAMLUnarchiveBasic];
}

- (id)YACYAMLUnarchiveBasic
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithData:self options:YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder];
}

- (id)YACYAMLUnarchiveAll
{
    return [YACYAMLKeyedUnarchiver unarchiveObjectWithData:self];
}

@end
