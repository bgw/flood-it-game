# Provides a generic greedy solver.

_ = require "../underscore-extra.coffee"

# A greedy solver iteratively picks the highest (or lowest) valued neighbor in
# its path. Sometimes greedy solvers will find an optimal solution, but for many
# problem types it just gives an imperfect-but-good-enough solution to a
# problem. We take a starting point, a function telling is if a given graph node
# is an ending point, a function to get the neighbors, and optionally (but
# highly recommended) a scoring function that takes a node.
#
# A hashing function, if passed should identify the problem set uniquely as well
# as the given board node. The cache comes in handy when calling function
# repeatedly with a subproblem that was previously solved as part of a fuller
# solution, such as when it is being used as a (usually non-admissible)
# heuristic for an aStar function.
#
# `preferLower` can be used to make the solver pick the lowest valued neighbor,
# rather than the highest. This might be convenient for certain types of
# heuristic functions.
greedySolver = _.lruCache 1000, ((args...) ->
    getKey = args[4]?.getKey
    getKey ?= _.identity
    return getKey args...
), (start, isEnd, getNeighbors, getScore=(->0), {preferLower, getKey}={}) ->
    # default kwargs
    preferLower ?= false
    getKey ?= _.identity

    if isEnd start then return [start]
    bestScore = -Infinity
    next = undefined
    for neighbor in getNeighbors start
        neighborScore = getScore neighbor
        if preferLower then neighborScore *= -1
        if neighborScore > bestScore
            [bestScore, next] = [neighborScore, neighbor]
    return [start, next].concat(
        greedySolver(next, Array::slice.call(arguments, 1)...)[1..]
    )

module.exports = greedySolver
