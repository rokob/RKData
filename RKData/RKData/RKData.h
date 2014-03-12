//  Copyright (c) 2014 rokob. All rights reserved.

#import <Foundation/Foundation.h>

@interface RKData : NSObject
@end

@protocol RKCache <NSObject>
- (id)objectForKey:(id)key;
- (void)setObject:(id)object forKey:(id)key;
@end

@interface RKEntity : NSObject
@end

@protocol RKEntityDescription <NSObject>
- (NSURL *)URL;
@end

@protocol RKEntityValue <NSObject>
- (RKEntity *)value;
@end

@protocol RKSubscriptionHandle <NSObject>
- (void)remove;
@end

@protocol RKEntityParser <NSObject>
- (id<RKEntityValue>)valueFromObject:(id)object withDescription:(id<RKEntityDescription>)description;
@end

typedef NS_OPTIONS(NSUInteger, RKSubscriptionEvent) {
  RKSubscriptionEventCreated = 1 << 0,
  RKSubscriptionEventValueOnce = 1 << 1,
  RKSubscriptionEventDelete = 1 << 2,
  RKSubscriptionEventValue = 1 << 3 | 1 << 2 | 1 << 1 | 1 << 0,
};

typedef NS_ENUM(NSUInteger, RKDataSubscriberPolicy) {
  RKDataSubscriberPolicyDefault,
  RKDataSubscriberPolicyCacheOnly,
};

@interface RKDataSubscriber : NSObject

- (instancetype)initWithCache:(id<RKCache>)cache;
- (instancetype)initWithCache:(id<RKCache>)cache baseURL:(NSURL *)baseURL;
- (instancetype)initWithCache:(id<RKCache>)cache baseURL:(NSURL *)baseURL policy:(RKDataSubscriberPolicy)policy;

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
