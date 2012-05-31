//
//  YACYAMLArchivingExtensions.h
//  YACYAML
//
//  Created by James Montgomerie on 18/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import "YACYAMLKeyedArchiver.h"


@interface NSObject (YACYAMLArchivingExtensions) <YACYAMLArchivingCustomEncoding>
@end


@interface NSString (YACYAMLArchivingExtensions) <YACYAMLArchivingCustomEncoding, YACYAMLArchivingScalar>
@end

@interface NSNumber (YACYAMLArchivingExtensions) <YACYAMLArchivingCustomEncoding, YACYAMLArchivingScalar>
@end


@interface NSArray (YACYAMLArchivingExtensions) <YACYAMLArchivingCustomEncoding>
@end

@interface NSDictionary (YACYAMLArchivingExtensions) <YACYAMLArchivingCustomEncoding>
@end

@interface NSNull (YACYAMLArchivingExtensions) <YACYAMLArchivingCustomEncoding>
@end

@interface NSSet (YACYAMLArchivingExtensions) <YACYAMLArchivingCustomEncoding>
@end


@interface NSData (YACYAMLArchivingExtensions) <YACYAMLArchivingCustomEncoding, YACYAMLArchivingScalar>
@end