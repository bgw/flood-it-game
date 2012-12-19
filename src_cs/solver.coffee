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
    baseGetScore = @admissibleHeuristic startBoard

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
        getKey: ((board) => "solveBoardGreedy#{@boardUtil.hash board}"),
        preferLower: true
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
    blobPositions = _.object(blobs, [0...blobs.length])

    # Returns neighboring blob numbers given a blob number from the blobified
    # board.
    getNeighbors = (blob) =>
        return _.chain(@boardUtil.getPerimeterBlocks startBoard,
                                                     blobPositions[blob])
            .map((p) => blobs[p]).uniq().value()

    mesh = @getNavigationMesh blobs[finalPosition], getNeighbors
    return (position) ->
        return (blobPositions[i] for i in mesh(blobs[position]))

# Forms navigation meshes from every blob to every other blob. Then, when
# calling the mesh, given a set of positions, it tries to find the best
# admissible guess possible.
solver.admissibleHeuristic = _.simpleLruCache (startBoard) ->
    # Form a list of all the blobs to visit on the board
    boardSize = @boardUtil.getSize startBoard
    targetPositions = [
        boardSize - 1
        boardSize * (boardSize-1)
        boardSize * boardSize - 1
    ]
    meshes = []
    for target in targetPositions
        meshes[target] = @getPositionMesh startBoard, target

    return (currentBoard) =>
        # Only test with blobs around the perimeter.
        testFrom = @boardUtil.getPerimeterBlobs currentBoard
        if testFrom.length is 0 then return 0 # board is filled
        # Only try to navigate to blobs away from the top-left blob.
        testTo = _.difference targetPositions,
                              @boardUtil.getBlobPositions(currentBoard)
        # Used later in computations, pulled outside the loop.
        topLeftIsWhole = @boardUtil.blobIsWhole currentBoard
        
        longestMinpath = @boardUtil.getColors(currentBoard).length
        if topLeftIsWhole then longestMinpath--
        # Try to find a longer path
        for to in testTo
            minimumPathLength = Infinity
            for from in testFrom
                path = meshes[to](from)
                unhandledColorCount = _.difference(
                    @boardUtil.getColors(currentBoard),
                    (currentBoard[position] for position in path),
                    (if topLeftIsWhole then [currentBoard[0]] else [])
                ).length
                pathLength = path.length + \ # the base cost
                             1 + \ # since we started on the outside perimeter
                             unhandledColorCount
                minimumPathLength = Math.min pathLength, minimumPathLength
            # Find the target requiring the longest path
            longestMinpath = Math.max minimumPathLength, longestMinpath
        return longestMinpath

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
solver.solveBoard = (startBoard=@boardUtil.getRandom(),
                     {admissible, callback}={}) ->
    admissible ?= false
    
    admissibleHeuristic = @admissibleHeuristic startBoard
    nonAdmissibleHeuristic = (board) =>
        # As great as our admissible heuristics are, performance is still not
        # good enough for a 14x14 board, especially as they only help near the
        # endgame. Therefore, we use a few multipliers on the admissable
        # heuristic to make the aStar algorithm more likely to skip bad paths.
        return 10 * admissibleHeuristic(board) + \
               0.01 * (board.length - @boardUtil.getBlobSize board)
    
    heuristic = (if admissible then admissibleHeuristic \
                               else nonAdmissibleHeuristic)

    return @aStar(
        startBoard,
        ((board) => @boardUtil.getColors(board).length == 1),
        @boardUtil.getNeighborBoards,
        ((boardA, boardB) => 1),
        heuristic: heuristic,
        getKey: @boardUtil.hash,
        callback: callback
    )

# Makes `this.` and `@` work relative to solver for all solver function, as
# would be expected.
_.bindAll solver

# Run some tests if we're run from the command line
if module is require.main
    # Generate our test board
    startBoard = solver.board.getRandom 14
    
    # Test the greedy search
    greedyLength = solver.solveBoardGreedy(startBoard).length - 1
    console.log "Greedy Algorithm: #{greedyLength}"

    meshLength = solver.getPositionMesh(startBoard)(0).length - 1
    console.log "Mesh Algorithm: #{meshLength}"

    # Test the aStar search
    aStarLength = solver.solveBoard(startBoard).length - 1
    console.log "aStar Algorithm: #{aStarLength}"
