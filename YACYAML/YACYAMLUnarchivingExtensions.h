//
//  YACYAMLUnarchivingExtensions.h
//  YACYAML
//
//  Created by James Montgomerie on 29/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import "YACYAMLKeyedUnarchiver.h"

void YACYAMLUnarchivingExtensionsRegister(void);

@interface NSNumber (YACYAMLUnarchivingExtensions) <YACYAMLUnarchivingScalar>
@end

@interface NSData (YACYAMLUnarchivingExtensions) <YACYAMLUnarchivingScalar>
@end

@interface NSNull (YACYAMLUnarchivingExtensions) <YACYAMLUnarchivingScalar>
@end



@interface NSMutableArray (YACYAMLUnarchivingExtensions) <YACYAMLUnarchivingSequence>
@end

@interface NSMutableDictionary (YACYAMLUnarchivingExtensions) <YACYAMLUnarchivingMapping>
@end

@interface NSMutableSet (YACYAMLUnarchivingExtensions) <YACYAMLUnarchivingMapping>
@end

