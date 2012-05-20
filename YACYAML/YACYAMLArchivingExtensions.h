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

@interface NSString (YACYAMLArchivingExtensions) <YACYAMLArchivingScalar>
@end

@interface NSNumber (YACYAMLArchivingExtensions) <YACYAMLArchivingScalar>
@end
