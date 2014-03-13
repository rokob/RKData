//  Copyright (c) 2014 rokob. All rights reserved.

#import <Foundation/Foundation.h>

@interface RKData : NSObject
@end

@interface RKEntity : NSObject
@end

@protocol RKEntityDescription <NSObject>
- (NSURL *)URL;
@end

@protocol RKEntityValue <NSObject>
- (RKEntity *)value;
@end

@protocol RKCache <NSObject>
- (id)objectForKey:(id)key;
- (void)setObject:(id)object forKey:(id)key;
@end

@interface RKSuperSimpleCache : NSMutableDictionary <RKCache>
@end

@interface RKSimpleCache : NSObject <RKCache>
- (instancetype)initWithCapacity:(NSUInteger)capacity;
- (instancetype)initWithCapacity:(NSUInteger)capacity compactionFactor:(double)compactionFactor;
@end

typedef NSUInteger(^RKEntityCacheKeyGenerator)(id<RKEntityDescription>);

@protocol RKNetwork <NSObject>
- (void)executeRequest:(NSURLRequest *)request
              callback:(void(^)(NSURLResponse *, NSError *))callback
                 queue:(dispatch_queue_t)queue;
@end

@protocol RKSubscriptionHandle <NSObject>
- (void)remove;
@end

@protocol RKEntityParser <NSObject>
- (id<RKEntityValue>)valueFromObject:(id)object withDescription:(id<RKEntityDescription>)description;
@end

typedef NS_OPTIONS(NSUInteger, RKSubscriptionEvent) {
  RKSubscriptionEventCreate = 1 << 0,
  RKSubscriptionEventValueOnce = 1 << 1,
  RKSubscriptionEventDelete = 1 << 2,
  RKSubscriptionEventValueAll = 1 << 3 | 1 << 2 | 1 << 1 | 1 << 0,

  RKSubscriptionEventChildAdd = 1 << 4,
  RKSubscriptionEventChildUpdate = 1 << 5,
  RKSubscriptionEventChildRemove = 1 << 6,
  RKSubscriptionEventChildMove = 1 << 7,
  RKSubscriptionEventChildAll = 1 << 7 | 1 << 6 | 1 << 5 | 1 << 4,

  RKSubscriptionEventValue = RKSubscriptionEventValueAll | RKSubscriptionEventChildAll
};

typedef NS_ENUM(NSUInteger, RKDataSubscriberPolicy) {
  RKDataSubscriberPolicyDefault,
  RKDataSubscriberPolicyCacheOnly,
};

@protocol RKNetworkSubscriber <NSObject>
- (id<RKSubscriptionHandle>)subscribeToEntity:(id<RKEntityDescription>)entity
                                        event:(RKSubscriptionEvent)event
                                     callback:(void(^)(id<RKEntityValue> value))callback
                                        queue:(dispatch_queue_t)queue;
@end

@interface RKDataSubscriber : NSObject

- (instancetype)initWithCache:(id<RKCache>)cache
                      network:(id<RKNetworkSubscriber>)network
                 keyGenerator:(RKEntityCacheKeyGenerator)keyGenerator;

- (instancetype)initWithCache:(id<RKCache>)cache
                      network:(id<RKNetworkSubscriber>)network
                 keyGenerator:(RKEntityCacheKeyGenerator)keyGenerator
                      baseURL:(NSURL *)baseURL;

- (instancetype)initWithCache:(id<RKCache>)cache
                      network:(id<RKNetworkSubscriber>)network
                 keyGenerator:(RKEntityCacheKeyGenerator)keyGenerator
                      baseURL:(NSURL *)baseURL
                       policy:(RKDataSubscriberPolicy)policy;

- (id<RKSubscriptionHandle>)subscribeToEntity:(id<RKEntityDescription>)entity
                                     callback:(void(^)(id<RKEntityValue> value))callback
                                        queue:(dispatch_queue_t)queue;

- (id<RKSubscriptionHandle>)subscribeToEntity:(id<RKEntityDescription>)entity
                                        event:(RKSubscriptionEvent)event
                                     callback:(void(^)(id<RKEntityValue> value))callback
                                        queue:(dispatch_queue_t)queue;

- (id<RKSubscriptionHandle>)subscribeToEntity:(id<RKEntityDescription>)entity
                                       parser:(id<RKEntityParser>)parser
                                     callback:(void(^)(id<RKEntityValue> value))callback
                                        queue:(dispatch_queue_t)queue;

- (id<RKSubscriptionHandle>)subscribeToEntity:(id<RKEntityDescription>)entity
                                       parser:(id<RKEntityParser>)parser
                                        event:(RKSubscriptionEvent)event
                                    callback:(void(^)(id<RKEntityValue> value))callback
                                       queue:(dispatch_queue_t)queue;

- (void)removeAllSubscriptions;

@end
