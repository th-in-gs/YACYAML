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
        // Get the next event.
        if(yaml_parser_parse(&parser, &event)) {
            /* Are we finished? */
            done = (event.type == YAML_STREAM_END_EVENT);
            
            /* The application is responsible for destroying the event object. */
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
    NSArray *testArray = [NSArray arrayWithObjects:@"one", @"two", @"three", nil];
    
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



@end
