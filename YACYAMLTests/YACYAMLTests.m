//
//  YACYAMLTests.m
//  YACYAMLTests
//
//  Created by James Montgomerie on 17/05/2012.
//  Copyright (c) 2012 Things Made Out Of Other Things. All rights reserved.
//

#import "YACYAMLTests.h"

#import <UIKit/UIKit.h>

#import <libYAML/yaml.h>

#import <YACYAML/YACYAML.h>

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

- (void)testFloatScalarArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:
                          [NSNumber numberWithFloat:(float)M_PI], 
                          [NSNumber numberWithDouble:M_PI], 
                          [NSNumber numberWithFloat:MAXFLOAT], 
                          [NSNumber numberWithDouble:INFINITY], 
                          nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    STAssertTrue(data.length != 0, nil);
}

- (void)testIntegerScalarArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:
                          [NSNumber numberWithChar:CHAR_MAX], 
                          [NSNumber numberWithChar:CHAR_MIN], 
                          [NSNumber numberWithUnsignedChar:UCHAR_MAX], 
                          [NSNumber numberWithUnsignedChar:0], 
                          [NSNumber numberWithShort:SHRT_MAX], 
                          [NSNumber numberWithShort:SHRT_MIN], 
                          [NSNumber numberWithUnsignedShort:USHRT_MAX], 
                          [NSNumber numberWithUnsignedShort:0], 
                          [NSNumber numberWithInt:INT_MAX], 
                          [NSNumber numberWithInt:INT_MIN], 
                          [NSNumber numberWithUnsignedInt:UINT_MAX], 
                          [NSNumber numberWithUnsignedInt:0], 
                          [NSNumber numberWithInteger:NSIntegerMax], 
                          [NSNumber numberWithInteger:NSIntegerMin], 
                          [NSNumber numberWithLong:LONG_MAX], 
                          [NSNumber numberWithLong:LONG_MIN], 
                          [NSNumber numberWithUnsignedLong:ULONG_MAX], 
                          [NSNumber numberWithUnsignedLong:0],
                          [NSNumber numberWithUnsignedInteger:NSUIntegerMax], 
                          [NSNumber numberWithUnsignedInteger:0],
                          nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    STAssertTrue(data.length != 0, nil);
}

- (void)testBooleanArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:
                          [NSNumber numberWithBool:YES],
                          [NSNumber numberWithBool:NO],
                          nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    STAssertTrue(data.length != 0, nil);
}


- (void)testDataArchiving
{
    char bytes[] = "1234567890";
    
    NSArray *testArray = [NSArray arrayWithObjects:
                          [NSData dataWithBytesNoCopy:bytes length:sizeof(bytes) freeWhenDone:NO],
                          nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    STAssertTrue(data.length != 0, nil);
}


- (void)testNullArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:@"one", [NSNull null], @"two", [NSNull null], nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    STAssertTrue(data.length != 0, nil);
}


- (void)testSetArchiving
{
    NSArray *testArray = [NSSet setWithObjects:@"one", @"two",  @"three", @"four", @"two", nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    STAssertTrue(data.length != 0, nil);
}


- (void)testEmptyString
{
    NSArray *testArray = [NSArray arrayWithObjects:@"one", @"",  @"", @"three", @"four", nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    STAssertTrue(data.length != 0, nil);
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


- (void)testUIButton
{
    UIView *view = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 320, 480)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = [UIColor redColor];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:view];
    
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
