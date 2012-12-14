# This file contains a (decently) fast algorithm for solving a given flood-it
# board. The implementation is largely functional in design. We prefer
# functional wrappers and transformations over more code. This can be used to
# determine difficulty of a game board, or to make variants of the game, where
# you play against the AI.
#
# Every instance of the board in the AI implementation is a Uint8Array of length
# width*height, where width = height because boards are square. Each element is
# an integer representing the color in that square. Indexes are marked by the
# equation `row * getSize(board) + col`

_ = require "./underscore-extra.coffee"
module.exports = solver = {
    aStar: require "./solver/astar.coffee"
    greedySolver: require "./solver/greedy.coffee"
    getNavigationMesh: require "./solver/dijkstra.coffee"
    board: require "./solver/board.coffee"
}
solver.boardUtil = solver.board

solver.solveBoardGreedy = (startBoard=@boardUtil.getRandom(), lookAhead=0) ->
    baseGetScore = (board) => @boardUtil.getBlobSize board

    getScore = (board, lookAheadLeft=lookAhead) =>
        score = baseGetScore board
        if lookAheadLeft
            neighbors = @boardUtil.getNeighborBoards board
            if neighbors.length < 2 then return score
            lookAheadLeft--
            score += Math.min (
                getScore(b, lookAheadLeft) for b in neighbors
            )...
        return score

    return @greedySolver(
        startBoard,
        ((board) => @boardUtil.getColors(board).length == 1),
        @boardUtil.getNeighborBoards,
        getScore,
        {getKey: ((board) => "solveBoardGreedy#{@boardUtil.hash board}")}
    )

# Uses `solver.aStar` to try to find the number of moves needed to get to the
# bottom right corner, often the hardest-to-access point. This can be used to
# help form an admissable heuristic if it is itself solved optimally. It remains
# admissible, because the bottom-right corner must be turned regardless.
solver.solveBottomRight = (startBoard=@boardUtil.getRandom(),
                           {multiplier, callback}={}) ->
    multiplier ?= 2.0
    heuristic = (board) => @boardUtil.getBlobDistance(board) * multiplier
    return solver.aStar(
        startBoard,
        ((board) => board.length-1 in @boardUtil.getBlobPositions(board)),
        @boardUtil.getNeighborBoards,
        (->1),
        {
            heuristic: heuristic,
            getKey: @boardUtil.hash,
            callback: callback
        }
    )


solver.solveBottomRightGreedy = (startBoard=@boardUtil.getRandom(),
                                 {multiplier, callback}={}) ->
    score = (board) => @boardUtil.getBlobDistance(board)
    return solver.greedySolver(
        startBoard,
        ((board) => board.length-1 in @boardUtil.getBlobPositions(board)),
        @boardUtil.getNeighborBoards,
        score,
        {
            preferLower: yes
            getKey:((board) => "solveBottomRightGreedy#{@boardUtil.hash board}")
        }
    )

# Given a board and a position, computes a navigation mesh from any arbitrary
# position to a given endpoint. The returned function, when called, will compute
# and return the shortest possible sequence of positions that must be conqured
# to get the the mesh's endpoint from the given start-point.
#
# This doesn't make sense for much other than as an admissible heuristic.
solver.getPositionMesh = (startBoard=@boardUtil.getRandom(),
                          finalPosition=startBoard.length-1) ->
    blobs = @boardUtil.getBlobifiedBoard startBoard
    blobPositions = _.object(_.values(blobs), [0...blobs.length])

    # Returns neighboring blob numbers given a blob number from the blobified
    # board.
    getNeighbors = (blob) =>
        return _.chain(@boardUtil.getPerimeterBlocks startBoard,
                                                     blobPositions[blob])
            .map((p) => blobs[p]).uniq().value()

    mesh = @getNavigationMesh blobs[finalPosition], getNeighbors
    return (position) -> (blobPositions[i] for i in mesh(blobs[position]))

# Given a board and a list of positions, computes all the navigation meshes for
# each position. Upon being called with a position, it gives the furthest path
# from the given point that exists.
solver.getMaxPositionMesh = (startBoard=@boardUtil.getRandom(),
                             finalPositions=[]) ->
    # rewrite finalPositions so that we only get one position per blob (the
    # results will always be the same within blobs)
    blobs = @boardUtil.getBlobifiedBoard startBoard
    finalPositions = _.chain(finalPositions)
        # Group each position into its owning blob
        .groupBy((p) -> blobs[p])
        .values()
        # Pick the first one that we found in each blob and just use that
        .pluck(0)
        .value()
    
    # compute the submeshes
    meshList = (@getNavigationMesh(startBoard, p) for p in finalPositions)

    # write the getter function
    return (position) ->
        return _.chain(meshList)
            # Find the paths to each point
            .map((m) -> m position)
            # Return the longest one found
            .max((path) -> path.length)

# Uses `solver.aStar` to solve a flood-it board minimally. The heuristic is
# admissible, but with a multiplier that makes it non-admissible. For a small
# board multiplier may be 1, guaranteeing an optimal solution, but as flood-it
# is an NP-Hard problem, for any moderately sized board, the multiplier should
# be slightly greater than 1, so that you are not stuck forever waiting for a
# solution.
#
# The return value consists of all the board states, from beginning to end,
# including the starting state. `solver.solveBoardMoves` will simply give an
# array of the moves to make as a list of integers. If a callback is given, it
# is simply passed to `solver.aStar`, and will act as expected.
solver.solveBoard = (startBoard=@boardUtil.getRandom(), {admissible, multiplier,
                     callback, acceptableBadness}={}) ->
    admissible ?= false
    multiplier ?= .5
    acceptableBadness ?= 1
    
    hardPositions = [
        startBoard.length - 1
        @boardUtil.getSize(startBoard) - 1
        startBoard.length - @boardUtil.getSize(startBoard)
    ]
    #hardPositions = [0...startBoard.length-1]
    
    meshScores = []
    
    for hardPosition in hardPositions
        mesh = @getPositionMesh(startBoard, hardPosition)
        meshScores.push scores = new Uint16Array startBoard.length
        for i in [0...startBoard.length]
            score = mesh(i).length - 1
            if scores[i] < score then scores[i] = score

    logLowest = Infinity
    # The magical aStar heuristic function. The closer this is to the actual
    # cost without going over, the faster the function will go! (With pretty big
    # dividends as we approach a perfect function)
    #
    # It should never return a negative number, as neither should the cost
    # function.
    admissibleHeuristic = (board) =>
        # We have to make at least as many moves as there are colors (minus
        # one, because that color could be only in the top-left blob)
        colorsLeft = @boardUtil.getColors(board).length
        # But, if it isn't *just* in the top-left blob, then we know that we
        # must make `n`, not `n-1` moves to clear the board.
        isWhole = @boardUtil.blobIsWhole board
        # Additionally, if none of the blobs in our perimeter are an entire
        # blob, after our next move, we won't have decreased the number of
        # colors in play, so we can say that we need at least one additional
        # move after that to start clearing off colors completely.
        isSegmented = @boardUtil.allBlobsSegmented board,
                                            @boardUtil.getPerimeterColors(board)
        # Our mesh is handy, let's find the positions for which we have data
        localHardPositions = _.intersection(hardPositions,
                                            @boardUtil.getBlobPositions board)
        return Math.max(
            colorsLeft - (if isWhole then 1 else 0) +
            (if isSegmented then 1 else 0),
            _.max(
                _.min(score[p] for p in localHardPositions) \
                for score in meshScores
            )
        )

    nonAdmissibleHeuristic = (board) =>
        # As great as our admissible heuristics are, performance is still not
        # good enough for a 14x14 board, especially as they only help near the
        # endgame. A greedy solution is really fast, and can predict the
        # remaining number of moves decently.
        greedyScore = @solveBoardGreedy(board).length - 1
        r = Math.max(
            greedyScore * multiplier,
            admissibleHeuristic(board) + greedyScore * 0.05
        )
        if logLowest > r
            logLowest = r
            console.log r
        return r
    
    heuristic = (if admissible then admissibleHeuristic \
                               else nonAdmissibleHeuristic)

    fastSolver = (board) =>
        solution = @solveBoardGreedy board
        return {cost: solution.length-1-acceptableBadness, path: solution}

    return @aStar(
        startBoard,
        ((board) => @boardUtil.getColors(board).length == 1),
        @boardUtil.getNeighborBoards,
        ((boardA, boardB) => 1),
        {
            heuristic: heuristic,
            fastSolver: fastSolver,
            getKey: @boardUtil.hash,
            callback: callback
        }
    )

# Makes `this.` and `@` work relative to solver for all solver function, as
# would be expected.
_.bindAll solver

# Run some tests if we're run from the command line
if module is require.main
    # Generate our test board
    startBoard = solver.board.getRandom 10
    
    # Test the greedy search
    greedyLength = solver.solveBoardGreedy(startBoard).length - 1
    console.log "Greedy Algorithm: #{greedyLength}"

    meshLength = solver.getPositionMesh(startBoard)(0).length - 1
    console.log "Mesh Algorithm: #{meshLength}"

    # Test the aStar search
    aStarLength = solver.solveBoard(startBoard).length - 1
    console.log "aStar Algorithm: #{aStarLength}"
