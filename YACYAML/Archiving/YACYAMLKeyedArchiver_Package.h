//
//  YACYAMLKeyedArchiver_Package.h
//  YACYAML
//
//  Created by James Montgomerie on 18/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YACYAMLArchivingObject;

@interface YACYAMLKeyedArchiver ()

@property (nonatomic, readonly) BOOL scalarAnchorsAllowed;
@property (nonatomic, readonly) BOOL localTagsDisallowed;

- (void)pushArchivingObject:(YACYAMLArchivingObject *)archivingObject;
- (void)popArchivingObject;
- (void)noteNonAnchoringObject:(YACYAMLArchivingObject *)archivingObject;
- (void)noteConditionalArchivingObject:(YACYAMLArchivingObject *)placeholder;

- (YACYAMLArchivingObject *)previouslySeenArchivingObjectForObject:(id)object;
- (NSString *)generateAnchor;
// How long the anchor that generateAnchor will return next is, without generating it.
- (NSUInteger)nextAnchorLength;

@end
