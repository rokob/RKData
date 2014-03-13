//  Copyright (c) 2014 rokob. All rights reserved.

#import <XCTest/XCTest.h>

#define EXP_SHORTHAND
#import <Expecta/Expecta.h>

#import <Specta/Specta.h>
#import <RKData/RKData.h>

@interface RKDataTests : XCTestCase

@end

SpecBegin(SimpleCache)

describe(@"The simple cache", ^{
  __block RKSimpleCache *simpleCache;

  beforeEach(^{
    simpleCache = [[RKSimpleCache alloc] initWithCapacity:5];
  });

  it(@"should allow adding an element", ^{
    expect(^{ [simpleCache setObject:@"anObject" forKey:@"key"]; }).notTo.raiseAny();
  });

  it(@"should allow getting an added element", ^{
    [simpleCache setObject:@"anObject" forKey:@"key"];
    expect([simpleCache objectForKey:@"key"]).to.equal(@"anObject");
  });

  it(@"should evict the right number of elements on hitting capacity", ^{
    for (int i=0; i < 6; i++) {
      [simpleCache setObject:[NSString stringWithFormat:@"%dObject", i] forKey:@(i)];
    }
    expect([simpleCache objectForKey:@0]).to.beNil();
    expect([simpleCache objectForKey:@1]).to.equal(@"1Object");
  });

  it(@"should consider a read as bumping the LRU priority", ^{
    for (int i=0; i < 6; i++) {
      if (i == 4) {
        expect([simpleCache objectForKey:@0]).to.equal(@"0Object");
      }
      [simpleCache setObject:[NSString stringWithFormat:@"%dObject", i] forKey:@(i)];
    }
    expect([simpleCache objectForKey:@1]).to.beNil();
    expect([simpleCache objectForKey:@0]).notTo.beNil();
    expect([simpleCache objectForKey:@2]).to.equal(@"2Object");
  });
});

SpecEnd
