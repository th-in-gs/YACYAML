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

@interface YACYAMLArchivingObject ()
@property (nonatomic, assign) BOOL needsAnchor;
@end

@implementation YACYAMLArchivingObject {
    __unsafe_unretained YACYAMLKeyedArchiver *_archiver;
    id _representedObject;
    
    NSMutableArray *_unkeyedChildren;
    NSMutableArray *_keyedChildren;
    
    BOOL _needsAnchor;
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
        
        // Make sure to add this to the _objectToArchivingObject map before 
        // encoding it, so that if it's encountered again (i.e. in a cycle)
        // we can refer to it and not just recurse for ever.
        [_archiver pushArchivingObject:archivingObject];
        
        if(![obj respondsToSelector:@selector(YACYAMLScalarString)]) {
            [obj YACYAMLEncodeWithCoder:_archiver];
        }
        
        [_archiver popArchivingObject];
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
        if([obj respondsToSelector:@selector(YACYAMLScalarString)]) {
            NSString *string = [(id<YACYAMLArchivingScalar>)obj YACYAMLScalarString];
                        
            const char *stringChars = [string UTF8String];
            
            yaml_scalar_event_initialize(&event,
                                         NULL,
                                         (yaml_char_t *)YAML_STR_TAG, 
                                         (yaml_char_t *)stringChars,
                                         strlen(stringChars),
                                         1,
                                         1,
                                         YAML_ANY_SCALAR_STYLE);
            yaml_emitter_emit(emitter, &event);
            //yaml_event_delete(&event);
        } else {
            if(_keyedChildren) {
                yaml_mapping_start_event_initialize(&event, 
                                                    NULL,
                                                    (yaml_char_t *)YAML_MAP_TAG, 
                                                    1, 
                                                    YAML_ANY_MAPPING_STYLE);
                yaml_emitter_emit(emitter, &event);
                //yaml_event_delete(&event);
                
                if(_unkeyedChildren) {
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
                    //yaml_event_delete(&event);
                }
            }
            if(_unkeyedChildren) {
                yaml_sequence_start_event_initialize(&event,
                                                     NULL,
                                                     (yaml_char_t *)YAML_SEQ_TAG,
                                                     1, 
                                                     YAML_ANY_SEQUENCE_STYLE);
                yaml_emitter_emit(emitter, &event);
                //yaml_event_delete(&event);
                
                for(YACYAMLArchivingObject *child in _unkeyedChildren) {
                    [child emitWithEmitter:emitter];
                }
                
                yaml_sequence_end_event_initialize(&event);
                yaml_emitter_emit(emitter, &event);
                //yaml_event_delete(&event);
            }
            if(_keyedChildren) {
                NSParameterAssert((_keyedChildren.count % 2) == 0);
                
                for(YACYAMLArchivingObject *key in _keyedChildren) {
                    [key emitWithEmitter:emitter];
                }

                yaml_mapping_end_event_initialize(&event);
                yaml_emitter_emit(emitter, &event);
                //yaml_event_delete(&event);
            }
        }
    } else {
        // No represented object means we're the root of the tree.
        yaml_document_start_event_initialize(&event, 
                                             NULL, 
                                             NULL, 
                                             NULL,
                                             1);
        yaml_emitter_emit(emitter, &event);
        //yaml_event_delete(&event);

        for(YACYAMLArchivingObject *child in _unkeyedChildren) {
            [child emitWithEmitter:emitter];
        }

        yaml_document_end_event_initialize(&event, 1);
        yaml_emitter_emit(emitter, &event);
        //yaml_event_delete(&event);
    }
}

@end
