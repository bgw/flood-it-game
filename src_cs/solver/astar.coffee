# Lovely, lovely a-star!

_ = require "../underscore-extra.coffee"
MinHeap = require "./minheap.coffee"

# Stolen from https://en.wikipedia.org/wiki/A*_search_algorithm#Pseudocode and
# generalized a bit.
#
# - `start` should be the starting state of our graph, which we will branch off
#   of until we get to an endpoint.
# - `isEnd` should tell us if a passed argument is a valid ending state or not
# - `getNeighbors` should take a graph node, such as `start` and give us an
#   array of nodes in the graph that are neighbors of our node.
# - `distance` should take two nodes, A and B, and tell us the distance needed
#   to travel to get from node A to B. This should always be >= 0, as the
#   algorithm assumes such.
# - `heuristic` should guess the total distance from the current node to the
#   nearest end-node
# - `getKey` should give a string or an object with a toString method that
#   uniquely expresses the node as concisely as possible. This is used for
#   dictionary keys. The default is the identity function.
# - `maxFCost` is an Number representing the maximum guessed value we should
#   give up after. We can use this to trim our tree of possible solutions. For
#   instance, with an admissible heuristic, if a path has to have a total
#   distance of 10, and we see that a node would need more than 10 units of
#   distance total to reach an exit, we can just drop it.
# - `callback` will, if passed, make this function non-blocking, never locking
#   up the stack, using `_.defer`. It should be in the form
#   `callback(result, err)`.
# - `asyncBlockSize` is the number of nodes in the search space that should be
#   investigated before a call to `_.defer` when we are acting asynchronously.
#   Calling `_.defer` in too small of increments may cause reduced performance.
# - `fastSolver` is a function that will get called on each analysis step. If
#   the solver's solution is less than (impossible in the case of an admissible
#   heuristic) or equal to the predicted remaining minimum solution cost, its
#   solution will be used instead of computing one with the a-star algorithm. It
#   should take a partially solved graph node, and return an object with "cost"
#   and "path" entries.
#
# When non-blocking, the return value is an object of control functions:
#
# - `pause()` will temporally stop execution. You can discard a paused state if
#   you want, and the VM will garbage collect the state. If the execution was
#   already finished or already paused, this does nothing.
# - `resume()` does the reverse of `pause()`. If the state was not paused, it
#   does nothing.
#
# This allows you to set limits on how long-running calls may be, and to make a
# more responsive UI. You may wish to combine `pause()` with `_.delay()`.
#
# When blocking, the return value is naturally the result of the computation.
aStar = (start, isEnd, getNeighbors, distance, {heuristic, getKey, maxFCost,
         callback, asyncBlockSize, fastSolver}={}) ->
    # Default values for keyword arguments, because of
    # https://github.com/jashkenas/coffee-script/issues/1558
    heuristic ?= ->0
    getKey ?= _.identity
    maxFCost ?= Infinity
    asyncBlockSize ?= 100

    [closedSet, openSet, cameFrom] = [{}, {}, {}]
    openSet[getKey start] = start # openSet has nodes left to evaluate
    openSet.length = 1

    # Cached cost data
    gCost = {}; gCost[getKey start] = 0 # from start to current point
    fCost = new MinHeap()
    fCost.put heuristic(start), getKey(start) # guess to the end

    loopBody = =>
        # Check if we've exhausted the search space first.
        if not openSet.length
            throw {
                name: "No path found"
                message: "There is no path from the given start node to the end"
            }

        # Find the lowest fCost node to work from.
        while true # As keys are not unique, we have to discard ones that were
                   # added multiple times.
            [currentFCost, currentKey] = fCost.popPair()
            if currentKey of openSet then break
        current = openSet[currentKey]
        
        # If we're already at the endpoint, we can just quit.
        if isEnd(current)
            return reconstructPath current

        # If we have a secondary solver, such as a greedy-based solver, we can
        # use it to try to jump to the end.
        if fastSolver?
            fastSolution = fastSolver current
            if fastSolution.cost <= (currentFCost - gCost[currentKey] + 0.00001)
                return reconstructPath(current).concat fastSolution.path[1..]
        
        openSet.length--
        delete openSet[currentKey]
        closedSet[currentKey] = current

        for neighbor in getNeighbors current
            neighborKey = getKey neighbor
            if neighborKey of closedSet then continue
            tentativeGCost = gCost[currentKey] + distance(current, neighbor)
            if neighborKey not of openSet or \
                                            tentativeGCost <= gCost[neighborKey]
                tentativeFCost = tentativeGCost + heuristic neighbor
                if tentativeFCost > maxFCost then continue
                cameFrom[neighborKey] = current
                gCost[neighborKey] = tentativeGCost
                fCost.put tentativeFCost, neighborKey
                openSet[neighborKey] = neighbor
                openSet.length++
        return undefined

    # Rebuilds the path, given the end node, using a dictionary to see where any
    # arbitrary node came from (`cameFrom`).
    reconstructPath = (current) ->
        path = [current]
        while getKey(current) of cameFrom
            path.unshift(current = cameFrom[getKey current])
        return path

    # If we're doing the async, use the callback and `_.defer`, if we're doing
    # it blocking, loop without stopping and return the result.
    if callback?
        isPaused = false
        loopWrapper = =>
            if isPaused then return
            for i in [0...asyncBlockSize]
                try
                    result = loopBody()
                catch err # Remap thrown errors to the callback.
                    return callback undefined, err
                if result?
                    return callback result
            _.defer loopWrapper # Wait for the stack to clear, don't block.
        _.defer loopWrapper
        # Return the object of control functions for execution control.
        return {
            pause: => isPaused = true
            resume: =>
                if isPaused
                    isPaused = false
                    _.defer loopWrapper
        }
    # The blocking case is much easier to handle...
    else
        while true
            result = loopBody()
            if result? then return result

module.exports = aStar
