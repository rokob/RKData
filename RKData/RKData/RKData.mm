//  Copyright (c) 2014 rokob. All rights reserved.

#import "RKData.h"

#import <mutex>
#import <list>
#import <unordered_map>

@implementation RKData
@end

@implementation RKEntity
@end

RKEntityCacheKeyGenerator simpleKeyGenerator() {
  return [^NSUInteger(id<RKEntityDescription> description) {
    return [[description URL] hash];
  } copy];
}

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

- (void)performCallbackForEvent:(RKSubscriptionEvent)event withObject:(id)object;
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

- (void)dealloc
{
  [_delegate removeSubscription:self];
}

- (void)remove
{
  [_delegate removeSubscription:self];
  _delegate = nil;
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
    _object = object;
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
  RKEntityCacheKeyGenerator _keyGenerator;
  id<RKNetworkSubscriber> _network;
  NSURL *_baseURL;
  RKDataSubscriberPolicy _policy;
  NSMapTable *_subscriptions;
  std::mutex _subscriptionMutex;
  std::mutex _cacheMutex;
}

@end

@implementation RKDataSubscriber

- (id)initWithCache:(id<RKCache>)cache network:(id<RKNetworkSubscriber>)network keyGenerator:(RKEntityCacheKeyGenerator)keyGenerator
{
  return [self initWithCache:cache network:network keyGenerator:keyGenerator baseURL:nil];
}

- (id)initWithCache:(id<RKCache>)cache
            network:(id<RKNetworkSubscriber>)network
       keyGenerator:(RKEntityCacheKeyGenerator)keyGenerator
            baseURL:(NSURL *)baseURL
{
  return [self initWithCache:cache network:network keyGenerator:keyGenerator baseURL:baseURL policy:RKDataSubscriberPolicyDefault];
}

- (id)initWithCache:(id<RKCache>)cache
            network:(id<RKNetworkSubscriber>)network
       keyGenerator:(RKEntityCacheKeyGenerator)keyGenerator
            baseURL:(NSURL *)baseURL
             policy:(RKDataSubscriberPolicy)policy
{
  NSAssert((!cache && !keyGenerator) || (cache && keyGenerator), @"cache must come with a key generator");
  NSAssert(cache || network, @"must have at least one of cache or network");
  NSAssert(cache || (policy != RKDataSubscriberPolicyCacheOnly), @"cache only policy means we need a cache");
  if ((self = [super init])) {
    _cache = cache;
    _keyGenerator = [keyGenerator copy];
    _network = network;
    _baseURL = baseURL;
    _policy = policy;

    NSPointerFunctionsOptions options = NSPointerFunctionsObjectPointerPersonality|NSPointerFunctionsStrongMemory;
    _subscriptions = [NSMapTable mapTableWithKeyOptions:options valueOptions:options];
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
  callback = [callback copy];
  RKSubscription *handle = [[RKSubscription alloc] initWithEntity:entity
                                                           parser:parser
                                                            event:event
                                                         callback:callback
                                                            queue:queue
                                                         delegate:self];
  NSUInteger cacheKey = 0;
  BOOL shouldAddToNetwork = _policy != RKDataSubscriberPolicyCacheOnly;
  BOOL hasCache = _cache && _keyGenerator;
  if (hasCache) {
    cacheKey = _keyGenerator(entity);
    shouldAddToNetwork = [self getCachedEntity:entity
                                      cacheKey:cacheKey
                                         event:event
                                      callback:callback
                                         queue:queue];
  }

  if (shouldAddToNetwork) {
    void(^wrappedCallback)(id<RKEntityValue>) = [self getWrappedNetworkBlockForEvent:event
                                                                            hasCache:hasCache
                                                                            cacheKey:cacheKey
                                                                              handle:handle
                                                                            callback:callback];

    id<RKSubscriptionHandle> networkHandle = [_network subscribeToEntity:entity
                                                                   event:event
                                                                callback:wrappedCallback
                                                                   queue:queue];
    {
      std::lock_guard<std::mutex> lock(_subscriptionMutex);
      [_subscriptions setObject:networkHandle forKey:handle];
    }
    return handle;
  }
  // If we get here it means that the subscription was for a single value and we fulfilled it from the cache
  return nil;
}

- (BOOL)getCachedEntity:(id<RKEntityDescription>)entity
               cacheKey:(NSUInteger)cacheKey
                  event:(RKSubscriptionEvent)event
               callback:(void(^)(id<RKEntityValue>))callback
                  queue:(dispatch_queue_t)queue
{
  std::lock_guard<std::mutex> lock(_cacheMutex);
  BOOL shouldAddToNetwork = _policy != RKDataSubscriberPolicyCacheOnly;
  id<RKEntityValue> entityValue = [_cache objectForKey:@(cacheKey)];
  if (entityValue && callback) {
    if (event & RKSubscriptionEventValueOnce) {
      shouldAddToNetwork = NO;
    }
    dispatch_async(queue, ^{
      if (event & (RKSubscriptionEventValue | RKSubscriptionEventValueOnce)) {
        callback(entityValue);
      }
    });
  }
  return shouldAddToNetwork;
}

- (void(^)(id<RKEntityValue>))getWrappedNetworkBlockForEvent:(RKSubscriptionEvent)event
                                                    hasCache:(BOOL)hasCache
                                                    cacheKey:(NSUInteger)cacheKey
                                                      handle:(id<RKSubscriptionHandle>)handle
                                                    callback:(void(^)(id<RKEntityValue>))callback
{
  RKDataSubscriber* __weak weakSelf = self;
  void(^wrappedCallback)(id<RKEntityValue>) = ^(id<RKEntityValue> value) {
    RKDataSubscriber* strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    if (hasCache && ![value isEqual:[NSNull null]] && !(event & RKSubscriptionEventValueOnce)) {
      std::lock_guard<std::mutex> lock(strongSelf->_cacheMutex);
      [strongSelf->_cache setObject:value forKey:@(cacheKey)];
    }
    if (event & RKSubscriptionEventValueOnce) {
      [strongSelf removeSubscription:handle];
    }
    if (callback) {
      callback(value);
    }
  };
  return [wrappedCallback copy];
}

- (void)removeAllSubscriptions
{
  NSMapTable *subscriptions = nil;
  {
    std::lock_guard<std::mutex> lock(_subscriptionMutex);
    subscriptions = [_subscriptions copy];
    [_subscriptions removeAllObjects];
  }
  for (id<RKSubscriptionHandle> handle in [subscriptions objectEnumerator]) {
    [handle remove];
  }
}

- (void)removeSubscription:(RKSubscription *)subscription
{
  id<RKSubscriptionHandle> networkHandle = nil;
  {
    std::lock_guard<std::mutex> lock(_subscriptionMutex);
    networkHandle = [_subscriptions objectForKey:subscription];
    [_subscriptions removeObjectForKey:subscription];
  }
  [networkHandle remove];
}

@end

@implementation RKSuperSimpleCache
@end

struct CacheEntry {
  id key;
  id object;
};

template<>
struct std::hash<id> {
  size_t operator()(const id& obj) const {
    return [obj hash];
  }
};

template<>
struct std::equal_to<id> {
  bool operator()(const id& a, const id& b) const {
    return a == b;
  }
};

template<>
struct std::hash<NSObject*> {
  size_t operator()(const NSObject* const obj) const {
    return [obj hash];
  }
};

template<>
struct std::equal_to<NSObject*> {
  bool operator()(const NSObject* const a, const NSObject* const b) const {
    return a == b;
  }
};

@implementation RKSimpleCache
{
  std::list<CacheEntry> _list;
  std::unordered_map<id, typename std::list<CacheEntry>::iterator> _cache;
  NSUInteger _capacity;
  double _compactionFactor;
}

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
  return [self initWithCapacity:capacity compactionFactor:0.2];
}

- (instancetype)initWithCapacity:(NSUInteger)capacity compactionFactor:(double)compactionFactor
{
  if ((self = [super init])) {
    _capacity = capacity;
    _compactionFactor = compactionFactor;
  }
  return self;
}

- (void)setObject:(id)object forKey:(id)key
{
  auto cacheIter = _cache.find(key);
  if (cacheIter != _cache.end()) {
    cacheIter->second->object = object;
    _list.splice(_list.begin(), _list, cacheIter->second);
  } else {
    if (_cache.size() >= _capacity) {
      NSUInteger numberOfObjectsToRemove = (NSUInteger)(_compactionFactor * _capacity);
      for (NSUInteger objectsRemoved = 0; objectsRemoved < numberOfObjectsToRemove; objectsRemoved++) {
        CacheEntry e = _list.back();
        _cache.erase(e.key);
        _list.pop_back();
      }
    }
    _cache[key] = _list.insert(_list.begin(), {key, object});
  }
}

- (id)objectForKey:(id)key
{
  auto cacheIter = _cache.find(key);
  if (cacheIter == _cache.end()) {
    return nil;
  } else {
    _list.splice(_list.begin(), _list, cacheIter->second);
    return cacheIter->second->object;
  }
}

@end
