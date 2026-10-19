//
//  YACYAMLTests.m
//  YACYAMLTests
//
//  Created by James Montgomerie on 17/05/2012.
//  Copyright (c) 2012 James Montgomerie. All rights reserved.
//

#import "YACYAMLTests.h"

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif
#import <QuartzCore/QuartzCore.h>

#import <ImageIO/ImageIO.h>

#import <libYAML/yaml.h>

#import <YACYAML/YACYAML.h>
#import <YACYAML/YACYAMLConstants.h>

#import <math.h>

@interface YACYAMLCustomTypeMerging : NSObject <NSCoding>

@property (retain, nonatomic) NSString *property1;
@property (retain, nonatomic) NSString *property2;

@end

@implementation YACYAMLCustomTypeMerging

- (instancetype) initWithCoder: (NSCoder *)aDecoder
{
    self = [self init];
    if(self) {
        self.property1 = [aDecoder decodeObjectForKey: @"key1"];
        self.property2 = [aDecoder decodeObjectForKey: @"key2"];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)aCoder
{
    [aCoder encodeObject: self.property1 forKey: @"key1"];
    [aCoder encodeObject: self.property2 forKey: @"key2"];
}

@end    
        
@interface YACYAMLTestsNilSubobjectObject : NSObject <NSCoding>
@end

@implementation YACYAMLTestsNilSubobjectObject {
    id _testSubobject;
}

- (BOOL)decodedCorrectly {
    return _testSubobject == nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if(self) {
        _testSubobject = [coder decodeObjectForKey:@"testSubobject"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:nil forKey:@"testSubobject"];
}

@end

// Captures the unarchiver, so tests can inspect its state after an exception.
static YACYAMLKeyedUnarchiver *gCapturedUnarchiver = nil;

// Like YACYAMLSelfReplacingObject, but records the coder it was given.
@interface YACYAMLCapturingReplacingObject : NSObject <NSCoding>
@end

@implementation YACYAMLCapturingReplacingObject

- (instancetype)initWithCoder:(NSCoder *)coder
{
    gCapturedUnarchiver = (YACYAMLKeyedUnarchiver *)coder;
    return (id)[[NSObject alloc] init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end

// Test class that replaces itself in initWithCoder: (like CALayer)
@interface YACYAMLSelfReplacingObject : NSObject <NSCoding>
@end

@implementation YACYAMLSelfReplacingObject

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // Return a DIFFERENT object (simulating CALayer behavior)
    id replacement = [[NSObject alloc] init];
    return replacement;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

@end

// Test class whose initWithCoder: returns self (the normal case)
@interface YACYAMLNormalObject : NSObject <NSCoding>

@property (nonatomic, strong) id child;

@end

@implementation YACYAMLNormalObject

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _child = [coder decodeObjectForKey:@"child"];
    }
    return self;  // Returns self - normal
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.child forKey:@"child"];
}

@end

// An object with some keyed bytes, that decodes them without asking for their length.
@interface YACYAMLBytesObject : NSObject <NSCoding>
@property (nonatomic, assign) BOOL decodedBytesWithNullLength;
@property (nonatomic, assign) BOOL decodedMissingBytesAsNull;
@property (nonatomic, assign) NSUInteger missingBytesLength;
@end

@implementation YACYAMLBytesObject

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        const uint8_t *bytes = [coder decodeBytesForKey:@"bytes" returnedLength:NULL];
        _decodedBytesWithNullLength = (bytes != NULL && memcmp(bytes, "abc", 3) == 0);
        
        NSUInteger length = 99;
        const uint8_t *missing = [coder decodeBytesForKey:@"missing" returnedLength:&length];
        _decodedMissingBytesAsNull = (missing == NULL && [coder decodeBytesForKey:@"missing" returnedLength:NULL] == NULL);
        _missingBytesLength = length;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBytes:(const uint8_t *)"abc" length:3 forKey:@"bytes"];
}

@end

// Objects that provide their own YAML encoding, with a global tag and with a local one.
@interface YACYAMLGlobalTagObject : NSObject
@end

@implementation YACYAMLGlobalTagObject

- (NSString *)YACYAMLArchivingTag
{
    return @"tag:example.com,2026:global";
}

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder
{
    [coder encodeObject:@"global" forKey:@"how"];
}

@end

@interface YACYAMLLocalTagObject : NSObject
@end

@implementation YACYAMLLocalTagObject

- (NSString *)YACYAMLArchivingTag
{
    return @"!local";
}

- (void)YACYAMLEncodeWithCoder:(YACYAMLKeyedArchiver *)coder
{
    [coder encodeObject:@"local" forKey:@"how"];
}

@end

// A CALayer subclass that replaces itself in -initWithCoder: (the pattern that
// -initWithCoder: implementations of some Cocoa classes follow), and that can refer
// to another layer, so that layers can form cycles.
@interface YACYAMLReplacingLayer : CALayer
@property (nonatomic, strong) id partner;
@end

@implementation YACYAMLReplacingLayer

- (instancetype)initWithCoder:(NSCoder *)coder
{
    YACYAMLReplacingLayer *decoded = [super initWithCoder:coder];
    
    // Return a DIFFERENT object, carrying the decoded state over.
    YACYAMLReplacingLayer *replacement = [[YACYAMLReplacingLayer alloc] init];
    replacement.name = decoded.name;
    replacement.bounds = decoded.bounds;
    replacement.partner = [coder decodeObjectForKey:@"partner"];
    return replacement;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:self.partner forKey:@"partner"];
}

@end

@interface YACYAMLKeyedArchiver (testing)
- (NSString *)generateAnchor;
@end

// Package-visible in the library (YACYAMLKeyedUnarchiver_Package.h); redeclared here for tests.
@interface YACYAMLKeyedUnarchiver (TestAccess)
- (NSUInteger)unarchivingObjectStackDepth;
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
    
    XCTAssertFalse(sawError, @"YAML parsing produced unexpected errors");
}

- (void)testFloatScalarArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:
                          [NSNumber numberWithFloat:(float)M_PI], 
                          [NSNumber numberWithDouble:M_PI], 
                          [NSNumber numberWithFloat:MAXFLOAT], 
                          [NSNumber numberWithDouble:INFINITY], 
                          [NSNumber numberWithDouble:-INFINITY], 
                          [NSNumber numberWithDouble:NAN], 
                          (__bridge NSNumber *)kCFNumberPositiveInfinity, 
                          (__bridge NSNumber *)kCFNumberNegativeInfinity, 
                          (__bridge NSNumber *)kCFNumberNaN, 
                          nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectedly zero length");
    
    NSArray *unarchivedArray = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    // A strict isEqual between the test array and the unarchived array doesn't
    // return YES, because the floats can't round-trip through ASCII properly
    // fully.
    // We also lose some type information, because YAML doesn't explicitly
    // encode e.g. float vs. double.
    // Nevertheless, the values are good enough for use, as a comparison of
    // their string represenatation will show.
    //XCTAssertTrue([unarchivedArray isEqual:testArray], nil);
    XCTAssertTrue([[unarchivedArray valueForKey:@"stringValue"]
                                       isEqual:[testArray valueForKey:@"stringValue"]], @"Equality check failed");
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
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSArray *unarchivedArray = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedArray isEqual:testArray], @"Unarchived object not equal to archived object");
}

- (void)testBooleanArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:
                          [NSNumber numberWithBool:YES],
                          [NSNumber numberWithBool:NO],
                          nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSArray *unarchivedArray = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedArray isEqual:testArray], @"Unarchived object not equal to archived object");
}


- (void)testDataArchiving
{
    char bytes[] = 
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890"
        "123456789012345678901234567890123456789012345678901234567890";
    
    NSDictionary *testDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSData dataWithBytesNoCopy:bytes length:sizeof(bytes) freeWhenDone:NO],
                                    @"my data's key",
                                    nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testDictionary];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSArray *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedDictionary isEqual:testDictionary], @"Unarchived object not equal to archived object");
}

- (void)testBigStringArchiving
{
    NSString *string = @"Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum";
    
    NSDictionary *testDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    string,
                                    @"my string's key",
                                    nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testDictionary];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSArray *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedDictionary isEqual:testDictionary], @"Unarchived object not equal to archived object");
}



- (void)testNullArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:@"one", [NSNull null], @"two", [NSNull null], nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSArray *unarchivedArray = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedArray isEqual:testArray], @"Unarchived object not equal to archived object");
}


- (void)testSetArchiving
{
    NSSet *testSet = [NSSet setWithObjects:@"one", @"two", @"three", @"four", @"two", nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testSet];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
}


- (void)testEmptyString
{
    NSArray *testArray = [NSArray arrayWithObjects:@"one", @"", @"", @"three", @"four", nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSArray *unarchivedArray = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedArray isEqual:testArray], @"Unarchived object not equal to archived object");
}



- (void)testSimpleArrayArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:@"one", @"two", @"three with a space and a colon:", nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSArray *unarchivedArray = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedArray isEqual:testArray], @"Unarchived object not equal to archived object");
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
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
        
    NSDictionary *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedDictionary isEqual:testDictionary], @"Unarchived object not equal to archived object");
}

- (void)testStringsVsScalars
{
    NSArray *testArray = [NSArray arrayWithObjects:
                          @"1", 
                          [NSNumber numberWithInt:1],
                          @"y",
                          @"true",
                          [NSNumber numberWithBool:YES],
                          nil];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:testArray];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSArray *unarchivedArray = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedArray isEqual:testArray], @"Unarchived object not equal to archived object");
}


- (void)testNSArchiverChars
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSMutableData *data = [NSMutableData data];
    
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
    char *string = "hello world";
    [archiver encodeValueOfObjCType:"*" at:&string];
     
    [archiver finishEncoding];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
     
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    
    char *newString = nil;
    [unarchiver decodeValueOfObjCType:"*" at:&newString];
    
    XCTAssertTrue(strcmp(string, newString) == 0, @"Unarchived object not equal to archived object");
#pragma clang diagnostic pop
}


- (void)testChars
{
    NSMutableData *data = [NSMutableData data];
    
    YACYAMLKeyedArchiver *archiver = [[YACYAMLKeyedArchiver alloc] initForWritingWithMutableData:data];
    
    char *string = "hello world";
    [archiver encodeValueOfObjCType:"*" at:&string];
    
    [archiver finishEncoding];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    YACYAMLKeyedUnarchiver *unarchiver = [[YACYAMLKeyedUnarchiver alloc] initForReadingWithData:data];
    
    char *newString = nil;
    [unarchiver decodeValueOfObjCType:"*" at:&newString];
    
    XCTAssertTrue(strcmp(string, newString) == 0, @"Unarchived object not equal to archived object");
}

#if TARGET_OS_IOS
- (void)testUIView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = [UIColor redColor];
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:view];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    UIView *unarchivedView = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([[YACYAMLKeyedArchiver archivedDataWithRootObject:unarchivedView] isEqualToData:data], @"Unarchived object not equal to archived object");
}

- (void)testUIButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    button.backgroundColor = [UIColor redColor];
    [button setTitle:@"Tap Me" forState:UIControlStateNormal];

    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:button];

    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;

    UIView *unarchivedView = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertTrue([[YACYAMLKeyedArchiver archivedDataWithRootObject:unarchivedView] isEqualToData:data], @"Unarchived object not equal to archived object");
}
#endif

#if TARGET_OS_OSX
- (void)testNSView
{
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480)];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:view];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSView *unarchivedView = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([[YACYAMLKeyedArchiver archivedDataWithRootObject:unarchivedView] isEqualToData:data], @"Unarchived object not equal to archived object");
}

- (void)testNSButton
{
    NSButton *button = [NSButton buttonWithTitle:@"Tap Me" target:nil action:nil];
    button.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:button];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    NSView *unarchivedView = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([[YACYAMLKeyedArchiver archivedDataWithRootObject:unarchivedView] isEqualToData:data], @"Unarchived object not equal to archived object");
}
#endif

- (void)testCALayer
{
    CALayer *layer = [CALayer layer];
    layer.name = @"layer";
    layer.bounds = CGRectMake(0, 0, 320, 480);
    layer.position = CGPointMake(10, 20);
    layer.opacity = 0.5;
    layer.cornerRadius = 8;
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:layer];
    
    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;
    
    CALayer *unarchivedLayer = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedLayer isKindOfClass:[CALayer class]], @"Got %@", unarchivedLayer);
    XCTAssertEqualObjects(unarchivedLayer.name, @"layer");
    XCTAssertTrue(CGRectEqualToRect(unarchivedLayer.bounds, CGRectMake(0, 0, 320, 480)));
    XCTAssertTrue(CGPointEqualToPoint(unarchivedLayer.position, CGPointMake(10, 20)));
    XCTAssertEqual(unarchivedLayer.opacity, 0.5f);
    XCTAssertEqual(unarchivedLayer.cornerRadius, (CGFloat)8);
    XCTAssertTrue([[YACYAMLKeyedArchiver archivedDataWithRootObject:unarchivedLayer] isEqualToData:data], @"Unarchived object not equal to archived object");
}

- (void)testCALayerHierarchy
{
    CALayer *parent = [CALayer layer];
    parent.name = @"parent";
    for(int i = 0; i < 3; ++i) {
        CALayer *child = [CALayer layer];
        child.name = [NSString stringWithFormat:@"child %d", i];
        child.bounds = CGRectMake(0, 0, 10 * (i + 1), 10);
        [parent addSublayer:child];
    }
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:parent];
    CALayer *unarchivedParent = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertEqualObjects(unarchivedParent.name, @"parent");
    XCTAssertEqual(unarchivedParent.sublayers.count, (NSUInteger)3);
    for(NSUInteger i = 0; i < unarchivedParent.sublayers.count; ++i) {
        CALayer *child = unarchivedParent.sublayers[i];
        XCTAssertEqualObjects(child.name, ([NSString stringWithFormat:@"child %lu", (unsigned long)i]));
        XCTAssertEqual(child.bounds.size.width, (CGFloat)(10 * (i + 1)));
        XCTAssertEqual(child.superlayer, unarchivedParent, @"Sublayers should be attached to the unarchived parent");
    }
    XCTAssertTrue([[YACYAMLKeyedArchiver archivedDataWithRootObject:unarchivedParent] isEqualToData:data], @"Unarchived object not equal to archived object");
}

- (void)testCALayerSharedReference
{
    // The second occurrence is archived as an alias of the first.
    CALayer *layer = [CALayer layer];
    layer.name = @"shared";
    NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:[YACYAMLKeyedArchiver archivedDataWithRootObject:@[layer, layer]]];
    
    XCTAssertEqual(unarchived.count, (NSUInteger)2);
    XCTAssertTrue(unarchived[0] == unarchived[1], @"Both references should be the same object");
    XCTAssertEqualObjects([unarchived[0] name], @"shared");
}

- (void)testReplacingLayer
{
    YACYAMLReplacingLayer *layer = [YACYAMLReplacingLayer layer];
    layer.name = @"replaced";
    layer.bounds = CGRectMake(0, 0, 30, 40);
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:layer];
    YACYAMLReplacingLayer *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchived isKindOfClass:[YACYAMLReplacingLayer class]], @"Got %@", unarchived);
    XCTAssertEqualObjects(unarchived.name, @"replaced");
    XCTAssertTrue(CGRectEqualToRect(unarchived.bounds, CGRectMake(0, 0, 30, 40)));
}

- (void)testReplacingLayerAsSublayer
{
    // The replacement must end up in the hierarchy, not the discarded original.
    CALayer *parent = [CALayer layer];
    for(int i = 0; i < 3; ++i) {
        YACYAMLReplacingLayer *child = [YACYAMLReplacingLayer layer];
        child.name = [NSString stringWithFormat:@"child %d", i];
        [parent addSublayer:child];
    }
    
    CALayer *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:[YACYAMLKeyedArchiver archivedDataWithRootObject:parent]];
    
    XCTAssertEqual(unarchived.sublayers.count, (NSUInteger)3);
    for(NSUInteger i = 0; i < unarchived.sublayers.count; ++i) {
        CALayer *child = unarchived.sublayers[i];
        XCTAssertTrue([child isKindOfClass:[YACYAMLReplacingLayer class]]);
        XCTAssertEqualObjects(child.name, ([NSString stringWithFormat:@"child %lu", (unsigned long)i]));
        XCTAssertEqual(child.superlayer, unarchived);
    }
}

- (void)testReplacingLayerAliasedAfterReplacement
{
    // Later references to a replaced object resolve to the replacement, not the discarded original.
    YACYAMLReplacingLayer *layer = [YACYAMLReplacingLayer layer];
    layer.name = @"shared";
    NSDictionary *root = @{ @"first": layer, @"second": layer, @"third": @[layer] };
    
    NSDictionary *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:[YACYAMLKeyedArchiver archivedDataWithRootObject:root]];
    
    YACYAMLReplacingLayer *first = unarchived[@"first"];
    XCTAssertTrue([first isKindOfClass:[YACYAMLReplacingLayer class]], @"Got %@", first);
    XCTAssertEqualObjects(first.name, @"shared");
    XCTAssertTrue(unarchived[@"second"] == first, @"Aliases should resolve to the replacement object");
    XCTAssertTrue([unarchived[@"third"] firstObject] == first, @"Aliases should resolve to the replacement object");
}

- (void)testReplacingLayerCycleIsRejected
{
    // Each layer refers to the other. While one is being decoded, the other resolves its
    // anchor, and would be left holding the discarded original: this is detected.
    YACYAMLReplacingLayer *a = [YACYAMLReplacingLayer layer];
    YACYAMLReplacingLayer *b = [YACYAMLReplacingLayer layer];
    a.partner = b;
    b.partner = a;
    
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:a];
    XCTAssertThrowsSpecificNamed([YACYAMLKeyedUnarchiver unarchiveObjectWithData:data],
                                 NSException,
                                 YACYAMLAnchorReplacementException,
                                 @"Should have caught YACYAMLAnchorReplacementException");
}

- (void)testNilEncoding
{
    YACYAMLTestsNilSubobjectObject *object = [[YACYAMLTestsNilSubobjectObject alloc] init];
    NSData *data = [YACYAMLKeyedArchiver archivedDataWithRootObject:object];

    XCTAssertTrue(data.length != 0, @"Archived data unexpectely zero length");;

    YACYAMLTestsNilSubobjectObject *unarchivedObject = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data];
    
    XCTAssertTrue([unarchivedObject decodedCorrectly], @"Unarchived subobject not nil");
}

- (void)testAnchorGeneration
{
    YACYAMLKeyedArchiver *archiver = [[YACYAMLKeyedArchiver alloc] initForWritingWithMutableData:nil];
    
    XCTAssertEqualObjects(@"a", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    XCTAssertEqualObjects(@"b", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    
    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }
    
    XCTAssertEqualObjects(@"A", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    XCTAssertEqualObjects(@"B", [archiver generateAnchor], @"Anchor generation generated unexpected result");

    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }

    XCTAssertEqualObjects(@"aa", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    XCTAssertEqualObjects(@"ab", [archiver generateAnchor], @"Anchor generation generated unexpected result");

    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }
    
    XCTAssertEqualObjects(@"aA", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    XCTAssertEqualObjects(@"aB", [archiver generateAnchor], @"Anchor generation generated unexpected result");

    
    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }
    
    XCTAssertEqualObjects(@"ba", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    XCTAssertEqualObjects(@"bb", [archiver generateAnchor], @"Anchor generation generated unexpected result");

    for(int i = 0; i < 24; ++i) {
        [archiver generateAnchor];
    }
    
    XCTAssertEqualObjects(@"bA", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    XCTAssertEqualObjects(@"bB", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    
    for(int j = 0; j < 52; ++j) {
        [archiver generateAnchor];
    }
    
    XCTAssertEqualObjects(@"cC", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    XCTAssertEqualObjects(@"cD", [archiver generateAnchor], @"Anchor generation generated unexpected result");
        
    for(int i = 0; i < 52; ++i) {
        for(int j = 0; j < 52; ++j) {
            [archiver generateAnchor];
        }
    }

    XCTAssertEqualObjects(@"acE", [archiver generateAnchor], @"Anchor generation generated unexpected result");
    XCTAssertEqualObjects(@"acF", [archiver generateAnchor], @"Anchor generation generated unexpected result");
}

- (void)testAnchorGenerationBoundaries
{
    // Anchors are a bijective base-52 encoding: 52 one-letter, then 52^2 two-letter,
    // then three-letter anchors starting at index 52 + 52^2 = 2756.
    YACYAMLKeyedArchiver *archiver = [[YACYAMLKeyedArchiver alloc] initForWritingWithMutableData:nil];
    NSMutableSet *seen = [NSMutableSet set];
    NSCharacterSet *notLetters = [[NSCharacterSet letterCharacterSet] invertedSet];
    
    for(NSUInteger i = 0; i < 60000; ++i) {
        NSString *anchor = [archiver generateAnchor];
        
        if(i == 2703) {
            XCTAssertEqualObjects(anchor, @"YZ", @"Anchor at index 2703");
        } else if(i == 2755) {
            XCTAssertEqualObjects(anchor, @"ZZ", @"Last two-letter anchor");
        } else if(i == 2756) {
            XCTAssertEqualObjects(anchor, @"aaa", @"First three-letter anchor");
        }
        
        XCTAssertEqual([anchor rangeOfCharacterFromSet:notLetters].location, (NSUInteger)NSNotFound,
                       @"Anchor %lu (%@) contains a non-letter", (unsigned long)i, anchor);
        XCTAssertFalse([seen containsObject:anchor], @"Anchor %lu (%@) is a duplicate", (unsigned long)i, anchor);
        [seen addObject:anchor];
    }
}

- (void)testScalarAnchorsOption
{
    // By default, scalars that are repeated are written out in full each time, for human
    // readability.  With YACYAMLKeyedArchiverOptionAllowScalarAnchors, they're written once, with
    // an anchor, and referred to by alias after that.
    NSString *repeated = @"a fairly long string that is repeated";
    NSArray *strings = @[ repeated, repeated, repeated, @"a different string" ];
    
    NSString *archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:strings];
    XCTAssertFalse([archived containsString:@"&"], @"No anchors expected by default: %@", archived);
    XCTAssertFalse([archived containsString:@"*"], @"No aliases expected by default: %@", archived);
    
    archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:strings options:YACYAMLKeyedArchiverOptionAllowScalarAnchors];
    XCTAssertTrue([archived containsString:@"&"], @"Expected an anchor: %@", archived);
    XCTAssertEqual([[archived componentsSeparatedByString:repeated] count], (NSUInteger)2, @"The string should be written once: %@", archived);
    XCTAssertEqualObjects([YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived], strings, @"Unarchived objects not equal to archived objects");
    
    // Scalars used as dictionary keys are anchored and referred to too.
    NSArray *dictionaries = @[ @{ @"a key that is used more than once": @1 }, @{ @"a key that is used more than once": @2 } ];
    archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:dictionaries options:YACYAMLKeyedArchiverOptionAllowScalarAnchors];
    XCTAssertEqual([[archived componentsSeparatedByString:@"a key that is used more than once"] count], (NSUInteger)2, @"The key should be written once: %@", archived);
    XCTAssertEqualObjects([YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived], dictionaries);
}

- (void)testScalarAnchorsOnlyWhenSmaller
{
    // With YACYAMLKeyedArchiverOptionAllowScalarAnchors, a repeated scalar is only given an anchor
    // when that makes the output smaller.  Written out in full each time, n uses of a scalar of
    // length l take n * l characters.  With an anchor, the first use is "&a " (the anchor name
    // is one character here) plus the scalar, and the rest are "*a": (1 + 2 + l) + (n - 1) * (1 + 1).
    // Each case is a scalar, how many times it's used, and whether that's enough for an anchor.
    NSArray *cases = @[
        // One character is never worth it, however many times it's used.
        @[ @"x",         @2,   @NO ],
        @[ @"x",         @100, @NO ],
        // Three characters: 3n against 2n + 4, so it takes five uses.
        @[ @"abc",       @4,   @NO ],
        @[ @"abc",       @5,   @YES ],
        // Two uses: 5 characters is a tie (10 against 10), 6 is the first that wins (12 against 11).
        @[ @"abcde",     @2,   @NO ],
        @[ @"abcdef",    @2,   @YES ],
        // Longer strings are worth it from the second use.
        @[ @"a fairly long string that is repeated", @2, @YES ],
        @[ @"a fairly long string that is repeated", @3, @YES ],
        // As are numbers and booleans, by the same rule (and the length of what's written).
        @[ @1000000,     @3,   @YES ],
        @[ @1,           @50,  @NO ],
        @[ @YES,         @2,   @NO ],
        @[ @YES,         @3,   @YES ],
    ];
    
    for(NSArray *testCase in cases) {
        id value = testCase[0];
        NSUInteger count = [testCase[1] unsignedIntegerValue];
        BOOL expectAnchor = [testCase[2] boolValue];
        
        NSMutableArray *values = [NSMutableArray array];
        for(NSUInteger i = 0; i < count; ++i) {
            [values addObject:value];
        }
        
        NSString *archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:values options:YACYAMLKeyedArchiverOptionAllowScalarAnchors];
        XCTAssertEqual([archived containsString:@"&"], expectAnchor, @"%@ used %lu times %@ have an anchor:\n%@", value, (unsigned long)count, expectAnchor ? @"should" : @"should not", archived);
        XCTAssertEqual([archived containsString:@"*"], expectAnchor, @"%@ used %lu times %@ be referred to:\n%@", value, (unsigned long)count, expectAnchor ? @"should" : @"shouldn't", archived);
        XCTAssertEqualObjects([YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived], values, @"Unarchived objects not equal to archived objects");
        
        // The anchor is never used if it doesn't save space.
        NSString *plain = [YACYAMLKeyedArchiver archivedStringWithRootObject:values];
        XCTAssertLessThanOrEqual(archived.length, plain.length, @"%@ used %lu times is longer with anchors", value, (unsigned long)count);
    }
    
    // Objects that aren't scalars always get an anchor when they're used more than once,
    // however small, because that's how cycles are encoded.
    NSArray *shared = @[ @1 ];
    NSString *archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:@[ shared, shared ] options:YACYAMLKeyedArchiverOptionAllowScalarAnchors];
    XCTAssertTrue([archived containsString:@"&"], @"A shared collection should have an anchor:\n%@", archived);
    XCTAssertTrue([archived containsString:@"*"], @"A shared collection should be referred to:\n%@", archived);
}

- (void)testScalarAnchorsKeepTypes
{
    // NSNumbers of different kinds compare as equal with isEqual: (@1, @1.0 and @YES all do), but are
    // written differently, and are different when read back.  Using an anchor for one must not make
    // another of them the same type.
    NSArray *numbers = @[ @1, @1.0, @YES, @1, @1.0, @YES, @0, @0.0, @NO ];
    NSString *archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:numbers options:YACYAMLKeyedArchiverOptionAllowScalarAnchors];
    NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived];
    
    XCTAssertEqual(unarchived.count, numbers.count, @"%@", archived);
    for(NSUInteger i = 0; i < MIN(unarchived.count, numbers.count); ++i) {
        NSNumber *original = numbers[i];
        NSNumber *value = unarchived[i];
        XCTAssertEqualObjects(value, original, @"Wrong value at %lu in %@", (unsigned long)i, archived);
        // The kind of number: a boolean, an integer (which is always read back as a long long, whatever
        // size it started as) or a floating point number.
        BOOL originalIsBoolean = CFGetTypeID((__bridge CFTypeRef)original) == CFBooleanGetTypeID();
        BOOL valueIsBoolean = CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
        XCTAssertEqual(valueIsBoolean, originalIsBoolean, @"Wrong boolean-ness at %lu in %@", (unsigned long)i, archived);
        if(!originalIsBoolean) {
            BOOL originalIsFloat = strchr("df", original.objCType[0]) != NULL;
            BOOL valueIsFloat = strchr("df", value.objCType[0]) != NULL;
            XCTAssertEqual(valueIsFloat, originalIsFloat, @"Wrong kind of number at %lu in %@", (unsigned long)i, archived);
        }
    }
    
    // Equal numbers of the same kind are still shared.
    NSArray *same = @[ @1000000, @1000000, @1000000 ];
    archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:same options:YACYAMLKeyedArchiverOptionAllowScalarAnchors];
    XCTAssertTrue([archived containsString:@"*"], @"Expected an alias: %@", archived);
    XCTAssertEqualObjects([YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived], same);
}

- (void)testPositiveIntegerParsing
{
    NSString *integersYAML = 
        @"canonical: 685230\n"
        @"decimal: 685_230\n"
        @"octal: 02472256\n"
        @"hexadecimal: 0x_0A_74_AE\n"
        @"binary: 0b1010_0111_0100_1010_1110\n"
        @"sexagesimal: 190:20:30\n"
        @"canonicalPlus: +685230\n"
        @"decimalPlus: +685_230\n"
        @"octalPlus: +02472256\n"
        @"hexadecimalPlus: +0x_0A_74_AE\n"
        @"binaryPlus: +0b1010_0111_0100_1010_1110\n"
        @"sexagesimalPlus: +190:20:30\n";
    
    NSArray *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:integersYAML];
    
    for(NSNumber *number in [unarchivedDictionary objectEnumerator]) {
        XCTAssertEqual(((NSInteger)685230), [number integerValue], @"Unarchived object not equal to archived object");
    }
}

- (void)testNegativeIntegerParsing
{
    NSString *integersYAML = 
        @"canonical: -685230\n"
        @"decimal: -685_230\n"
        @"octal: -02472256\n"
        @"hexadecimal: -0x_0A_74_AE\n"
        @"binary: -0b1010_0111_0100_1010_1110\n"
        @"sexagesimal: -190:20:30\n";
    
    NSDictionary *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:integersYAML];
    
    for(NSNumber *number in [unarchivedDictionary objectEnumerator]) {
        XCTAssertEqual(((NSInteger)-685230), [number integerValue], @"Unarchived object not equal to archived object");
    }
}

- (void)testPositiveFloatParsing
{
    NSString *floatsYAML = 
        @"canonical: 6.8523015e+5"
        @"exponentioal: 685.230_15e+03"
        @"fixed: 685_230.15"
        @"sexagesimal: 190:20:30.15";

    NSDictionary *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:floatsYAML];
    
    for(NSNumber *number in [unarchivedDictionary objectEnumerator]) {
        XCTAssertEqual(685230.15, [number doubleValue], @"Unarchived object not equal to archived object");
    }
}

- (void)testNegativePositiveFloatParsing
{
    NSString *floatsYAML = 
        @"canonical: -6.8523015e+5"
        @"exponentioal: -685.230_15e+03"
        @"fixed: -685_230.15"
        @"sexagesimal: -190:20:30.15";
    
    NSDictionary *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:floatsYAML];
    
    for(NSNumber *number in [unarchivedDictionary objectEnumerator]) {
        XCTAssertEqual(-685230.15, [number doubleValue], @"Unarchived object not equal to archived object");
    }
}

- (void)testSpecialFloatParsing
{
    NSString *floatsYAML = 
        @"infinity: .INF\n"
        @"positive infinity: +.INF\n"
        @"negative infinity: -.inf\n"
        @"not a number: .NaN\n";
    
    NSDictionary *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:floatsYAML];

    XCTAssertTrue(isinf([[unarchivedDictionary objectForKey:@"infinity"] doubleValue]), @"Unarchived object not equal to archived object");
    XCTAssertTrue([[unarchivedDictionary objectForKey:@"infinity"] doubleValue] > 0, @"Unarchived object not equal to archived object");
    XCTAssertFalse([[unarchivedDictionary objectForKey:@"infinity"] doubleValue] < 0, @"Unarchived object not equal to archived object");
    
    XCTAssertTrue(isinf([[unarchivedDictionary objectForKey:@"positive infinity"] doubleValue]), @"Unarchived object not equal to archived object");
    XCTAssertTrue([[unarchivedDictionary objectForKey:@"positive infinity"] doubleValue] > 0, @"Unarchived object not equal to archived object");
    XCTAssertFalse([[unarchivedDictionary objectForKey:@"positive infinity"] doubleValue] < 0, @"Unarchived object not equal to archived object");

    XCTAssertTrue(isinf([[unarchivedDictionary objectForKey:@"negative infinity"] doubleValue]), @"Unarchived object not equal to archived object");
    XCTAssertTrue([[unarchivedDictionary objectForKey:@"negative infinity"] doubleValue] < 0, @"Unarchived object not equal to archived object");
    XCTAssertFalse([[unarchivedDictionary objectForKey:@"negative infinity"] doubleValue] > 0, @"Unarchived object not equal to archived object");

    XCTAssertTrue(isnan([[unarchivedDictionary objectForKey:@"not a number"] doubleValue]), @"Unarchived object not equal to archived object");
}

- (void)testBooleanParsing
{
    // The YAML 1.1 boolean forms, in each of the three cases that YAML allows.
    NSArray *trueForms = @[ @"true", @"True", @"TRUE", @"yes", @"Yes", @"YES", @"y", @"Y", @"on", @"On", @"ON" ];
    NSArray *falseForms = @[ @"false", @"False", @"FALSE", @"no", @"No", @"NO", @"n", @"N", @"off", @"Off", @"OFF" ];
    
    for(NSString *form in trueForms) {
        id value = [self unarchivedScalar:form];
        XCTAssertTrue(value != nil && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID(), @"%@ should be a boolean, got %@", form, value);
        XCTAssertEqualObjects(value, @YES, @"%@ should be true", form);
    }
    for(NSString *form in falseForms) {
        id value = [self unarchivedScalar:form];
        XCTAssertTrue(value != nil && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID(), @"%@ should be a boolean, got %@", form, value);
        XCTAssertEqualObjects(value, @NO, @"%@ should be false", form);
    }
    
    // Other capitalisations, and near misses, are strings.
    for(NSString *form in @[ @"tRue", @"TRUe", @"fAlse", @"FALSe", @"yEs", @"nO", @"oN", @"oFF", @"truee", @"fals", @"ye", @"t", @"f", @"o", @"yes please" ]) {
        XCTAssertEqualObjects([self unarchivedScalar:form], form, @"%@ should be a string", form);
    }
    
    // Quoting, or an explicit string tag, makes them strings.
    XCTAssertEqualObjects([self unarchivedScalar:@"\"False\""], @"False");
    XCTAssertEqualObjects([self unarchivedScalar:@"'yes'"], @"yes");
    XCTAssertEqualObjects([self unarchivedScalar:@"!!str true"], @"true");
}

- (void)testBooleanLookingStringsRoundTrip
{
    // Strings that would be read back as booleans must be archived in a way that keeps them strings.
    // This is what keeps 'False' a string for other YAML parsers too, not just for this one.
    NSArray *strings = @[ @"true", @"True", @"TRUE", @"false", @"False", @"FALSE", @"yes", @"No", @"y", @"N", @"on", @"Off",
                          @"tRue", @"fAlse", @"yes please" ];
    
    NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:strings]];
    XCTAssertEqualObjects(unarchived, strings);
    
    for(NSString *string in @[ @"True", @"False", @"FALSE" ]) {
        NSString *archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:@[string]];
        XCTAssertTrue([archived hasPrefix:@"- '"], @"%@ should be quoted when archived, got: %@", string, archived);
    }
    
    // And real booleans are archived as booleans.
    NSArray *booleans = @[ @YES, @NO ];
    XCTAssertEqualObjects([YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:booleans]], booleans);
}

- (void)testFloatParsingForms
{
    // Each form is checked against its own expected value.  Each must be decoded as a float.
    NSArray *cases = @[
        @[ @"1.5",                  @1.5 ],
        @[ @"-1.5",                 @-1.5 ],
        @[ @"+1.5",                 @1.5 ],
        @[ @"1.",                   @1 ],
        @[ @"5.",                   @5 ],
        @[ @".5",                   @0.5 ],
        @[ @"+.5",                  @0.5 ],
        @[ @"-.5",                  @-0.5 ],
        @[ @"0.0",                  @0 ],
        @[ @"6.8523015e+5",         @685230.15 ],
        @[ @"685_230.15",           @685230.15 ],
        @[ @"1.5E-3",               @0.0015 ],
        @[ @"1.e+3",                @1000 ],
        @[ @"190:20:30.15",         @685230.15 ],
        @[ @"-190:20:30.15",        @-685230.15 ],
    ];
    
    for(NSArray *testCase in cases) {
        id value = [self unarchivedScalar:testCase[0]];
        XCTAssertTrue([value isKindOfClass:[NSNumber class]], @"%@ should be a number, got %@", testCase[0], value);
        XCTAssertEqualWithAccuracy([value doubleValue], [testCase[1] doubleValue], 0.0000005, @"Wrong value for %@", testCase[0]);
        XCTAssertEqual(strcmp([value objCType], "d"), 0, @"%@ should be a double, got type %s", testCase[0], [value objCType]);
    }
}

- (void)testMalformedFloatsAreStrings
{
    // These look a little like floats, but aren't.
    for(NSString *string in @[ @"1.5e", @"1.5e+", @"e+3", @"1,5", @"1.5f" ]) {
        id value = [self unarchivedScalar:string];
        XCTAssertEqualObjects(value, string, @"%@ should be a string, got %@", string, value);
    }
    
    // Strings that look like floats are archived in a way that keeps them strings, including ones
    // (like version numbers) that the YAML 1.1 float expression accepts but that aren't floats.
    NSArray *strings = @[ @".", @"1.2.3", @"10.0.0.1", @"1..2" ];
    XCTAssertEqualObjects([YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:strings]], strings);
}

- (void)testHexadecimalAndBinaryIntegerParsing
{
    // 'b' is both the marker in a binary number (0b101) and a hexadecimal digit, which must not
    // confuse the two: hexadecimal numbers with a 'b' in them used to be decoded as 0.
    NSArray *cases = @[
        @[ @"0x1b",            @27 ],
        @[ @"0xb",             @11 ],
        @[ @"0xab",            @171 ],
        @[ @"0xAB",            @171 ],
        @[ @"0xbeef",          @48879 ],
        @[ @"-0xbeef",         @-48879 ],
        @[ @"+0xbeef",         @48879 ],
        @[ @"0xdeadbeef",      @3735928559LL ],
        @[ @"0x_0A_74_AE",     @685230 ],
        @[ @"0x_bb_bb",        @48059 ],
        @[ @"0b101",           @5 ],
        @[ @"-0b101",          @-5 ],
        @[ @"+0b101",          @5 ],
        @[ @"0b_1_0",          @2 ],
        @[ @"0b1010_0111",     @167 ],
        @[ @"0",               @0 ],
        @[ @"0777",            @511 ],
    ];
    
    for(NSArray *testCase in cases) {
        id value = [self unarchivedScalar:testCase[0]];
        XCTAssertTrue([value isKindOfClass:[NSNumber class]], @"%@ should be a number, got %@", testCase[0], value);
        XCTAssertEqual([value longLongValue], [testCase[1] longLongValue], @"Wrong value for %@", testCase[0]);
    }
}

- (void)testIntegerRangeParsing
{
    // Integers that fit in 64 bits (signed, or unsigned for large positive values) are numbers,
    // exactly.  Those that don't must not be silently clamped or wrapped.
    
    // Signed values.
    NSArray *signedCases = @[
        @[ @"9223372036854775807",    @9223372036854775807LL ],
        @[ @"-9223372036854775808",   @(LLONG_MIN) ],
        @[ @"-0x8000000000000000",    @(LLONG_MIN) ],
        @[ @"0x7FFFFFFFFFFFFFFF",     @9223372036854775807LL ],
        @[ @"-1",                     @-1 ],
    ];
    for(NSArray *testCase in signedCases) {
        id value = [self unarchivedScalar:testCase[0]];
        XCTAssertTrue([value isKindOfClass:[NSNumber class]], @"%@ should be a number, got %@", testCase[0], value);
        XCTAssertEqual([value longLongValue], [testCase[1] longLongValue], @"Wrong value for %@", testCase[0]);
    }
    
    // Positive values that need an unsigned 64 bit number.
    NSArray *unsignedCases = @[
        @"9223372036854775808",
        @"18446744073709551615",
        @"0xFFFFFFFFFFFFFFFF",
        @"0b1111111111111111111111111111111111111111111111111111111111111111",
        @"01777777777777777777777",
    ];
    for(NSString *string in unsignedCases) {
        id value = [self unarchivedScalar:string];
        XCTAssertTrue([value isKindOfClass:[NSNumber class]], @"%@ should be a number, got %@", string, value);
        XCTAssertEqual([value unsignedLongLongValue], string.length == 19 ? 9223372036854775808ULL : ULLONG_MAX, @"Wrong value for %@", string);
        XCTAssertGreaterThan([value doubleValue], 0, @"%@ should be positive", string);
    }
    
    // Too big for either.  These must not be clamped or wrapped: they are left as strings, so
    // that no information is lost.
    NSArray *tooBig = @[ @"18446744073709551616",
                         @"99999999999999999999999999",
                         @"-9223372036854775809",
                         @"-99999999999999999999999999",
                         @"123456789012345678901234567890123456789",
                         @"1234567890123456789012345678901234567890123456789012345678901234567890",
                         @"0x10000000000000000",
                         @"-0x8000000000000001",
                         @"0b10000000000000000000000000000000000000000000000000000000000000000",
                         @"02000000000000000000000",
                         @"99999999999999999999:30" ];
    for(NSString *string in tooBig) {
        id value = [self unarchivedScalar:string];
        XCTAssertEqualObjects(value, string, @"%@ doesn't fit in 64 bits, so should be left as a string, got %@", string, value);
    }
    
    // And those strings survive being archived and unarchived.
    XCTAssertEqualObjects([YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:tooBig]], tooBig);
}

- (NSString *)archivedScalarForObject:(id)object
{
    // Archive a one-element array and extract the scalar from "- <scalar>\n".
    NSString *archive = [YACYAMLKeyedArchiver archivedStringWithRootObject:@[object]];
    NSRange start = [archive rangeOfString:@"- "];
    XCTAssertNotEqual(start.location, (NSUInteger)NSNotFound, @"Unexpected archive: %@", archive);
    return [[archive substringFromIndex:NSMaxRange(start)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)testFloatingPointNumbersAreArchivedAsFloats
{
    // A floating point number that happens to have a whole value must still be written so that
    // it is read back as a float: '1' would be read as an integer.  Each pair is the number
    // and how it's written.
    NSArray *cases = @[
        @[ @1.0,                @"1.0" ],
        @[ @-1.0,               @"-1.0" ],
        @[ @0.0,                @"0.0" ],
        @[ @100000.0,           @"100000.0" ],
        @[ @123456789.0,        @"123456789.0" ],
        @[ @1e15,               @"1000000000000000.0" ],
        @[ @1e16,               @"1.0e+16" ],
        @[ @2.5e20,             @"2.5e+20" ],
        @[ @1e300,              @"1.0e+300" ],
        @[ @1e-5,               @"1.0e-05" ],
        @[ @1.5,                @"1.5" ],
        @[ @(M_PI),             @"3.141592653589793" ],
        @[ @1.5e300,            @"1.5e+300" ],
    ];
    
    for(NSArray *testCase in cases) {
        XCTAssertEqualObjects([self archivedScalarForObject:testCase[0]], testCase[1], @"Wrong archived form of %@", testCase[0]);
        
        NSNumber *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:@[testCase[0]]]][0];
        XCTAssertEqual(strcmp(unarchived.objCType, "d"), 0, @"%@ should come back as a double, not %s", testCase[0], unarchived.objCType);
        XCTAssertEqual(unarchived.doubleValue, [testCase[0] doubleValue], @"Wrong value for %@", testCase[0]);
    }
    
    // Negative zero.
    XCTAssertEqualObjects([self archivedScalarForObject:@-0.0], @"-0.0");
    NSNumber *negativeZero = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:@[ @-0.0 ]]][0];
    XCTAssertTrue(signbit(negativeZero.doubleValue), @"Negative zero should stay negative");
    
    // Floats too.
    XCTAssertEqualObjects([self archivedScalarForObject:[NSNumber numberWithFloat:1.0f]], @"1.0");
    XCTAssertEqualObjects([self archivedScalarForObject:[NSNumber numberWithFloat:0.5f]], @"0.5");
    
    // Integers, booleans, infinities and NaN are as they were.
    XCTAssertEqualObjects([self archivedScalarForObject:@1], @"1");
    XCTAssertEqualObjects([self archivedScalarForObject:@-7], @"-7");
    XCTAssertEqualObjects([self archivedScalarForObject:@(LLONG_MIN)], @"-9223372036854775808");
    XCTAssertEqualObjects([self archivedScalarForObject:@YES], @"true");
    XCTAssertEqualObjects([self archivedScalarForObject:@(INFINITY)], @".inf");
    XCTAssertEqualObjects([self archivedScalarForObject:@(-INFINITY)], @"-.inf");
    XCTAssertEqualObjects([self archivedScalarForObject:@(NAN)], @".nan");
    
    // Decimal numbers are exact, not floating point, and are written as they always were.
    XCTAssertEqualObjects([self archivedScalarForObject:[NSDecimalNumber decimalNumberWithString:@"42"]], @"42");
    XCTAssertEqualObjects([self archivedScalarForObject:[NSDecimalNumber decimalNumberWithString:@"18446744073709551616"]], @"18446744073709551616");
}

- (void)testExplicitFloatTag
{
    // A float tag makes a number a float, even if what it tags looks like an integer.
    for(NSString *string in @[ @"!!float 1", @"!!float \"1\"", @"!!float 0x01", @"!!float +1" ]) {
        NSNumber *value = [self unarchivedScalar:string];
        XCTAssertTrue([value isKindOfClass:[NSNumber class]], @"%@ should be a number, got %@", string, value);
        XCTAssertEqual(strcmp(value.objCType, "d"), 0, @"%@ should be a double, not %s", string, value.objCType);
        XCTAssertEqual(value.doubleValue, 1.0, @"Wrong value for %@", string);
    }
    XCTAssertEqual([[self unarchivedScalar:@"!!float -3"] doubleValue], -3.0);
    XCTAssertEqual(strcmp([[self unarchivedScalar:@"!!float -3"] objCType], "d"), 0);
    XCTAssertEqual([[self unarchivedScalar:@"!!float 1.5"] doubleValue], 1.5);
    XCTAssertEqual([[self unarchivedScalar:@"!!float 190:20:30"] doubleValue], 685230.0);
    
    // Without the tag, they're integers.
    XCTAssertEqual(strcmp([[self unarchivedScalar:@"1"] objCType], "q"), 0);
    XCTAssertEqual(strcmp([[self unarchivedScalar:@"!!int 1"] objCType], "q"), 0);
    
    // Other tags that don't match what they tag are not errors: the value is left as a string.
    XCTAssertEqualObjects([self unarchivedScalar:@"!!bool maybe"], @"maybe");
    XCTAssertEqualObjects([self unarchivedScalar:@"!!int abc"], @"abc");
    XCTAssertEqualObjects([self unarchivedScalar:@"!!str 123"], @"123");
}

- (void)testBinaryParsing
{
    NSString *binaryYAML =
        @"canonical: !!binary \"\\\n"
        @" R0lGODlhDAAMAIQAAP//9/X17unp5WZmZgAAAOfn515eXvPz7Y6OjuDg4J+fn5\\\n"
        @" OTk6enp56enmlpaWNjY6Ojo4SEhP/++f/++f/++f/++f/++f/++f/++f/++f/+\\\n"
        @" +f/++f/++f/++f/++f/++SH+Dk1hZGUgd2l0aCBHSU1QACwAAAAADAAMAAAFLC\\\n"
        @" AgjoEwnuNAFOhpEMTRiggcz4BNJHrv/zCFcLiwMWYNG84BwwEeECcgggoBADs=\"\n"
        @"generic: !!binary |\n"
        @" R0lGODlhDAAMAIQAAP//9/X17unp5WZmZgAAAOfn515eXvPz7Y6OjuDg4J+fn5\n"
        @" OTk6enp56enmlpaWNjY6Ojo4SEhP/++f/++f/++f/++f/++f/++f/++f/++f/+\n"
        @" +f/++f/++f/++f/++f/++SH+Dk1hZGUgd2l0aCBHSU1QACwAAAAADAAMAAAFLC\n"
        @" AgjoEwnuNAFOhpEMTRiggcz4BNJHrv/zCFcLiwMWYNG84BwwEeECcgggoBADs=\n"
        @"description:\n"
        @" The binary value above is a tiny arrow encoded as a gif image.\n";

    NSDictionary *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:binaryYAML];

    XCTAssertTrue([[unarchivedDictionary objectForKey:@"canonical"] isEqual:[unarchivedDictionary objectForKey:@"generic"]], @"Unarchived object not equal to archived object");

    // Cross-platform image validation using ImageIO (available on both macOS and iOS)
    NSData *canonicalData = [unarchivedDictionary objectForKey:@"canonical"];
    NSData *genericData = [unarchivedDictionary objectForKey:@"generic"];

    CGImageSourceRef canonicalSource = CGImageSourceCreateWithData((__bridge CFDataRef)canonicalData, NULL);
    CGImageSourceRef genericSource = CGImageSourceCreateWithData((__bridge CFDataRef)genericData, NULL);

    XCTAssertNotNil((__bridge id)canonicalSource, @"Failed to create image source from canonical data");
    XCTAssertNotNil((__bridge id)genericSource, @"Failed to create image source from generic data");

    CGImageRef canonicalImage = CGImageSourceCreateImageAtIndex(canonicalSource, 0, NULL);
    CGImageRef genericImage = CGImageSourceCreateImageAtIndex(genericSource, 0, NULL);

    XCTAssertNotNil((__bridge id)canonicalImage, @"Failed to create image from canonical data");
    XCTAssertNotNil((__bridge id)genericImage, @"Failed to create image from generic data");

    if(canonicalImage) CFRelease(canonicalImage);
    if(genericImage) CFRelease(genericImage);
    if(canonicalSource) CFRelease(canonicalSource);
    if(genericSource) CFRelease(genericSource);
}

- (void)testNullParsing
{
    NSString *yaml = 
        @"empty:\n"
        @"canonical: ~\n"
        @"english: null\n"
        @"~: null key\n";

    NSDictionary *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml];
    
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"empty"], @"Unarchived object not equal to archived object");
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"canonical"], @"Unarchived object not equal to archived object");
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"english"], @"Unarchived object not equal to archived object");
    XCTAssertEqualObjects(@"null key", [unarchivedDictionary objectForKey:[NSNull null]], @"Unarchived object not equal to archived object");
}


- (void)testDateParsing
{
    NSString *yaml = 
    @"canonical:           2001-12-15T02:59:43.1Z\n"
    @"valid iso8601:       2001-12-14t21:59:43.10-05:00\n"
    @"space separated:     2001-12-14 21:59:43.10 -5\n"
    @"no time zone (Z):    2001-12-15 2:59:43.10\n"
    @"half hour time zone: 2001-12-15 3:29:43.10+00:30\n"
    @"date (00:00:00Z):    2002-12-14";
    
    NSDictionary *unarchivedDictionary = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml];
    
    for(NSNumber *number in [[[unarchivedDictionary objectEnumerator] allObjects] valueForKey:@"timeIntervalSince1970"]) {
        XCTAssertTrue(number.doubleValue == 1008385183.1 || // 2001-12-15 2:59:43.10
                      number.doubleValue == 1039824000,     // 2002-12-14
                      @"Unarchived object not equal to archived object");
    }
}   

- (void)testDateArchiving
{
    NSArray *testArray = [NSArray arrayWithObjects:[NSDate dateWithTimeIntervalSince1970:1039824000],
                                                   [NSDate dateWithTimeIntervalSince1970:1008385183.1],
                                                   [NSDate dateWithTimeIntervalSince1970:1008385323.01],
                                                    nil];
    
    NSString *string = [YACYAMLKeyedArchiver archivedStringWithRootObject:testArray];
    
    XCTAssertTrue(string.length != 0, @"Zero-length archive string");
    
    NSArray *unarchivedArray = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:string];
    
    for(NSNumber *number in [unarchivedArray  valueForKey:@"timeIntervalSince1970"]) {
        XCTAssertTrue(number.doubleValue == 1039824000 ||
                      number.doubleValue == 1008385183.1 ||
                      number.doubleValue == 1008385323.01,
                      @"Unarchived object not equal to archived object");
    }
}


- (NSString *)archivedScalarForDate:(NSDate *)date
{
    // Archive a one-element array and extract the timestamp scalar from "- <scalar>\n".
    NSString *archive = [YACYAMLKeyedArchiver archivedStringWithRootObject:@[date]];
    NSRange start = [archive rangeOfString:@"- "];
    XCTAssertNotEqual(start.location, (NSUInteger)NSNotFound, @"Unexpected archive: %@", archive);
    return [[archive substringFromIndex:NSMaxRange(start)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)testDateArchivingMilliseconds
{
    // Fractions are zero-padded to three digits.
    XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSince1970:1008385323.01]],
                          @"2001-12-15T03:02:03.010Z");
    // Dates before the reference date (2001-01-01) have negative reference intervals.
    XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:-0.5]],
                          @"2000-12-31T23:59:59.500Z");
    XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:-0.05]],
                          @"2000-12-31T23:59:59.950Z");
    // Fractions beyond milliseconds are rounded, not truncated.
    XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:100.1236]],
                          @"2001-01-01T00:01:40.124Z");
    XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:100.9994]],
                          @"2001-01-01T00:01:40.999Z");
    // A fraction that rounds up to 1000ms must carry into the seconds.
    XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:10.9996]],
                          @"2001-01-01T00:00:11Z");
    XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:-10.0004]],
                          @"2000-12-31T23:59:50Z");
}


- (void)testDateMillisecondRoundTrip
{
    NSArray *intervals = @[@(-0.5), @(-0.05), @(-10.0004), @(10.9996), @(30077983.1), @(-86400.001)];
    for(NSNumber *interval in intervals) {
        // Dates are archived to millisecond precision.
        NSTimeInterval expected = round(interval.doubleValue * 1000.0) / 1000.0;
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:interval.doubleValue];
        NSString *archive = [YACYAMLKeyedArchiver archivedStringWithRootObject:@[date]];
        NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:archive];
        XCTAssertEqual(unarchived.count, (NSUInteger)1, @"%@", archive);
        XCTAssertEqualWithAccuracy([unarchived[0] timeIntervalSinceReferenceDate], expected, 0.0005, @"Round trip of %@ via %@", interval, archive);
    }
}

- (void)testDateNegativeTimeZoneWithMinutes
{
    // 2001-12-15T02:59:43Z expressed in other zones.
    NSDate *expected = [NSDate dateWithTimeIntervalSince1970:1008385183];
    for(NSString *string in @[@"2001-12-14T21:29:43-05:30",
                              @"2001-12-15T03:29:43+00:30",
                              @"2001-12-15T02:59:43-00:00"]) {
        NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[NSString stringWithFormat:@"- %@\n", string]];
        XCTAssertEqualObjects(unarchived.firstObject, expected, @"%@", string);
    }
}

- (id)unarchivedScalar:(NSString *)scalar
{
    // Unarchive a one-element sequence "- <scalar>\n" and return its element.
    NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[NSString stringWithFormat:@"- %@\n", scalar]];
    XCTAssertEqual(unarchived.count, (NSUInteger)1, @"Unexpected result for %@: %@", scalar, unarchived);
    return unarchived.firstObject;
}

- (void)testDateParsingForms
{
    // Each form is checked against its own expected time (seconds since 1970).
    NSDictionary *expectations = @{
        // Canonical, ISO 8601, space separated, and no time zone (UTC) forms.
        @"2001-12-15T02:59:43.1Z":            @1008385183.1,
        @"2001-12-14t21:59:43.10-05:00":      @1008385183.1,
        @"2001-12-14 21:59:43.10 -5":         @1008385183.1,
        @"2001-12-15 2:59:43.10":             @1008385183.1,
        @"2001-12-15 3:29:43.10+00:30":       @1008385183.1,
        // Date only (midnight UTC).
        @"2002-12-14":                        @1039824000,
        @"1970-01-01":                        @0,
        @"1900-01-01":                        @-2208988800,
        // Single digit month, day and hour.
        @"2001-1-2T3:04:05Z":                 @978404645,
        // Fractions.
        @"2001-12-15T02:59:43Z":              @1008385183,
        @"2001-12-15T02:59:43.Z":             @1008385183,
        @"2001-12-15T02:59:43.123456Z":       @1008385183.123456,
        // Leap day and range extremes.
        @"2000-02-29T12:34:56Z":              @951827696,
        @"9999-12-31T23:59:59Z":              @253402300799,
        // Time zone forms.
        @"2001-12-15T02:59:43+00:00":         @1008385183,
        @"2001-12-15T05:59:43+3":             @1008385183,
        @"2001-12-14T21:59:43-05":            @1008385183,
        @"2001-12-15T08:29:43+05:30":         @1008385183,
        @"2001-12-14T22:29:43-04:30":         @1008385183,
        @"2001-12-15T02:59:43 Z":             @1008385183,
        @"2001-12-15T02:59:43\t+0":           @1008385183,
        @"2001-12-15T02:59:43-00:30":         @1008386983,
        // Offsets that cross a day, month or year boundary.
        @"2001-12-31T23:59:59-01:00":         @1009846799,
        @"2000-02-29T23:30:00-01:00":         @951870600,
    };
    
    [expectations enumerateKeysAndObjectsUsingBlock:^(NSString *string, NSNumber *expected, BOOL *stop) {
        id date = [self unarchivedScalar:string];
        XCTAssertTrue([date isKindOfClass:[NSDate class]], @"%@ should parse as a date, got %@", string, date);
        XCTAssertEqualWithAccuracy([date timeIntervalSince1970], expected.doubleValue, 0.0000005,
                                   @"Wrong time parsed from %@", string);
    }];
}

- (void)testNonDatesAreNotParsedAsDates
{
    for(NSString *string in @[@"2001-12", @"12:30:00", @"2001/12/14", @"20011214", @"not-a-date", @"2001-12-14-3"]) {
        id value = [self unarchivedScalar:string];
        XCTAssertFalse([value isKindOfClass:[NSDate class]], @"%@ should not parse as a date", string);
    }
}

- (void)testDateLikeStringsRoundTripAsStrings
{
    NSArray *strings = @[@"2001-12-14", @"2001-12-15T02:59:43Z", @"2001-12-14 21:59:43.10 -5"];
    NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:strings]];
    XCTAssertEqualObjects(unarchived, strings, @"Strings that look like dates should stay strings");
}

- (void)testDateArchivingExactStrings
{
    NSDictionary *expectations = @{
        // Midnight UTC is written as a plain date.
        @0:                @"1970-01-01",
        @1039824000:       @"2002-12-14",
        @-2208988800:      @"1900-01-01",
        // Otherwise a full UTC timestamp.
        @951827696:        @"2000-02-29T12:34:56Z",
        @946684799:        @"1999-12-31T23:59:59Z",
        @253402300799:     @"9999-12-31T23:59:59Z",
        @-14182940:        @"1969-07-20T20:17:40Z",
        @2147483648:       @"2038-01-19T03:14:08Z",
        // Fractions, zero padded to three digits.
        @1008385183.1:     @"2001-12-15T02:59:43.100Z",
        @1008385183.001:   @"2001-12-15T02:59:43.001Z",
        @1008385183.999:   @"2001-12-15T02:59:43.999Z",
        @-14182940.25:     @"1969-07-20T20:17:39.750Z",
    };
    
    [expectations enumerateKeysAndObjectsUsingBlock:^(NSNumber *interval, NSString *expected, BOOL *stop) {
        XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSince1970:interval.doubleValue]],
                              expected, @"Wrong archived form of %@", interval);
    }];
}

- (void)testDateArchivingMidnightWithFraction
{
    // A date at midnight UTC that has a fraction of a second must not be written as a plain date.
    XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSince1970:1039824000.5]],
                          @"2002-12-14T00:00:00.500Z");
    XCTAssertEqualObjects([self archivedScalarForDate:[NSDate dateWithTimeIntervalSince1970:-0.001]],
                          @"1969-12-31T23:59:59.999Z");
}

- (void)testDateArchivingFractionBoundaries
{
    // Reference-date based, so that expected fractions are exact in binary where possible.
    // Each pair: seconds since 2001-01-01T00:00:00Z, expected archived form.
    NSArray *cases = @[
        // Smallest and largest millisecond fractions.
        @[@0.001,     @"2001-01-01T00:00:00.001Z"],
        @[@0.999,     @"2001-01-01T00:00:00.999Z"],
        // Fractions that need padding.
        @[@0.01,      @"2001-01-01T00:00:00.010Z"],
        @[@0.1,       @"2001-01-01T00:00:00.100Z"],
        @[@0.5,       @"2001-01-01T00:00:00.500Z"],
        // Sub-millisecond values round to the nearest millisecond.
        @[@0.0004,    @"2001-01-01"],
        @[@0.0006,    @"2001-01-01T00:00:00.001Z"],
        @[@0.9994,    @"2001-01-01T00:00:00.999Z"],
        @[@0.9996,    @"2001-01-01T00:00:01Z"],
        // Rounding up carries through minute, hour, day and month boundaries. A carry that
        // lands exactly on midnight gives a plain date.
        @[@59.9996,   @"2001-01-01T00:01:00Z"],
        @[@3599.9996, @"2001-01-01T01:00:00Z"],
        @[@86399.9996, @"2001-01-02"],
        @[@2678399.9996, @"2001-02-01"],
        // Fractions just before the midnight, which is written as a plain date.
        @[@86399.999, @"2001-01-01T23:59:59.999Z"],
        @[@86400.001, @"2001-01-02T00:00:00.001Z"],
        // Negative reference intervals (before 2001-01-01).
        @[@-0.001,    @"2000-12-31T23:59:59.999Z"],
        @[@-0.999,    @"2000-12-31T23:59:59.001Z"],
        @[@-0.0004,   @"2001-01-01"],
        @[@-0.0006,   @"2000-12-31T23:59:59.999Z"],
        @[@-0.9996,   @"2000-12-31T23:59:59Z"],
        @[@-86399.9996, @"2000-12-31"],
        @[@-31622399.9996, @"2000-01-01"],
        // Midnight with a fraction is not a plain date.
        @[@86400.5,   @"2001-01-02T00:00:00.500Z"],
        @[@-86399.5,  @"2000-12-31T00:00:00.500Z"],
    ];
    
    for(NSArray *testCase in cases) {
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:[testCase[0] doubleValue]];
        XCTAssertEqualObjects([self archivedScalarForDate:date], testCase[1],
                              @"Wrong archived form of reference interval %@", testCase[0]);
    }
}

- (void)testDateFractionParsing
{
    // Fractions of any length. Each pair: scalar, expected seconds since 2001-12-15T02:59:43Z.
    NSArray *cases = @[
        @[@"2001-12-15T02:59:43.1Z",          @0.1],
        @[@"2001-12-15T02:59:43.10Z",         @0.1],
        @[@"2001-12-15T02:59:43.100Z",        @0.1],
        @[@"2001-12-15T02:59:43.001Z",        @0.001],
        @[@"2001-12-15T02:59:43.999Z",        @0.999],
        @[@"2001-12-15T02:59:43.0Z",          @0],
        @[@"2001-12-15T02:59:43.000Z",        @0],
        @[@"2001-12-15T02:59:43.5",           @0.5],
        @[@"2001-12-15T02:59:43.5+00:00",     @0.5],
        @[@"2001-12-15 02:59:43.25 Z",        @0.25],
        @[@"2001-12-15T02:59:43.0000001Z",    @0.0000001],
        @[@"2001-12-15T02:59:43.123456789Z",  @0.123456789],
        @[@"2001-12-14T21:59:43.5-05:00",     @0.5],
        @[@"2001-12-15T08:29:43.5+05:30",     @0.5],
        // A fraction does not alter the whole-second part, or leak into the next unit.
        @[@"2001-12-15T02:59:44.999Z",        @1.999],
        @[@"2001-12-15T02:59:42.999Z",        @-0.001],
    ];
    
    NSDate *base = [NSDate dateWithTimeIntervalSince1970:1008385183];
    for(NSArray *testCase in cases) {
        id date = [self unarchivedScalar:testCase[0]];
        XCTAssertTrue([date isKindOfClass:[NSDate class]], @"%@ should parse as a date, got %@", testCase[0], date);
        XCTAssertEqualWithAccuracy([date timeIntervalSinceDate:base], [testCase[1] doubleValue], 0.0000005,
                                   @"Wrong fraction parsed from %@", testCase[0]);
    }
}

- (void)testDateFractionRoundTripAtEveryMillisecond
{
    // All 1000 millisecond fractions, in a second of a pre-2001 date, a 2001 date, and a midnight.
    NSArray *baseIntervals = @[@-86400, @978307200, @1039824000, @-2208988800];
    for(NSNumber *base in baseIntervals) {
        NSMutableArray *dates = [NSMutableArray array];
        for(int ms = 0; ms < 1000; ++ms) {
            [dates addObject:[NSDate dateWithTimeIntervalSince1970:base.doubleValue + ms / 1000.0]];
        }
        
        NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:dates]];
        XCTAssertEqual(unarchived.count, dates.count, @"Base %@", base);
        
        for(NSUInteger ms = 0; ms < MIN(unarchived.count, dates.count); ++ms) {
            XCTAssertEqualWithAccuracy([unarchived[ms] timeIntervalSince1970], base.doubleValue + ms / 1000.0, 0.0005,
                                       @"Round trip failed for base %@ plus %lu ms", base, (unsigned long)ms);
        }
    }
}

- (void)testDateRoundTripBroad
{
    // A deterministic spread of dates, roughly 1906 to 2096, at millisecond precision.
    NSMutableArray *dates = [NSMutableArray array];
    NSMutableArray *intervals = [NSMutableArray array];
    uint64_t state = 0x2545F4914F6CDD1DULL;
    for(int i = 0; i < 2000; ++i) {
        state = state * 6364136223846793005ULL + 1442695040888963407ULL;
        double fraction = (double)(state >> 11) / (double)(1ULL << 53);
        NSTimeInterval interval = round((fraction * 6.0e9 - 3.0e9) * 1000.0) / 1000.0;
        [intervals addObject:@(interval)];
        [dates addObject:[NSDate dateWithTimeIntervalSinceReferenceDate:interval]];
    }
    
    NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:dates]];
    XCTAssertEqual(unarchived.count, dates.count);
    
    for(NSUInteger i = 0; i < MIN(unarchived.count, dates.count); ++i) {
        XCTAssertEqualWithAccuracy([unarchived[i] timeIntervalSinceReferenceDate], [intervals[i] doubleValue], 0.0005,
                                   @"Round trip failed for reference interval %@", intervals[i]);
    }
}

- (void)testDateRoundTripInContainers
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1008385183.1];
    NSDate *midnight = [NSDate dateWithTimeIntervalSince1970:1039824000];
    NSDictionary *root = @{ @"single": date,
                            @"midnight": midnight,
                            @"nested": @{ @"array": @[date, midnight] },
                            date: @"date as a key" };
    
    NSDictionary *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:root]];
    
    XCTAssertEqualWithAccuracy([unarchived[@"single"] timeIntervalSince1970], 1008385183.1, 0.0005);
    XCTAssertEqualWithAccuracy([unarchived[@"midnight"] timeIntervalSince1970], 1039824000, 0.0005);
    NSArray *nested = unarchived[@"nested"][@"array"];
    XCTAssertEqual(nested.count, (NSUInteger)2);
    XCTAssertEqualWithAccuracy([nested[0] timeIntervalSince1970], 1008385183.1, 0.0005);
    XCTAssertEqualWithAccuracy([nested[1] timeIntervalSince1970], 1039824000, 0.0005);
    
    NSDate *keyDate = nil;
    for(id key in unarchived) {
        if([key isKindOfClass:[NSDate class]]) {
            keyDate = key;
        }
    }
    XCTAssertNotNil(keyDate, @"A date used as a dictionary key should be unarchived as a date");
    XCTAssertEqualObjects(unarchived[keyDate], @"date as a key");
}

- (void)testDateRoundTripAsRootObject
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1008385183.1];
    id unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:[YACYAMLKeyedArchiver archivedStringWithRootObject:date]];
    XCTAssertTrue([unarchived isKindOfClass:[NSDate class]], @"Got %@", unarchived);
    XCTAssertEqualWithAccuracy([unarchived timeIntervalSince1970], 1008385183.1, 0.0005);
}

- (void)testMergeParsing
{
    NSString *yaml = 
    @"---\n"
    @"- &CENTER { x: 1, y: 2 }\n"
    @"- &LEFT { x: 0, y: 2 }\n"
    @"- &BIG { r: 10 }\n"
    @"- &SMALL { r: 1 }\n"
    @"\n"
    @"# All the following maps are equal:\n"
    @"\n"
    @"- # Explicit keys\n"
    @"  x: 1\n"
    @"  y: 2\n"
    @"  r: 10\n"
    @"  label: center/big\n"
    @"\n"
    @"- # Merge one map\n"
    @"  << : *CENTER\n"
    @"  r: 10\n"
    @"  label: center/big\n"
    @"\n"
    @"- # Merge multiple maps\n"
    @"  << : [ *CENTER, *BIG ]\n"
    @"  label: center/big\n"
    @"\n"
    @"- # Override\n"
    @"  << : [ *BIG, *LEFT, *SMALL ]\n"
    @"  x: 1\n"
    @"  label: center/big\n";
    
    NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml];

    XCTAssertTrue(unarchived.count != 0, @"Unexpected count after merge parsing");
}

- (void)testMergingFromCustomTypes
{
    NSString *yaml =
    @"---\n"
    @"original: !YACYAMLCustomTypeMerging &CUSTOMTYPEMERGE\n"
    @"    key1: this key should be inherited\n"
    @"    key2: this key should be overridden\n"
    @"# Keys can be merged from custom types into other custom types\n"
    @"mergedCustomType: !YACYAMLCustomTypeMerging\n"
    @"    <<: *CUSTOMTYPEMERGE\n"
    @"    key2: override for key2\n"
    @"# Keys can be merged from custom types into regular maps\n"
    @"mergedMap:\n"
    @"    <<: *CUSTOMTYPEMERGE\n"
    @"    key2: override for key2\n";
    
    NSDictionary *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml];
    XCTAssertTrue(unarchived.count == 3);
    
    YACYAMLCustomTypeMerging *original = unarchived[@"original"];
    XCTAssertTrue([original isKindOfClass: [YACYAMLCustomTypeMerging class]]);
    XCTAssertEqualObjects(original.property1, @"this key should be inherited");
    XCTAssertEqualObjects(original.property2, @"this key should be overridden");
    
    YACYAMLCustomTypeMerging *mergedCustomType = unarchived[@"mergedCustomType"];
    XCTAssertTrue([mergedCustomType isKindOfClass: [YACYAMLCustomTypeMerging class]]);
    XCTAssertEqualObjects(mergedCustomType.property1, @"this key should be inherited");
    XCTAssertEqualObjects(mergedCustomType.property2, @"override for key2");
    
    NSDictionary *mergedMap = unarchived[@"mergedMap"];
    XCTAssertTrue([mergedMap isKindOfClass: [NSDictionary class]]);
    XCTAssertEqualObjects(mergedMap[@"key1"], @"this key should be inherited");
    XCTAssertEqualObjects(mergedMap[@"key2"], @"override for key2");
}

- (void)testYAMLExtensions
{
    NSString *yaml = 
    @"empty:\n"
    @"canonical: ~\n"
    @"english: null\n"
    @"~: null key\n";
    
    NSDictionary *unarchivedDictionary = [yaml YACYAMLDecode];
    
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"empty"], @"Unexpected result after unarchiving");
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"canonical"], "Unexpected result after unarchiving");
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"english"], "Unexpected result after unarchiving");
    XCTAssertEqualObjects(@"null key", [unarchivedDictionary objectForKey:[NSNull null]], "Unexpected result after unarchiving");
    
    unarchivedDictionary = [yaml YACYAMLDecodeBasic];
    
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"empty"], "Unexpected result after unarchiving");
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"canonical"], "Unexpected result after unarchiving");
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"english"], "Unexpected result after unarchiving");
    XCTAssertEqualObjects(@"null key", [unarchivedDictionary objectForKey:[NSNull null]], "Unexpected result after unarchiving");
    
    unarchivedDictionary = [yaml YACYAMLDecodeAll];
    
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"empty"], "Unexpected result after unarchiving");
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"canonical"], "Unexpected result after unarchiving");
    XCTAssertEqualObjects([NSNull null], [unarchivedDictionary objectForKey:@"english"], "Unexpected result after unarchiving");
    XCTAssertEqualObjects(@"null key", [unarchivedDictionary objectForKey:[NSNull null]], "Unexpected result after unarchiving");

}

- (void)testDisallowInitWithCoderOption
{
    // The option stops tagged classes being instantiated with initWithCoder:, so
    // YAML from an untrusted source can't make the unarchiver create arbitrary
    // objects. YACYAMLCapturingReplacingObject records the unarchiver when its
    // initWithCoder: runs, so gCapturedUnarchiver being nil afterwards shows that
    // it was never called. The YAML has a tagged mapping for it, a tagged mapping
    // for a normal object, and a tagged sequence.

    NSString *yaml =
        @"- !YACYAMLCapturingReplacingObject\n"
        @"  child: hello\n"
        @"- !YACYAMLNormalObject\n"
        @"  child: hello\n"
        @"- !YACYAMLNormalObject [one, two]\n";
    
    // By default, tags name classes, which are instantiated with initWithCoder:.
    gCapturedUnarchiver = nil;
    NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml];
    XCTAssertEqual(unarchived.count, (NSUInteger)3);
    XCTAssertNotNil(gCapturedUnarchiver, @"initWithCoder: should be called by default");
    XCTAssertTrue([unarchived[1] isKindOfClass:[YACYAMLNormalObject class]], @"Got %@", unarchived[1]);
    gCapturedUnarchiver = nil;
    
    // With the option, they are presented as plain collections, and initWithCoder: is never called.
    NSArray *expected = @[ @{ @"child": @"hello" }, @{ @"child": @"hello" }, @[ @"one", @"two" ] ];
    
    unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml options:YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder];
    XCTAssertEqualObjects(unarchived, expected);
    XCTAssertNil(gCapturedUnarchiver, @"initWithCoder: must not be called with the option set");
    
    // The same again, through the NSData entry point.  The NSString method above
    // is a wrapper around this one, so this mainly guards the NSData method
    // itself.  'data' is also used by the NSData convenience methods below.
    NSData *data = [yaml dataUsingEncoding:NSUTF8StringEncoding];
    unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:data options:YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder];
    XCTAssertEqualObjects(unarchived, expected);
    XCTAssertNil(gCapturedUnarchiver);
    
    // The NSString and NSData convenience methods set the option, except for -YACYAMLDecodeAll.
    XCTAssertEqualObjects([yaml YACYAMLDecode], expected);
    XCTAssertEqualObjects([yaml YACYAMLDecodeBasic], expected);
    XCTAssertEqualObjects([data YACYAMLDecode], expected);
    XCTAssertEqualObjects([data YACYAMLDecodeBasic], expected);
    XCTAssertNil(gCapturedUnarchiver);
    
    unarchived = [yaml YACYAMLDecodeAll];
    XCTAssertTrue([unarchived[1] isKindOfClass:[YACYAMLNormalObject class]], @"Got %@", unarchived[1]);
    XCTAssertNotNil(gCapturedUnarchiver);
    gCapturedUnarchiver = nil;
}

- (void)testDisallowInitWithCoderOptionStillDecodesYAMLTypes
{
    // The option only stops initWithCoder: being called on tagged classes. The
    // YAML types themselves must still decode to their Cocoa equivalents. (The
    // null key is called 'nothing' because a plain 'null' key would itself be YAML
    // null.)

    NSString *yaml =
        @"string: text\n"
        @"integer: 42\n"
        @"float: 1.5\n"
        @"boolean: y\n"
        @"nothing: ~\n"
        @"date: 2001-12-15T02:59:43Z\n"
        @"binary: !!binary aGVsbG8=\n"
        @"sequence: [a, b]\n"
        @"mapping: { key: value }\n"
        @"set: !!set { a, b }\n";
    
    NSDictionary *unarchived = [yaml YACYAMLDecode];
    
    XCTAssertEqualObjects(unarchived[@"string"], @"text");
    XCTAssertEqualObjects(unarchived[@"integer"], @42);
    XCTAssertEqualObjects(unarchived[@"float"], @1.5);
    XCTAssertEqualObjects(unarchived[@"boolean"], @YES);
    XCTAssertEqualObjects(unarchived[@"nothing"], [NSNull null]);
    XCTAssertTrue([unarchived[@"date"] isKindOfClass:[NSDate class]]);
    XCTAssertEqualWithAccuracy([unarchived[@"date"] timeIntervalSince1970], 1008385183, 0.0005);
    XCTAssertEqualObjects(unarchived[@"binary"], [@"hello" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(unarchived[@"sequence"], (@[ @"a", @"b" ]));
    XCTAssertEqualObjects(unarchived[@"mapping"], (@{ @"key": @"value" }));
    XCTAssertEqualObjects(unarchived[@"set"], ([NSSet setWithObjects:@"a", @"b", nil]));
}

- (void)testAnchorReplacementHazard
{
    // This test verifies that initWithCoder: returning a different object
    // after an anchor has been resolved triggers an exception.
    // The YAML encodes a parent object with an anchor, which contains a child
    // that references the parent via alias (creating a cycle). The parent's
    // initWithCoder: returns a different object (simulating CALayer pattern).

    // Use !YACYAMLSelfReplacingObject tag to get our custom class
    NSString *yaml =
        @"parent: &anchor !YACYAMLSelfReplacingObject\n"
        @"  child: *anchor\n";  // Child references parent - creates cycle during decode

    // This should trigger the YACYAMLAnchorReplacementException because:
    // 1. Parent starts decoding, registers anchor "anchor"
    // 2. Child decodes, resolves anchor "anchor" -> parent's unarchiving object
    // 3. Parent's initWithCoder: runs, returns different object
    // 4. _anchorWasResolved is YES -> exception fires

    XCTAssertThrowsSpecificNamed([YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml],
                                 NSException,
                                 YACYAMLAnchorReplacementException,
                                 @"Should have caught YACYAMLAnchorReplacementException");
}

- (void)testAnchorReplacementExceptionKeepsStackBalanced
{
    NSString *yaml =
        @"parent: &anchor !YACYAMLCapturingReplacingObject\n"
        @"  child: *anchor\n";

    gCapturedUnarchiver = nil;
    XCTAssertThrowsSpecificNamed([YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml],
                                 NSException,
                                 YACYAMLAnchorReplacementException,
                                 @"Should have caught YACYAMLAnchorReplacementException");

    XCTAssertNotNil(gCapturedUnarchiver, @"initWithCoder: should have run");
    XCTAssertEqual([gCapturedUnarchiver unarchivingObjectStackDepth], (NSUInteger)0,
                   @"Unarchiving object stack should be balanced after exception");
    gCapturedUnarchiver = nil;
}

- (void)testAnchorNoReplacementSafe
{
    // Same cycle structure, but initWithCoder: returns self (normal case).
    // Should NOT trigger assertion.

    NSString *yaml =
        @"parent: &anchor !YACYAMLNormalObject\n"
        @"  child: *anchor\n";

    id result = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml];
    XCTAssertNotNil(result, @"Should unarchive without assertion");
    NSDictionary *dict = (NSDictionary *)result;
    YACYAMLNormalObject *parent = [dict objectForKey:@"parent"];
    XCTAssertTrue([parent isKindOfClass:[YACYAMLNormalObject class]], @"Unexpected parent: %@", parent);
    id child = parent.child;
    XCTAssertEqualObjects(parent, child, @"Cycle should resolve to same object");
}

- (void)testArchiverDisallowLocalTagsOption
{
    // The option stops anything with a local tag (one that starts with a single '!', like
    // the !ClassName that application objects are written with) being archived, so that it
    // can't get into the output by accident.  YAML's own types, which have global tags,
    // are still written.
    
    YACYAMLNormalObject *normal = [[YACYAMLNormalObject alloc] init];
    normal.child = @"hello";
    
    // By default, the object is written, tagged with its class.
    NSString *archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:@[ normal ]];
    XCTAssertTrue([archived rangeOfString:@"!YACYAMLNormalObject"].location != NSNotFound, @"Got %@", archived);
    
    // With the option, it raises, wherever the object is: at the top, in a collection, as a
    // dictionary value, or as a dictionary key (an NSURL, for this one, as keys have to be
    // copyable).  Classes that give themselves a local tag are refused too.
    YACYAMLKeyedArchiverOptions options = YACYAMLKeyedArchiverOptionDisallowLocalTags;
    NSArray *unencodable = @[ normal,
                              @[ normal ],
                              @{ @"key": normal },
                              @{ [NSURL URLWithString:@"http://example.com/"]: @"value" },
                              [[YACYAMLLocalTagObject alloc] init] ];
    for(id object in unencodable) {
        XCTAssertThrowsSpecificNamed([YACYAMLKeyedArchiver archivedStringWithRootObject:object options:options],
                                     NSException,
                                     YACYAMLUnsupportedObjectException,
                                     @"Should not have been able to archive %@", object);
    }
    
    // Nothing has been written to the data when it fails: the exception comes before
    // anything is output.
    NSMutableData *data = [NSMutableData data];
    YACYAMLKeyedArchiver *archiver = [[YACYAMLKeyedArchiver alloc] initForWritingWithMutableData:data options:options];
    NSArray *partlyEncodable = @[ @"fine", normal ];
    XCTAssertThrowsSpecificNamed([archiver encodeRootObject:partlyEncodable],
                                 NSException,
                                 YACYAMLUnsupportedObjectException);
    XCTAssertEqual(data.length, (NSUInteger)0);
    
    // YAML's own types are written exactly as they are without the option, including
    // the ones that are not scalars, and null.
    NSArray *native = @[ @"string", @1, @2.5, @YES, [NSNull null],
                         [NSDate dateWithTimeIntervalSinceReferenceDate:0],
                         [NSData dataWithBytes:"abc" length:3],
                         @[ @"nested", @{ @"a": @"b" } ],
                         [NSSet setWithObject:@"member"] ];
    NSString *withoutOption = [YACYAMLKeyedArchiver archivedStringWithRootObject:native];
    NSString *withOption = [YACYAMLKeyedArchiver archivedStringWithRootObject:native options:options];
    XCTAssertEqualObjects(withOption, withoutOption);
    
    // Classes that give themselves a global tag are allowed too.
    YACYAMLGlobalTagObject *global = [[YACYAMLGlobalTagObject alloc] init];
    withOption = [YACYAMLKeyedArchiver archivedStringWithRootObject:@[ global ] options:options];
    XCTAssertTrue([withOption rangeOfString:@"tag:example.com,2026:global"].location != NSNotFound, @"Got %@", withOption);
    
    // The option combines with the others.
    withOption = [YACYAMLKeyedArchiver archivedStringWithRootObject:@[ @"repeated string for anchoring", @"repeated string for anchoring", @"repeated string for anchoring" ]
                                                            options:options | YACYAMLKeyedArchiverOptionAllowScalarAnchors];
    XCTAssertTrue([withOption rangeOfString:@"&"].location != NSNotFound, @"Got %@", withOption);
}

- (void)testUnarchiverDisallowLocalTagsOption
{
    // The option makes the unarchiver ignore local tags (the ones that start with a single
    // '!'), so they never cause a class to be instantiated: what has one is read as if it
    // had no tag.  Global tags, like !!int, which is tag:yaml.org,2002:int, are still honoured.
    // YACYAMLCapturingReplacingObject records the unarchiver when its initWithCoder: runs,
    // so gCapturedUnarchiver being nil afterwards shows that it was never called.
    
    NSString *yaml =
        @"- !YACYAMLCapturingReplacingObject\n"
        @"  child: hello\n"
        @"- !YACYAMLNormalObject [one, two]\n"
        @"- !NotAClass 12\n"
        @"- !!int \"5\"\n"
        @"- !!str 6\n";
    
    // By default, tags name classes, which are instantiated with initWithCoder:.
    gCapturedUnarchiver = nil;
    NSArray *unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml];
    XCTAssertEqual(unarchived.count, (NSUInteger)5);
    XCTAssertNotNil(gCapturedUnarchiver, @"initWithCoder: should be called by default");
    XCTAssertTrue([unarchived[1] isKindOfClass:[YACYAMLNormalObject class]], @"Got %@", unarchived[1]);
    gCapturedUnarchiver = nil;
    
    // With the option, the local tags are ignored (a scalar with an ignored tag is left as a
    // string, not resolved as a number), and the global ones are used.
    NSArray *expected = @[ @{ @"child": @"hello" }, @[ @"one", @"two" ], @"12", @5, @"6" ];
    unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml options:YACYAMLKeyedUnarchiverOptionDisallowLocalTags];
    XCTAssertEqualObjects(unarchived, expected);
    XCTAssertNil(gCapturedUnarchiver, @"initWithCoder: must not be called with the option set");
    
    // The same through the NSData entry point, and combined with the other option.
    unarchived = [YACYAMLKeyedUnarchiver unarchiveObjectWithData:[yaml dataUsingEncoding:NSUTF8StringEncoding]
                                                         options:YACYAMLKeyedUnarchiverOptionDisallowLocalTags | YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder];
    XCTAssertEqualObjects(unarchived, expected);
    XCTAssertNil(gCapturedUnarchiver);
    
    // Output from the archiver with the same option is read back by an unarchiver with it.
    NSArray *native = @[ @"string", @1, @{ @"a": @[ @2.5, [NSNull null] ] } ];
    NSString *archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:native options:YACYAMLKeyedArchiverOptionDisallowLocalTags];
    XCTAssertEqualObjects([YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived options:YACYAMLKeyedUnarchiverOptionDisallowLocalTags], native);
}

- (void)testValueOfObjCTypeWidths
{
    // The values are chosen to need the whole width of each type: reading only part of
    // them (a char for a short, or an int for a long long) gives a different number.
    // Values with every bit set are no good for this, as they survive being narrowed
    // and then sign extended.
    // Each value is archived on its own, as unkeyed values at the top level are written
    // as separate YAML documents, and only the first would be read back.
    
    void (^roundTrip)(const char *, const void *, void *, NSString *) =
        ^(const char *type, const void *value, void *decoded, NSString *expectedYAML) {
            NSMutableData *data = [NSMutableData data];
            YACYAMLKeyedArchiver *archiver = [[YACYAMLKeyedArchiver alloc] initForWritingWithMutableData:data];
            [archiver encodeValueOfObjCType:type at:value];
            [archiver finishEncoding];
            
            NSString *archived = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            XCTAssertTrue([archived hasPrefix:expectedYAML], @"Type %s was archived as %@, not %@", type, archived, expectedYAML);
            
            YACYAMLKeyedUnarchiver *unarchiver = [[YACYAMLKeyedUnarchiver alloc] initForReadingWithData:data];
            [unarchiver decodeValueOfObjCType:type at:decoded];
        };
    
    char c = -100, newC = 0;
    roundTrip("c", &c, &newC, @"-100");
    XCTAssertEqual(newC, c);
    
    short s = -300, newS = 0;
    roundTrip("s", &s, &newS, @"-300");
    XCTAssertEqual(newS, s);
    
    int i = -70000, newI = 0;
    roundTrip("i", &i, &newI, @"-70000");
    XCTAssertEqual(newI, i);
    
    long long q = -(1LL << 40), newQ = 0;
    roundTrip("q", &q, &newQ, @"-1099511627776");
    XCTAssertEqual(newQ, q);
    
    unsigned char C = 200, newUC = 0;
    roundTrip("C", &C, &newUC, @"200");
    XCTAssertEqual(newUC, C);
    
    unsigned short S = 300, newUS = 0;
    roundTrip("S", &S, &newUS, @"300");
    XCTAssertEqual(newUS, S);
    
    unsigned int I = 3000000000u, newUI = 0;
    roundTrip("I", &I, &newUI, @"3000000000");
    XCTAssertEqual(newUI, I);
    
    unsigned long long Q = 1ULL << 40, newUQ = 0;
    roundTrip("Q", &Q, &newUQ, @"1099511627776");
    XCTAssertEqual(newUQ, Q);
}

- (void)testDecodeBytesWithNullLength
{
    // The length is allowed to be NULL, if the caller doesn't need it.  A missing key
    // gives NULL (and a length of 0, if that's asked for), with either.
    NSString *archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:[[YACYAMLBytesObject alloc] init]];
    YACYAMLBytesObject *decoded = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived];
    XCTAssertTrue([decoded isKindOfClass:[YACYAMLBytesObject class]], @"Got %@ from %@", decoded, archived);
    XCTAssertTrue(decoded.decodedBytesWithNullLength);
    XCTAssertTrue(decoded.decodedMissingBytesAsNull);
    XCTAssertEqual(decoded.missingBytesLength, (NSUInteger)0);
}

- (void)testCStringEncodingAndDecoding
{
    // C strings (the '*' type) are written as data, with their terminating NUL, so that any
    // bytes can be encoded, not just valid UTF-8.
    char utf8[] = "caf\xC3\xA9";
    char notUTF8[] = { 'a', (char)0xFF, (char)0xFE, 'b', 0 };
    char empty[] = "";
    char *strings[] = { utf8, notUTF8, empty };
    for(NSUInteger i = 0; i < 3; i++) {
        char *string = strings[i];
        NSMutableData *data = [NSMutableData data];
        YACYAMLKeyedArchiver *archiver = [[YACYAMLKeyedArchiver alloc] initForWritingWithMutableData:data];
        [archiver encodeValueOfObjCType:"*" at:&string];
        [archiver finishEncoding];
        
        char *decoded = NULL;
        YACYAMLKeyedUnarchiver *unarchiver = [[YACYAMLKeyedUnarchiver alloc] initForReadingWithData:data];
        [unarchiver decodeValueOfObjCType:"*" at:&decoded];
        XCTAssertTrue(decoded != NULL && strcmp(decoded, string) == 0, @"String %lu did not round trip", (unsigned long)i);
    }
    
    // A NULL string can't be encoded.
    NSMutableData *data = [NSMutableData data];
    YACYAMLKeyedArchiver *archiver = [[YACYAMLKeyedArchiver alloc] initForWritingWithMutableData:data];
    char *null = NULL;
    XCTAssertThrowsSpecificNamed([archiver encodeValueOfObjCType:"*" at:&null],
                                 NSException,
                                 YACYAMLUnsupportedObjectException);
    
    // What's decoded always ends in a NUL, even if the YAML's data doesn't have one (here,
    // "abc" with nothing after it, and no bytes at all), so that a caller can use it as a C
    // string without reading off the end of it.  Hand-written strings are read as well.
    NSDictionary *yamlToExpected = @{ @"!!binary YWJj": @"abc",
                                      @"!!binary YWJjAA==": @"abc",
                                      @"!!binary \"\"": @"",
                                      @"hello": @"hello",
                                      @"'caf\u00e9'": @"caf\u00e9" };
    for(NSString *yaml in yamlToExpected) {
        char *decoded = NULL;
        YACYAMLKeyedUnarchiver *unarchiver = [[YACYAMLKeyedUnarchiver alloc] initForReadingWithData:[yaml dataUsingEncoding:NSUTF8StringEncoding]];
        [unarchiver decodeValueOfObjCType:"*" at:&decoded];
        NSString *expected = yamlToExpected[yaml];
        XCTAssertTrue(decoded != NULL && strcmp(decoded, expected.UTF8String) == 0, @"%@ was decoded as %s", yaml, decoded);
    }
    
    // Anything else can't be a C string.
    for(NSString *yaml in @[ @"[1, 2]", @"{ a: b }" ]) {
        char *decoded = NULL;
        YACYAMLKeyedUnarchiver *unarchiver = [[YACYAMLKeyedUnarchiver alloc] initForReadingWithData:[yaml dataUsingEncoding:NSUTF8StringEncoding]];
        XCTAssertThrowsSpecificNamed([unarchiver decodeValueOfObjCType:"*" at:&decoded],
                                     NSException,
                                     YACYAMLUnsupportedTypeException,
                                     @"%@", yaml);
    }
}

- (void)testEmptyCollections
{
    // An empty dictionary used to be written as an empty sequence ([]), and read back as an NSArray.
    // An empty set has the same problem.
    NSDictionary *dictionary = @{};
    NSSet *set = [NSSet set];
    NSArray *array = @[];
    
    NSString *archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:dictionary];
    XCTAssertTrue([archived hasPrefix:@"{}"], @"Got %@", archived);
    id decoded = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived];
    XCTAssertTrue([decoded isKindOfClass:[NSDictionary class]], @"Got %@ from %@", [decoded class], archived);
    XCTAssertEqual([decoded count], (NSUInteger)0);
    
    archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:set];
    decoded = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived];
    XCTAssertTrue([decoded isKindOfClass:[NSSet class]], @"Got %@ from %@", [decoded class], archived);
    XCTAssertEqual([decoded count], (NSUInteger)0);
    
    archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:array];
    XCTAssertTrue([archived hasPrefix:@"[]"], @"Got %@", archived);
    decoded = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived];
    XCTAssertTrue([decoded isKindOfClass:[NSArray class]], @"Got %@ from %@", [decoded class], archived);
    
    // And inside other collections, as values and as elements.
    NSDictionary *nested = @{ @"dictionary": dictionary, @"set": set, @"array": array, @"list": @[ dictionary, set, array ] };
    archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:nested];
    decoded = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:archived];
    XCTAssertEqualObjects(decoded, nested, @"Did not round trip:\n%@", archived);
    XCTAssertTrue([decoded[@"dictionary"] isKindOfClass:[NSDictionary class]]);
    XCTAssertTrue([decoded[@"set"] isKindOfClass:[NSSet class]]);
    XCTAssertTrue([decoded[@"array"] isKindOfClass:[NSArray class]]);
    NSArray *list = decoded[@"list"];
    XCTAssertTrue([list[0] isKindOfClass:[NSDictionary class]] && [list[1] isKindOfClass:[NSSet class]] && [list[2] isKindOfClass:[NSArray class]], @"Got %@", list);
    
    // An object that isn't a collection, with nothing to encode, is still an empty sequence.
    archived = [YACYAMLKeyedArchiver archivedStringWithRootObject:[[YACYAMLNormalObject alloc] init]];
    XCTAssertTrue([archived rangeOfString:@"[]"].location != NSNotFound, @"Got %@", archived);
}

- (void)testUnarchivedObjectOfClass
{
    // As for NSKeyedUnarchiver, the decoded object has to be of the class (or a subclass).
    // (It's checked after the YAML is decoded, so it doesn't limit what is instantiated.)
    NSData *data = [@"- a\n- b\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSArray *expected = @[ @"a", @"b" ];
    XCTAssertEqualObjects([YACYAMLKeyedUnarchiver unarchivedObjectOfClass:[NSArray class] fromData:data error:&error], expected);
    XCTAssertNil(error);
    XCTAssertNotNil([YACYAMLKeyedUnarchiver unarchivedObjectOfClass:[NSObject class] fromData:data error:&error]);
    XCTAssertNotNil([YACYAMLKeyedUnarchiver unarchivedObjectOfClass:[NSArray class]
                                                           fromData:data
                                                            options:YACYAMLKeyedUnarchiverOptionDisallowLocalTags
                                                              error:&error]);
    
    XCTAssertNil([YACYAMLKeyedUnarchiver unarchivedObjectOfClass:[NSDictionary class] fromData:data error:&error]);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(error.code, NSCoderReadCorruptError);
    
    // And it is fine with NULL for the error.
    XCTAssertNil([YACYAMLKeyedUnarchiver unarchivedObjectOfClass:[NSDictionary class] fromData:data error:NULL]);
}

@end
