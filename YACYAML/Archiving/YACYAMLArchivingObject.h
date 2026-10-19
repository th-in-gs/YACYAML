//
//  YACYAMLArchivingObject.h
//  YACYAML
//
//  Created by James Montgomerie on 18/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YACYAMLKeyedArchiver;
struct yaml_emitter_s;

@interface YACYAMLArchivingObject : NSObject

@property (nonatomic, strong) id representedObject;

- (id)initWithRepresentedObject:(id)representedObject
                    forArchiver:(YACYAMLKeyedArchiver *)archiver;
- (void)encodeChild:(id)obj forKey:(id)key;

// Adds a placeholder for a child that is only to be encoded if it's encoded (unconditionally)
// somewhere else in the archive.  -resolveConditionalChild:withTarget: is called for it,
// when the archive is finished, to say which.
- (void)encodeConditionalChild:(id)obj forKey:(id)key;
- (void)resolveConditionalChild:(YACYAMLArchivingObject *)placeholder withTarget:(YACYAMLArchivingObject *)target;

// For a placeholder: the object that it is a child of.
@property (nonatomic, unsafe_unretained) YACYAMLArchivingObject *conditionalParent;

- (void)emitWithEmitter:(struct yaml_emitter_s *)emitter;

@end