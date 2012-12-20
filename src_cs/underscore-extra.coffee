# Extends underscore with a few generic helper functions that we find useful.

_ = require "underscore"

# An arbitrary-size LRU cache. Saves the result of the last maxSize calls into
# a dictionary. Essentially a memoize function with an optional memory bound.
# Should only be used to wrap a function where arguments are immutable and there
# are no side effects (the functional case).
lruCache = (args...) ->
    # argument parsing
    [maxSize, getKey] = [undefined, _.identity]
    f = args[args.length - 1]
    if args.length >= 2 then maxSize = args[0]
    if args.length >= 3 then getKey = args[1]
    
    # reorder arguments if needed
    oldMaxSize = maxSize
    if _.isNumber(getKey) then maxSize = getKey
    if _.isFunction(oldMaxSize) then getKey = oldMaxSize

    cache = {}
    cacheKeys = [] # A queue that lets us determine what key to get rid of next
    return (args...) -> # The wrapping function
        key = getKey args...
        if key of cache then return cache[key]
        result = f.apply this, args
        cacheKeys.shift key
        if maxSize? and cacheKeys.length > maxSize
            delete cache[cacheKeys.pop()]
        return cache[key] = result

# A fast single-entry LRU cache. Being single-entry, we don't need to hash to
# maintain a O(1) lookup, as instead we only have one item to lookup against.
# This is useful if most calls to a function are directly after another. It also
# saves against the (relatively) expensive operation of hashing a board.
simpleLruCache = (f, getKey=(a...) -> a) ->
    lastKey = undefined
    lastResult = undefined
    return (args...) ->
        key = getKey args...
        if _.isEqual(key, lastKey) then return lastResult
        lastKey = key
        return lastResult = f.apply this, args

# Like _.compact, except instead of removing all "falsy" values, only removes
# null and undefined values using coffescript's existential operator.
compactExists = (array) -> _.filter array, ((value)->value?)

# Calls console.log on the value, but can also be used in a chain like _.tap.
log = (value) -> _.tap(value, console.log)

# Ensures a <= value <= b, "clamp"ing the value
clamp = (value, a, b) -> Math.min(Math.max(value, a), b)

# Just like Python's `sum` function, takes an array of numbers, or a bunch of
# numbers as arguments, and then adds them all together, returning the sum.
sum = (list) ->
    if _.isNumber list
        list = _.toArray arguments
    return _.reduce list, ((memo, n) -> memo + n), 0

isDebug = true

# Doesn't get compiled away, although it could be with an agressive enough
# minimizer. Will take a boolean value or a function. When passed a function, it
# will evaluate the return value of it. This is useful for expensive assertion
# operations that you don't want to be run when not in debug mode, or for giving
# context to and improving readability of larger assertion calculations.
assert = (value) ->
    if not isDebug then return
    if _.isFunction(value) then value = value()
    if not value
        throw {
            name: "Failed assertion"
        }

# Can disable or enable assertions. If passed a function, the assertion won't
# even be evaluated.
setDebug = (isEnabled) -> isDebug = isEnabled

_.mixin {
    lruCache: lruCache
    simpleLruCache: simpleLruCache
    compactExists: compactExists
    log: log
    clamp: clamp
    sum: sum
    assert: assert
    setDebug: setDebug
}
module.exports = _
