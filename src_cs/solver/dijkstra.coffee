# Generates and consumes navigation meshes, speeding up repeated calls. This
# isn't exactly dijkstra's algorithm, especially as we're exploring the entire
# search space, but it is clearly derived.

_ = require "../underscore-extra.coffee"
MinHeap = require "./minheap.coffee"

getFullGraph = (start, getNeighbors, {getKey}={}) ->
    getKey ?= _.identity
    graph = {}
    queue = [start]
    while queue.length
        node = queue.pop()
        for neighbor in getNeighbors node
            if getKey neighbor not of graph
                graph[getKey neighbor] = neighbor
                queue.unshift neighbor
    return _.values graph

# Explore the entire mesh given a starting point. Takes about O(n^2) time, where
# n is the number of nodes on the graph.
getNavigationMesh = (start, getNeighbors, distance=(->1), {getKey}={}) ->
    getKey ?= _.identity
    fullGraph = getFullGraph(start, getNeighbors, {getKey: getKey})

    cameFrom = {}
    minDistSorted = new MinHeap(); minDistSorted.put 0, start
    minDist = {}
    for node in fullGraph
        cost = (if node is start then 0 else Infinity)
        minDist[getKey node] = cost

    while minDistSorted.length
        while true
            [nodeDist, node] = minDistSorted.popPair()
            if nodeDist == minDist[getKey node] then break

        # Normally for Dijkstra's we'd check to see if the node is infinite
        # cost, but generate the queue by iterating over the graph ourselves, we
        # already have stripped out unreachable nodes.
        for neighbor in getNeighbors node
            altNeighborDist = nodeDist + distance node, neighbor
            if altNeighborDist < minDist[getKey neighbor]
                cameFrom[getKey neighbor] = node
                minDist[getKey neighbor] = altNeighborDist
                minDistSorted.put altNeighborDist, neighbor

    # We return a function that you can call with an endpoint to get a path,
    # using the navigation mesh for O(n) time, where n is the length of the
    # path.
    return do (getKey, cameFrom) ->
        (end) ->
            path = [end]
            current = end
            while getKey(current) of cameFrom
                path.unshift(current = cameFrom[getKey current])
            return path

module.exports = getNavigationMesh
