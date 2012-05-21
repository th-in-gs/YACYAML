//
//  YACYAMLTests.m
//  YACYAMLTests
//
//  Created by James Montgomerie on 17/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import "YACYAMLTests.h"

#import <libYAML/yaml.h>

#import <YACYAML/YACYAMLKeyedArchiver.h>

@interface YACYAMLKeyedArchiver (testing)
- (NSString *)generateAnchor;
@end

@implementation YACYAMLTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testLibYAMLParsing
{
    yaml_parser_t parser;
    yaml_event_t event;

    yaml_parser_initialize(&parser);

    char *input = "[ 'one', 1.01, 1, YES, false ]";
    yaml_parser_set_input_string(&parser, (const yaml_char_t *)input, strlen(input));
    
    BOOL sawError = NO;
    BOOL done = NO;
    while(!done) {
        if(yaml_parser_parse(&parser, &event)) {
            done = (event.type == YAML_STREAM_END_EVENT);
            yaml_event_delete(&event);
        } else {
            sawError = YES;
            done = YES;
        }
    }
    
    yaml_parser_delete(&parser);
    
    STAssertFalse(sawError, nil);
}

- (void)testSimpleArrayArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:@"one", @"two", @"three with a space and a colon:", nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    STAssertTrue(data.length != 0, nil);
}

- (void)testSimpleDictionaryArchiving
{
    NSDictionary *testDictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"one", @"onekey",
                                    @"two", @"twokey",
                                    @"three", @"threekey",
                                    [NSArray arrayWithObjects:@"one", @"two", @"three", nil], @"fourKey",
                                    [NSDictionary dictionaryWithObjectsAndKeys:@"one", @"onekey",
                                     @"two", @"twokey",
                                     @"three", @"threekey",
                                     [NSArray arrayWithObjects:@"one", @"two", @"three", nil], @"fourKey",
                                     nil], @"dict",
                                    [NSArray arrayWithObjects:@"array", nil], [NSArray arrayWithObjects:@"arrayThatIsAKey", nil],
                                    nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testDictionary];
    
    STAssertTrue(data.length != 0, nil);
}


- (void)testAnchorGeneration
{
    YACYAMLKeyedArchiver *archiver = [[YACYAMLKeyedArchiver alloc] initForWritingWithMutableData:nil];
    
    STAssertEqualObjects(@"a", [archiver generateAnchor], nil);
    STAssertEqualObjects(@"b", [archiver generateAnchor], nil);
    
    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }
    
    STAssertEqualObjects(@"A", [archiver generateAnchor], nil);
    STAssertEqualObjects(@"B", [archiver generateAnchor], nil);

    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }

    STAssertEqualObjects(@"aa", [archiver generateAnchor], nil);
    STAssertEqualObjects(@"ab", [archiver generateAnchor], nil);

    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }
    
    STAssertEqualObjects(@"aA", [archiver generateAnchor], nil);
    STAssertEqualObjects(@"aB", [archiver generateAnchor], nil);

    
    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }
    
    STAssertEqualObjects(@"ba", [archiver generateAnchor], nil);
    STAssertEqualObjects(@"bb", [archiver generateAnchor], nil);

    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }
    
    STAssertEqualObjects(@"bA", [archiver generateAnchor], nil);
    STAssertEqualObjects(@"bB", [archiver generateAnchor], nil);
    
    for(int j = 0; j < 52; ++j) {
        [archiver generateAnchor];
    }
    
    STAssertEqualObjects(@"cC", [archiver generateAnchor], nil);
    STAssertEqualObjects(@"cD", [archiver generateAnchor], nil);
        
    for(int i = 0; i < 52; ++i) {
        for(int j = 0; j < 52; ++j) {
            [archiver generateAnchor];
        }
    }

    STAssertEqualObjects(@"adE", [archiver generateAnchor], nil);
    STAssertEqualObjects(@"adF", [archiver generateAnchor], nil);
}

@end
