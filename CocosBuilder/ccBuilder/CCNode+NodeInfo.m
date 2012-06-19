//
//  CCNode+NodeInfo.m
//  CocosBuilder
//
//  Created by Viktor Lidholt on 5/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CCNode+NodeInfo.h"
#import "NodeInfo.h"
#import "PlugInNode.h"
#import "SequencerNodeProperty.h"
#import "SequencerKeyframe.h"
#import "CocosBuilderAppDelegate.h"
#import "SequencerHandler.h"
#import "SequencerSequence.h"

@implementation CCNode (NodeInfo)

- (void) setExtraProp:(id)prop forKey:(NSString *)key
{
    NodeInfo* info = self.userObject;
    [info.extraProps setObject:prop forKey:key];
}

- (id) extraPropForKey:(NSString *)key
{
    NodeInfo* info = self.userObject;
    return [info.extraProps objectForKey:key];
}

- (void) setSeqExpanded:(BOOL)seqExpanded
{
    [self setExtraProp:[NSNumber numberWithBool:seqExpanded] forKey:@"seqExpanded"];
}

- (BOOL) seqExpanded
{
    return [[self extraPropForKey:@"seqExpanded"] boolValue];
}

- (PlugInNode*) plugIn
{
    NodeInfo* info = self.userObject;
    return info.plugIn;
}

- (SequencerNodeProperty*) sequenceNodeProperty:(NSString*)name sequenceId:(int)seqId
{
    NodeInfo* info = self.userObject;
    NSDictionary* dict = [info.animatableProperties objectForKey:[NSNumber numberWithInt:seqId]];
    return [dict objectForKey:name];
}

- (void) enableSequenceNodeProperty:(NSString*)name sequenceId:(int)seqId
{
    // Check if animations are already enabled for this node property
    if ([self sequenceNodeProperty:name sequenceId:seqId])
    {
        return;
    }
    
    // Get the right seqence, create one if neccessary
    NodeInfo* info = self.userObject;
    NSMutableDictionary* sequences = [info.animatableProperties objectForKey:[NSNumber numberWithInt:seqId]];
    if (!sequences)
    {
        sequences = [NSMutableDictionary dictionary];
        [info.animatableProperties setObject:sequences forKey:[NSNumber numberWithInt:seqId]];
    }
    
    id baseValue = [self valueForProperty:name atTime:0 sequenceId:seqId];
    
    SequencerNodeProperty* seqNodeProp = [[SequencerNodeProperty alloc] initWithProperty:name node:self];
    seqNodeProp.baseValue = baseValue;
    
    [sequences setObject:seqNodeProp forKey:name];
}

- (void) enableSequenceNodeProperty:(NSString *)name
{
    NSArray* seqs = [SequencerHandler sharedHandler].sequences;
    for (SequencerSequence* seq in seqs)
    {
        [self enableSequenceNodeProperty:name sequenceId:seq.sequenceId];
    }
}

- (void) addKeyframe:(SequencerKeyframe*)keyframe forProperty:(NSString*)name atTime:(float)time sequenceId:(int)seqId
{
    // Make sure timeline is enabled for this property
    [self enableSequenceNodeProperty:name];
    
    SequencerNodeProperty* seqNodeProp = [self sequenceNodeProperty:name sequenceId:seqId];
    [seqNodeProp setKeyframe:keyframe];
    
    // Update property inspector
    [[CocosBuilderAppDelegate appDelegate] updateInspectorFromSelection];
}

- (void) addDefaultKeyframeForProperty:(NSString*)name atTime:(float)time sequenceId:(int)seqId
{
    // Get property type
    NSString* propType = [self.plugIn propertyTypeForProperty:name];
    int keyframeType = [SequencerKeyframe keyframeTypeFromPropertyType:propType];
    
    // Ensure that the keyframe type is supported
    if (!keyframeType)
    {
        return;
    }
    
    // Create keyframe
    SequencerKeyframe* keyframe = [[SequencerKeyframe alloc] init];
    keyframe.time = time;
    keyframe.type = keyframeType;
    keyframe.name = name;
    keyframe.value = [self valueForProperty:name atTime:time sequenceId:seqId];
    
    NSLog(@"keyframe.value: %@", keyframe.value);
    
    [self addKeyframe:keyframe forProperty:name atTime:time sequenceId:seqId];
}

- (id) valueForProperty:(NSString*)name atTime:(float)time sequenceId:(int)seqId
{
    SequencerNodeProperty* seqNodeProp = [self sequenceNodeProperty:name sequenceId:seqId];
    
    int type = [SequencerKeyframe keyframeTypeFromPropertyType:[self.plugIn propertyTypeForProperty:name]];
    
    // Check that type is supported
    if (!type) return NULL;
    
    if (seqNodeProp)
    {
        return [seqNodeProp valueAtTime:time];
    }
    else
    {
        // Just use standard value
        if (type == kCCBKeyframeTypeDegrees)
        {
            return [self valueForKey:name];
        }
    }
    
    return NULL;
}

- (void) updatePropertiesTime:(float)time sequenceId:(int)seqId
{
    NSArray* animatableProps = [self.plugIn animatableProperties];
    for (NSString* propName in animatableProps)
    {
        SequencerNodeProperty* seqNodeProp = [self sequenceNodeProperty:propName sequenceId:seqId];
        if (seqNodeProp)
        {
            [seqNodeProp updateNode:self toTime:time];
        }
    }
}

- (void) deselectAllKeyframes
{
    NodeInfo* info = self.userObject;
    
    NSEnumerator* animPropEnum = [info.animatableProperties objectEnumerator];
    NSDictionary* seq;
    while ((seq = [animPropEnum nextObject]))
    {
        NSEnumerator* seqEnum = [seq objectEnumerator];
        SequencerNodeProperty* prop;
        while ((prop = [seqEnum nextObject]))
        {
            for (SequencerKeyframe* keyframe in prop.keyframes)
            {
                keyframe.selected = NO;
            }
        }
    }
}

- (void) addSelectedKeyframesToArray:(NSMutableArray*)keyframes
{
    NodeInfo* info = self.userObject;
    
    NSEnumerator* animPropEnum = [info.animatableProperties objectEnumerator];
    NSDictionary* seq;
    while ((seq = [animPropEnum nextObject]))
    {
        NSEnumerator* seqEnum = [seq objectEnumerator];
        SequencerNodeProperty* prop;
        while ((prop = [seqEnum nextObject]))
        {
            for (SequencerKeyframe* keyframe in prop.keyframes)
            {
                if (keyframe.selected)
                {
                    [keyframes addObject:keyframe];
                }
            }
        }
    }
}

@end