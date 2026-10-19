//
//  YACYAMLUnarchivingObject.m
//  YACYAML
//
//  Created by James Montgomerie on 24/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import "YACYAML_Package.h"

#import "YACYAMLUnarchivingObject.h"
#import "YACYAMLKeyedUnarchiver.h"
#import "YACYAMLKeyedUnarchiver_Package.h"
#import "YACYAMLUnarchivingExtensions.h"
#import "YACYAMLConstants.h"

#import <libYAML/yaml.h>
#import <objc/message.h>
#import <objc/runtime.h>

@implementation YACYAMLUnarchivingObject {
    __unsafe_unretained YACYAMLKeyedUnarchiver *_unarchiver;

    NSArray *_unkeyedChildren;
    NSDictionary *_keyedChildren;

    NSUInteger _unkeyedChildIndex;

    // See comments in _parseWithParser:... for the purpose of this ivar.
    void *_uninitializedRepresentedObject;
    id _representedObject;

    // Set to YES when another object resolves this object's anchor during decoding.
    // Used to detect the hazardous case: initWithCoder: returns a different object
    // AND the anchor was already resolved by a nested object.
    BOOL _anchorWasResolved;
    
    NSUInteger _startLine;
    NSUInteger _startColumn;
}

@synthesize anchorWasResolved = _anchorWasResolved;
@synthesize startLine = _startLine;
@synthesize startColumn = _startColumn;

- (id)representedObject
{
    // See comments in _parseWithParser:...
    return _representedObject ?: (__bridge id)_uninitializedRepresentedObject;
}

- (void) dealloc
{
    // De-annotate our represented object in case it was annotated for merge keys.
    objc_setAssociatedObject(_representedObject, YACYAMLOriginalMapAnnotationKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

- (id)initWithParser:(struct yaml_parser_s *)parser
       forUnarchiver:(YACYAMLKeyedUnarchiver *)unarchiver;
{
    if((self = [super init])) {
        _unarchiver = unarchiver;
        
        yaml_event_t event; 
        int worked = yaml_parser_parse(parser, &event);
        if(worked) {
            // The marks count from 0; people count from 1.
            _startLine = event.start_mark.line + 1;
            _startColumn = event.start_mark.column + 1;
            
            switch(event.type) {
                case YAML_STREAM_START_EVENT:
                    NSLog(@"Warning: Unexpected stream start event from YAML parser.");
                    // Fall through, process as sequence.
                case YAML_DOCUMENT_START_EVENT:
                    [self _parseWithParser:parser 
                            forEventOfType:event.type
                                       tag:nil
                                    anchor:nil];
                    break;
                case YAML_SEQUENCE_START_EVENT:
                    [self _parseWithParser:parser
                            forEventOfType:event.type
                                       tag:event.data.sequence_start.tag
                                    anchor:event.data.sequence_start.anchor];
                    break;
                                        
                case YAML_MAPPING_START_EVENT:
                    [self _parseWithParser:parser    
                            forEventOfType:event.type
                                       tag:event.data.mapping_start.tag
                                    anchor:event.data.mapping_start.anchor];

                    break;
                    
                case YAML_SCALAR_EVENT:
                    [self _parseScalarEvent:&event];
                    break; 
                    
                case YAML_ALIAS_EVENT:
                    self = [_unarchiver previouslyInstantiatedUnarchivingObjectForAnchor:[NSString stringWithUTF8String:(const char *)event.data.alias.anchor]];
                    break;
                    
                default:
                    // Probably an end event.
                    self = nil;
                    break;
            }
            
            yaml_event_delete(&event);
        } else {
            self = nil;
        }
    }
    return self;
}

// Local tags (the ones that start with a single '!') are ignored, as if the node had no tag,
// if the unarchiver has been asked to.
- (BOOL)_shouldIgnoreTag:(const yaml_char_t *)tag
{
    return _unarchiver.localTagsDisallowed && tag[0] == '!';
}

- (void)_parseScalarEvent:(yaml_event_t *)event
{
    
    Class representedClass = nil;
    
    if(event->data.scalar.tag && ![self _shouldIgnoreTag:event->data.scalar.tag]) {
        NSString *tagString = [NSString stringWithUTF8String:(const char *)event->data.scalar.tag];
        representedClass = [[_unarchiver class] classForYAMLTag:tagString];
        if(representedClass) {
            if([representedClass respondsToSelector:@selector(objectWithYACYAMLScalarUTF8String:length:)]) {
                _representedObject = [representedClass objectWithYACYAMLScalarUTF8String:(const char *)event->data.scalar.value
                                                                                  length:event->data.scalar.length];
            }
        }
    }
    
    if(!_representedObject) {
        NSString *scalarString = (__bridge_transfer NSString *)CFStringCreateWithBytes(kCFAllocatorDefault,
                                                                                       event->data.scalar.value,
                                                                                       event->data.scalar.length,
                                                                                       kCFStringEncodingUTF8,
                                                                                       NO);
        
        if(!representedClass && event->data.scalar.plain_implicit) {
            representedClass = [[_unarchiver class] classForYAMLScalarString:scalarString];
        }

        if([representedClass respondsToSelector:@selector(objectWithYACYAMLScalarString:)]) {
            _representedObject = [representedClass objectWithYACYAMLScalarString:scalarString];
        } else {
            _representedObject = scalarString;
        }
    }
    
    const char *anchor = (const char *)event->data.scalar.anchor;
    if(anchor) {
        [_unarchiver setUnarchivingObject:self
                                forAnchor:[NSString stringWithUTF8String:anchor]];
    }
}


- (void)_parseWithParser:(yaml_parser_t *)parser
          forEventOfType:(yaml_event_type_t)type
                     tag:(const yaml_char_t *)tag
                  anchor:(const yaml_char_t *)anchor
{
    YACYAMLUnarchivingObject *keyAndData[2];
    NSUInteger index = 0;
        
    NSString *anchorString = nil;
    if(anchor) {
        anchorString = [NSString stringWithUTF8String:(const char *)anchor];
    }
    
    
    Class representedClass = nil;
    if(tag && ![self _shouldIgnoreTag:tag]) {
        NSString *tagString = [NSString stringWithUTF8String:(const char *)tag];
        representedClass = [[_unarchiver class] classForYAMLTag:tagString];
    }
    if(!representedClass) {
        if(type == YAML_MAPPING_START_EVENT) {
            representedClass = [NSDictionary class];
        } else {
            representedClass = [NSArray class];
        }
    }
    
    if(type == YAML_MAPPING_START_EVENT && 
       [representedClass instancesRespondToSelector:@selector(YACYAMLUnarchivingSetObject:forKey:)]) {
        _representedObject = [representedClass objectForYACYAMLUnarchiving];
    } else if([representedClass instancesRespondToSelector:@selector(YACYAMLUnarchivingAddObject:)]) {
        _representedObject = [representedClass objectForYACYAMLUnarchiving];
    } else {
        if(!_unarchiver.isInitWithCoderDisallowed) {
            // No init.  We'll call initWithCoder later (see further comments
            // lower in the method).

            // ARC gets confused if we strongly store an alloc'd object, then
            // later call -initWithCoder: which may return a DIFFERENT object.
            // (The original author saw CALayer do this in 2013.)
            //
            // Per Cocoa convention: if initWithCoder: returns a different object,
            // it RELEASES the original alloc'd object. So:
            //   1. alloc -> object A (+1 retain)
            //   2. initWithCoder: on A -> returns B (≠ A), releases A (deallocated if nothing else owns it)
            //   3. Caller owns B (+1)
            //
            // If we stored A in a strong ivar, ARC would try to release A when
            // overwriting with B at step 3 -> over-release.
            // Solution: store A in a void* ivar (ARC ignores it), then use
            // __bridge_transfer when assigning B to the strong ivar.
            _uninitializedRepresentedObject = (__bridge void *)((id(*)(id,SEL))objc_msgSend)(representedClass, @selector(alloc));
        } else {
            // -initWithCoder: is disallowed.  Just present these as a simple
            // mapping or sequence in an NSDictionary or NSArray.
            if(type == YAML_MAPPING_START_EVENT) {
                representedClass = [NSDictionary class];
            } else {
                representedClass = [NSArray class];
            }     
            _representedObject = [representedClass objectForYACYAMLUnarchiving];
        } 
    }
    
    BOOL shouldAnnotateWithOriginalMap = NO;
    
    if(anchorString) {
        // This is an invalid thing to do if the -initWithCoder: later returns
        // a different object to the one that alloc returns, but I can't
        // see a way to decode cyclic structures without doing it - we need
        // to be able to return a valid object for an anchor that refers to 
        // this object from 'inside' it, eve though it's not fully 
        // initialized yet.
        //
        // Presumably, the system NSCoder classes do a similar thing.  The
        // only widely used open source one, MAKeyedArchiver, certainly 
        // does, and the GNUStep one seems to too.
        //
        // It looks like, with NSKeyedArchiver, perhaps the client is meant
        // to fix things up by listening for 
        // unarchiver:willReplaceObject:withObject: delegate messages (I'd
        // bet that none do though).  Perhaps a similar delegate method
        // could be implemented in the future for this.
        
        [_unarchiver setUnarchivingObject:self
                                forAnchor:anchorString];
        
        // If a custom map type has been referenced by an anchor, annotate the resulting object
        // with the original mapping values so that it can be merged as part of a merge key.
        shouldAnnotateWithOriginalMap = (type == YAML_MAPPING_START_EVENT) && ![representedClass isSubclassOfClass: [NSDictionary class]];
    }
    
    if(type == YAML_MAPPING_START_EVENT) {
        NSMutableDictionary *buildKeyedChildren = nil;
        id<YACYAMLUnarchivingMapping> mappingElements;
        
        // For objects that implement YACYAMLUnarchivingMapping, we must build up a parallel dictionary of elements
        // as they were in the original map, with which the object is annotated so that it can be used in a merge key.
        // (For objects that don't implement the protocol, we'll just re-use the same dictionary we're already build up for them.)
        NSMutableDictionary *originalMapping = nil;
        
        if([representedClass instancesRespondToSelector:@selector(YACYAMLUnarchivingSetObject:forKey:)]) {
            mappingElements = _representedObject;
            if (shouldAnnotateWithOriginalMap) {
                originalMapping = [[NSMutableDictionary alloc] init];
            }
        } else {
            buildKeyedChildren = [[NSMutableDictionary alloc] init];
            mappingElements = buildKeyedChildren;
        }
        
        YACYAMLUnarchivingObject *nextEventObject = nil;
        while((nextEventObject = [[YACYAMLUnarchivingObject alloc] initWithParser:parser 
                                                                    forUnarchiver:_unarchiver])) {
            keyAndData[index++] = nextEventObject;
            if(index == 2) {
                id key = keyAndData[0].representedObject;
                id value = keyAndData[1].representedObject;
                [mappingElements YACYAMLUnarchivingSetObject: value forKey: key];
                if (originalMapping)
                    [originalMapping YACYAMLUnarchivingSetObject: value forKey: key];
                index = 0;
            }
        }
        
        if(index != 0) {
            NSLog(@"Warning: Unexpected non-even number of children in parsed YAML mapping");
        }
        
        if(buildKeyedChildren) {
            NSArray *unkeyedChildren = [buildKeyedChildren objectForKey:YACYAMLUnkeyedChildrenKey];
            if(unkeyedChildren) {
                _unkeyedChildren = unkeyedChildren;
                [buildKeyedChildren removeObjectForKey:YACYAMLUnkeyedChildrenKey];
            }
            
            _keyedChildren = buildKeyedChildren;
            originalMapping = buildKeyedChildren;
        }
        
        // Annotate the represented object with the original mapping keys and values,
        // so that it can be used in merge keys.
        if(originalMapping) {
            id objToAnnotate = _representedObject ?: (__bridge id)_uninitializedRepresentedObject;
            // Note that objects that will be initialized with initWithCoder: will get re-annotated below:
            // we annotate it in the interim in case anything refers to it before it's initialized.
            objc_setAssociatedObject(objToAnnotate, YACYAMLOriginalMapAnnotationKey, originalMapping, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        };
        
    } else {
        NSMutableArray *buildUnkeyedChildren = nil;
        id<YACYAMLUnarchivingSequence> sequenceElements;
        
        if([representedClass instancesRespondToSelector:@selector(YACYAMLUnarchivingAddObject:)]) {
            sequenceElements = _representedObject;
        } else {
            buildUnkeyedChildren = [[NSMutableArray alloc] init];
            sequenceElements = buildUnkeyedChildren;
        }
        
        YACYAMLUnarchivingObject *nextEventObject = nil;
        while((nextEventObject = [[YACYAMLUnarchivingObject alloc] initWithParser:parser 
                                                                    forUnarchiver:_unarchiver])) {
            [sequenceElements YACYAMLUnarchivingAddObject:nextEventObject.representedObject];
        }
        
        if(buildUnkeyedChildren) {
            _unkeyedChildren = buildUnkeyedChildren;
        }
    }
    
    // The representedObject was allocated above (ick! - see comment above).
    if(_keyedChildren || _unkeyedChildren) {
        [_unarchiver pushUnarchivingObject:self];
        id allocatedObject = (__bridge id)_uninitializedRepresentedObject;
        void * initializedObject = (__bridge void *)((id(*)(id,SEL,id))objc_msgSend)(allocatedObject, @selector(initWithCoder:), _unarchiver);
        _uninitializedRepresentedObject = nil;
        BOOL replaced = (initializedObject != (__bridge void *)allocatedObject);

        // Take ownership and rebalance the stack before any exception can unwind.
        _representedObject = (__bridge_transfer id)initializedObject;
        [_unarchiver popUnarchivingObject];

        // Detect initWithCoder: returning a different object AFTER anchor was resolved.
        // This is the hazardous case: nested object resolved our anchor, then initWithCoder:
        // replaced self. The nested object now holds a stale reference.
        if (replaced && _anchorWasResolved) {
            YACYAMLRaiseDecodingException(YACYAMLAnchorReplacementException,
                                          [NSString stringWithFormat:@"initWithCoder: returned a different object (%@ vs %@) after anchor was resolved by a nested object. "
                                                                      "This breaks cyclic object graph decoding. The nested object holds a stale reference.",
                                                                      _representedObject, allocatedObject],
                                          _startLine,
                                          _startColumn);
        }

        //(Re-)annotate the new object with the original map if necessary.
        if (shouldAnnotateWithOriginalMap && _keyedChildren) {
            objc_setAssociatedObject(_representedObject, YACYAMLOriginalMapAnnotationKey, _keyedChildren, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    // This is a hack that ensures that we can both return the represented 
    // object for these events as an array, and that nextUnkeyedObject
    // will also work on them.
    if(type == YAML_STREAM_START_EVENT || type == YAML_DOCUMENT_START_EVENT) {
        _unkeyedChildren = _representedObject;
        _representedObject = nil;
    }
}

- (id)nextUnkeyedObject
{
    if(_unkeyedChildIndex < _unkeyedChildren.count) {
        return [_unkeyedChildren objectAtIndex:_unkeyedChildIndex++];
    }
    return nil;
}

- (id)keyedObjectForKey:(id)key
{
    return [_keyedChildren objectForKey:key];
}

@end
