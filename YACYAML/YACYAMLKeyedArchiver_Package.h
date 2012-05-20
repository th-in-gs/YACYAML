//
//  YACYAMLKeyedArchiver_Package.h
//  YACYAML
//
//  Created by James Montgomerie on 18/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YACYAMLArchivingObject;

@interface YACYAMLKeyedArchiver ()

- (void)pushArchivingObject:(YACYAMLArchivingObject *)archivingObject;
- (void)popArchivingObject;

- (YACYAMLArchivingObject *)previouslySeenArchivingObjectForObject:(id)object;


@end
