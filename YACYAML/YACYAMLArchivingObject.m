//
//  YACYAMLArchivingObject.m
//  YACYAML
//
//  Created by James Montgomerie on 18/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import <libYAML/yaml.h>

#import "YACYAMLKeyedArchiver.h"
#import "YACYAMLKeyedArchiver_Package.h"

#import "YACYAMLArchivingObject.h"
#import "YACYAMLArchivingExtensions.h"

@interface YACYAMLArchivingObject ()
@property (nonatomic, assign) BOOL needsAnchor;
@end

@implementation YACYAMLArchivingObject {
    __unsafe_unretained YACYAMLKeyedArchiver *_archiver;
    id _representedObject;
    
    NSMutableArray *_unkeyedChildren;
    NSMutableArray *_keyedChildren;
    
    BOOL _needsAnchor;
    NSString *_emittedAnchor;
}

@synthesize representedObject = _representedObject;
@synthesize needsAnchor = _needsAnchor;

- (id)initWithRepresentedObject:(id)representedObject
                    forArchiver:(YACYAMLKeyedArchiver *)archiver
{
    if((self = [super init])) {
        _representedObject = representedObject;
        _archiver = archiver;
    }
    return self;
}

- (BOOL)allowsKeyedCoding
{
    return YES;
}

- (YACYAMLArchivingObject *)_archivingObjectForObject:(id)obj
{
    YACYAMLArchivingObject *archivingObject = [_archiver previouslySeenArchivingObjectForObject:obj];
    if(archivingObject) {
        // We've already seen this object, don't archive it again, but mark it
        // as needing an anchor in the emitted YAML so that we know to emit one
        // when we come to writing the file.
        archivingObject.needsAnchor = YES;
    } else {
        archivingObject = [[YACYAMLArchivingObject alloc] initWithRepresentedObject:obj
                                                                        forArchiver:_archiver];
        
        if([obj respondsToSelector:@selector(YACYAMLScalarString)]) {
            if(_archiver.scalarAnchorsAllowed) {
                [_archiver pushArchivingObject:archivingObject];
                [_archiver popArchivingObject];
            }
        } else {
            [_archiver pushArchivingObject:archivingObject];
            [obj YACYAMLEncodeWithCoder:_archiver];
            [_archiver popArchivingObject];
        }
    }
    return archivingObject;
}

- (void)encodeChild:(id)obj forKey:(id)key
{
    YACYAMLArchivingObject *archivingObject = [self _archivingObjectForObject:obj];
    if(key) {
        if(!_keyedChildren) {
            _keyedChildren = [[NSMutableArray alloc] init];
        }
        [_keyedChildren addObject:[self _archivingObjectForObject:key]];
        [_keyedChildren addObject:archivingObject];
    } else {
        if(!_unkeyedChildren) {
            _unkeyedChildren = [[NSMutableArray alloc] init];
        }
        [_unkeyedChildren addObject:archivingObject];
    }
}

- (void)emitWithEmitter:(yaml_emitter_t *)emitter;
{
    yaml_event_t event = {};
    id obj = self.representedObject;
    
    if(obj) {
        if(_emittedAnchor) {
            // An anchor has already been emitted for this object,
            // so just refer to it rather than emitting again.
            yaml_alias_event_initialize(&event, (yaml_char_t *)_emittedAnchor.UTF8String);
            yaml_emitter_emit(emitter, &event);
        } else {
            yaml_char_t *anchor = NULL;
            if(_needsAnchor) {
                // We know that this object will be referred to again later in
                // the archive, so generate an anchor for it.
                _emittedAnchor = [_archiver generateAnchor];
                anchor = (yaml_char_t *)_emittedAnchor.UTF8String;
            }
            
            NSString *customTag = [obj YACYAMLTag];
            
            if([obj respondsToSelector:@selector(YACYAMLScalarString)]) {
                // This is a scalar object.  Emit it.
                NSString *string = [(id<YACYAMLArchivingScalar>)obj YACYAMLScalarString];
                            
                const char *stringChars;
                int stringCharsLength;
                yaml_scalar_style_t style;

                // The below deals with the difference between an empty
                // string, and a nill string.
                if(string) {
                    stringChars = [string UTF8String];
                    stringCharsLength = strlen(stringChars);
                    if(stringCharsLength) {
                        style = YAML_ANY_SCALAR_STYLE;
                    } else {
                        style = YAML_SINGLE_QUOTED_SCALAR_STYLE;
                    }
                } else {
                    stringChars = "";
                    stringCharsLength = 0;
                    style = YAML_PLAIN_SCALAR_STYLE;
                }
                
                yaml_scalar_event_initialize(&event,
                                             anchor,
                                             customTag ? (yaml_char_t *) 
                                                (yaml_char_t *)customTag.UTF8String : 
                                                (yaml_char_t *)YAML_STR_TAG, 
                                             (yaml_char_t *)stringChars,
                                             stringCharsLength,
                                             [obj YACYAMLTagCanBePlainImplicit],
                                             [obj YACYAMLTagCanBeQuotedImplicit],
                                             style);
                yaml_emitter_emit(emitter, &event);
            } else {
                // This is an obect with children.
                if(_keyedChildren) {
                    // This object has keyed chidren, so we use a map to 
                    // represent it.
                    yaml_mapping_start_event_initialize(&event, 
                                                        anchor,
                                                        customTag ? 
                                                            (yaml_char_t *)customTag.UTF8String :
                                                            (yaml_char_t *)YAML_MAP_TAG, 
                                                        [obj YACYAMLTagCanBePlainImplicit], 
                                                        YAML_ANY_MAPPING_STYLE);
                    yaml_emitter_emit(emitter, &event);
                    
                    if(_unkeyedChildren) {
                        // This object has keyed children /and/ unkeyed
                        // children.  Put the unkeyed children in a sequence 
                        // under a special key.
                        static const char *key = "__unkeyedChildren";
                        yaml_scalar_event_initialize(&event,
                                                     NULL,
                                                     (yaml_char_t *)YAML_STR_TAG, 
                                                     (yaml_char_t *)key,
                                                     strlen(key),
                                                     1,
                                                     1,
                                                     YAML_ANY_SCALAR_STYLE);
                        yaml_emitter_emit(emitter, &event);
                    }
                }
                if(_unkeyedChildren || !_keyedChildren) {
                    // Emit a sequence for the unkeyed children.
                    // Note that, in the case that there are no keyed children,
                    // we emit this even if there's no unkeyed children, so a 
                    // non-scalar object with no children is represented as an
                    // empty sequence.
                    yaml_sequence_start_event_initialize(&event,
                                                         _keyedChildren ? 
                                                            NULL : 
                                                            anchor,
                                                         (!_keyedChildren && customTag) ? 
                                                            (yaml_char_t *)customTag.UTF8String : 
                                                            (yaml_char_t *)YAML_SEQ_TAG,
                                                         _keyedChildren ?
                                                             1 :
                                                             [obj YACYAMLTagCanBePlainImplicit], 
                                                         YAML_ANY_SEQUENCE_STYLE);
                    yaml_emitter_emit(emitter, &event);
                    
                    for(YACYAMLArchivingObject *child in _unkeyedChildren) {
                        [child emitWithEmitter:emitter];
                    }
                    
                    yaml_sequence_end_event_initialize(&event);
                    yaml_emitter_emit(emitter, &event);
                }
                if(_keyedChildren) {
                    NSParameterAssert((_keyedChildren.count % 2) == 0);
                    
                    // Emit the keyed children (the mapping we're emitting these
                    // into was started above, before we dealt with any
                    // potential unkeyed children).
                    for(YACYAMLArchivingObject *key in _keyedChildren) {
                        [key emitWithEmitter:emitter];
                    }

                    // All keyed children emitted, close the mapping.
                    yaml_mapping_end_event_initialize(&event);
                    yaml_emitter_emit(emitter, &event);
                }
            }
        }
    } else {
        // No represented object means we're the root of the tree.
        for(YACYAMLArchivingObject *child in _unkeyedChildren) {
            yaml_document_start_event_initialize(&event, 
                                                 NULL, 
                                                 NULL, 
                                                 NULL,
                                                 1);
            yaml_emitter_emit(emitter, &event);

            [child emitWithEmitter:emitter];

            yaml_document_end_event_initialize(&event, 1);
            yaml_emitter_emit(emitter, &event);
        }
    }
}

@end
