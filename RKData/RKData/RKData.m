//  Copyright (c) 2014 rokob. All rights reserved.

#import "RKData.h"

@implementation RKData
@end

@implementation RKEntity
@end

@class RKSubscription;

@protocol RKSubscriptionDelegate <NSObject>
- (void)removeSubscription:(RKSubscription *)subscription;
@end

@interface RKSubscription : NSObject <RKSubscriptionHandle>
- (id)initWithEntity:(id<RKEntityDescription>)entity
              parser:(id<RKEntityParser>)parser
               event:(RKSubscriptionEvent)event
            callback:(void(^)(id<RKEntityValue>))callback
               queue:(dispatch_queue_t)queue
            delegate:(id<RKSubscriptionDelegate>)delegate;
@end

@implementation RKSubscription
{
  id<RKEntityDescription> _entity;
  id<RKEntityParser> _parser;
  RKSubscriptionEvent _event;
  void(^_callback)(id<RKEntityValue>);
  dispatch_queue_t _queue;
  id<RKSubscriptionDelegate> __weak _delegate;
}

- (id)initWithEntity:(id<RKEntityDescription>)entity
              parser:(id<RKEntityParser>)parser
               event:(RKSubscriptionEvent)event
            callback:(void (^)(id<RKEntityValue>))callback
               queue:(dispatch_queue_t)queue
            delegate:(id<RKSubscriptionDelegate>)delegate
{
  if ((self = [super init])) {
    _entity = entity;
    _parser = parser;
    _event = event;
    _callback = [callback copy];
    _queue = queue;
    _delegate = delegate;
  }
  return self;
}

- (void)remove
{
  [_delegate removeSubscription:self];
}

- (void)performCallbackForEvent:(RKSubscriptionEvent)event withObject:(id)object
{
  if (event & _event) {
    id<RKEntityValue> value = [_parser valueFromObject:object withDescription:_entity];
    dispatch_async(_queue, ^{
      if (_callback) {
        _callback(value);
      }
    });
  }
}
@end

@interface RKEntityValue : NSObject <RKEntityValue>
- (id)initWithObject:(id)object;
@end

@implementation RKEntityValue
{
  id _object;
}

- (id)initWithObject:(id)object
{
  if ((self = [super init])) {
    _object = [object isEqual:[NSNull null]] ? [NSNull null] : object;
  }
  return self;
}

- (RKEntity *)value
{
  return _object;
}
@end

@interface RKEntityParser : NSObject <RKEntityParser>
+ (instancetype)defaultParser;
@end

@implementation RKEntityParser

+ (instancetype)defaultParser
{
  return [[self alloc] init];
}

- (id<RKEntityValue>)valueFromObject:(id)object withDescription:(id<RKEntityDescription>)description
{
  return [[RKEntityValue alloc] initWithObject:object];
}
@end

@interface RKDataSubscriber () <RKSubscriptionDelegate>
{
  id<RKCache> _cache;
  NSURL *_baseURL;
  RKDataSubscriberPolicy _policy;
  NSHashTable *_subscriptions;
}

@end

@implementation RKDataSubscriber

- (id)initWithCache:(id<RKCache>)cache
{
  return [self initWithCache:cache baseURL:nil];
}

- (id)initWithCache:(id<RKCache>)cache baseURL:(NSURL *)baseURL
{
  return [self initWithCache:cache baseURL:baseURL policy:RKDataSubscriberPolicyDefault];
}

- (id)initWithCache:(id<RKCache>)cache baseURL:(NSURL *)baseURL policy:(RKDataSubscriberPolicy)policy
{
  if ((self = [super init])) {
    _cache = cache;
    _baseURL = baseURL;
    _policy = policy;

    NSPointerFunctionsOptions options = NSPointerFunctionsObjectPointerPersonality|NSPointerFunctionsStrongMemory;
    _subscriptions = [[NSHashTable alloc] initWithOptions:options
                                                 capacity:0];
  }
  return self;
}

- (id<RKSubscriptionHandle>)subscribeToEntity:(id<RKEntityDescription>)entity
                                     callback:(void(^)(id<RKEntityValue>))callback
                                        queue:(dispatch_queue_t)queue
{
  return [self subscribeToEntity:entity
                          parser:[RKEntityParser defaultParser]
                           event:RKSubscriptionEventValue
                        callback:callback
                           queue:queue];
}

- (id<RKSubscriptionHandle>)subscribeToEntity:(id<RKEntityDescription>)entity
                                        event:(RKSubscriptionEvent)event
                                     callback:(void(^)(id<RKEntityValue>))callback
                                        queue:(dispatch_queue_t)queue
{
  return [self subscribeToEntity:entity
                          parser:[RKEntityParser defaultParser]
                           event:event
                        callback:callback
                           queue:queue];
}

- (id<RKSubscriptionHandle>)subscribeToEntity:(id<RKEntityDescription>)entity
                                       parser:(id<RKEntityParser>)parser
                                     callback:(void(^)(id<RKEntityValue>))callback
                                        queue:(dispatch_queue_t)queue
{
  return [self subscribeToEntity:entity
                          parser:parser
                           event:RKSubscriptionEventValue
                        callback:callback
                           queue:queue];
}

- (id<RKSubscriptionHandle>)subscribeToEntity:(id<RKEntityDescription>)entity
                                       parser:(id<RKEntityParser>)parser
                                        event:(RKSubscriptionEvent)event
                                     callback:(void(^)(id<RKEntityValue>))callback
                                        queue:(dispatch_queue_t)queue
{
  RKSubscription *handle = [[RKSubscription alloc] initWithEntity:entity
                                                           parser:parser
                                                            event:event
                                                         callback:callback
                                                            queue:queue
                                                         delegate:self];
  return handle;
}

- (void)removeAllSubscriptions
{
  [_subscriptions removeAllObjects];
}

- (void)removeSubscription:(RKSubscription *)subscription
{
  [_subscriptions removeObject:subscription];
}

@end
