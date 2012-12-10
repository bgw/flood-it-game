# This file contains a (decently) fast algorithm for solving a given flood-it
# board. The implementation is largely functional in design. We prefer
# functional wrappers and transformations over more code. This can be used to
# determine difficulty of a game board, or to make variants of the game, where
# you play against the AI.
#
# Every instance of the board in the AI implementation is a Uint8Array of length
# width*height, where width = height because boards are square. Each element is
# an integer representing the color in that square. Indexes are marked by the
# equation `row * getBoardSize(board) + col`

_ = require "./underscore-extra.coffee"
module.exports = solver = {
    aStar: require "./solver/astar.coffee"
    greedySolver: require "./solver/greedy.coffee"
    getNavigationMesh: require "./solver/dijkstra.coffee"
}

# Given a board, returns the width/height of it. The total number of elements on
# the board can be found with `board.length`.
solver.getBoardSize = (board) -> Math.sqrt board.length

# Converts an x, y pair into a position value, where x an y are offsets from the
# top-left corner. They are converted with the formula: x + y * boardSize
solver.getBoardPosition = (board, x, y) -> x + y * @getBoardSize board

# Used wherever we need to put a board into a dictionary (object), as object
# keys must be strings. Not designed to be human readable, just computer-usable.
solver.boardHash = _.simpleLruCache (b) -> String.fromCharCode(b...)

# Used for debugging, pretty-prints the board and returns a string.
solver.getBoardString = (board) ->
    lines = []
    boardSize = @getBoardSize board
    for r in [0...boardSize]
        lines[r] = ""
        for c in [0...boardSize]
            lines[r] += board[r*boardSize + c]
    return lines.join "\n"

# Takes a multi-line string and turns it into a board. This is useful for
# debugging.
solver.parseBoard = (boardString) ->
    boardString = boardString.replace /\D/g, "" # We only want digits left
    board = new Uint8Array boardString.length
    for color, i in boardString
        board[i] = parseInt color, 10
    return board

# Gives the set of all colors on a given board. Colors are given as an array of
# integers.
solver.getColors = _.simpleLruCache _.uniq

# Generates a random board with a given width/height and number of colors.
# Traditionally this means a 14x14 board with 6 colors.
solver.getRandomBoard = (boardSize=14, colorCount=6) ->
    if boardSize*boardSize < colorCount
        throw {
            name: "Board too small",
            message: "The given boardSize=#{boardSize} is too small to " +
                     "contain all the colors desired."
        }
    # Generate the array in two parts: (1) generate the range so that each color
    # will show up at least once, and (2) generate random colors to fill up the
    # rest of the space.
    #
    # We then shuffle the result, so we don't have an ordered list at the
    # beginning.
    return new Uint8Array _.shuffle _.range(colorCount).concat(
        _.random(0, colorCount) for i in [0...boardSize*boardSize - colorCount]
    )

# Gets the positions on the board next to a given position. Is called
# practically everywhere in the heuristic and cost functions. We use a lookup
# table to make things as fast as possible (I don't know how much this actually
# does unfortunately). Returns a list.
solver.getAdjacentPositions = (board, position) ->
    data = []
    [bs, p] = [@getBoardSize(board), position]
    if p % bs > 0        then data.push p - 1  # left
    if p % bs < bs - 1   then data.push p + 1  # right
    if p >= bs           then data.push p - bs # up
    if p < bs * (bs - 1) then data.push p + bs # down
    return data

# Returns an array of every position in a given blob on the board.
solver.getBlobPositions = (board, startPosition=0) ->
    evaluated = new Uint8Array board.length
    boardSize = @getBoardSize board
    stack = [startPosition]
    blocks = []
    baseColor = board[startPosition]
    while stack.length
        position = stack.pop()
        if evaluated[position] then continue
        if board[position] != baseColor then continue
        blocks.push position
        evaluated[position] = 1
        stack[stack.length..] = @getAdjacentPositions board, position
    return blocks

# Flood-fills the board starting from the top left corner with another color,
# returning a new board with the color changed for the player's blob.
solver.playColor = (board, color) ->
    if color == board[0] then return board
    nextBoard = new Uint8Array board
    for position in @getBlobPositions board
        nextBoard[position] = color
    return nextBoard

# Plays each color in the perimeter, and then returns the list. The amount of
# neighbors returned affects the branching factor.
solver.getNeighborBoards = (board) ->
    boardList = []
    for color in @getPerimeterColors board
        nextBoard = @playColor board, color
        # If we have a board that completely eliminates a color, then the
        # only good boards are those of the current set that also eliminate
        # a color entirely. To take this a step further, if there were multiple
        # eliminating moves, it doesn't matter what one we pick first, because
        # we're going to going to eventually play all of them if this strategy
        # is repeated iteratively, and the end result will always be equivalent.
        if @blobIsWhole nextBoard then return [nextBoard]
        boardList.push nextBoard
    return boardList

# Counts the number of squares in the top-left blob.
solver.getBlobSize = _.lruCache(((board, position=0) ->
    return solver.boardHash(board) + position
), 100, (args...) ->
    return @getBlobPositions(args...).length
)

# Computes and returns the manhattan distance between two points (not blobs).
solver.getDistance = (board, positionA, positionB) ->
    bs = @getBoardSize board
    [aX, bX] = [positionA % bs, positionB % bs]
    [aY, bY] = [Math.floor(positionA / bs), Math.floor(positionB / bs)]
    return Math.abs(aX-bX) + Math.abs(aY-bY)

# Returns the minimum manhattan distance between two blobs specified by
# positions in the blobs
solver.getBlobDistance = (board, positionA=0, positionB=board.length-1) ->
    blobA = @getBlobPositions board, positionA
    if _(blobA).contains(positionB) then return 0 # the same blob
    blobB = @getBlobPositions board, positionB
    
    return _.chain(blobA)
        # Compare every position in blobA with every position in blobB
        .map((a) => _.min _.map blobB, (b) => @getDistance(board, a, b))
        .min().value()

# Returns an array of the blocks forming the perimeter around the blob
# containing the passed position. This is the outer perimeter: no blocks from
# the inside of the blob are counted.
solver.getPerimeterBlocks = _.simpleLruCache (board, position=0) ->
    blobBlocks = @getBlobPositions board, position
    # Find adjacent blocks to expand the blob out
    adjacencyList = _.chain(blobBlocks)
        .map((adjacent) => @getAdjacentPositions board, adjacent)
        .flatten(1)
        .uniq()
        .value()
    # Remove the blob from the adjacencyList, leaving only the perimeter
    perimeterBlocks = _(adjacencyList)
        .reject((adjacent) => board[adjacent] == board[position])
    return perimeterBlocks

# Returns the number of blocks outside of the blob directly touching the blob.
# Typically the larger the perimeter, the more blocks we can collect on our next
# turn.
solver.getPerimeter = _.simpleLruCache (args...) ->
    return @getPerimeterBlocks(args...).length

# Returns an array of the different colors on the perimeter of the top-left
# blob. This is useful for figuring out how to branch, because it only makes
# sense to play colors that we're touching.
solver.getPerimeterColors = _.simpleLruCache (board, args...) ->
    return _.chain(@getPerimeterBlocks board, args...)
        .map((position) => board[position])
        .uniq()
        .value()

# Returns true if a blob at a given position contains all of the given color. In
# the case of the top-left blob, we can use this function to see if the current
# color has been cleared on not.
solver.blobIsWhole = (board, position=0) ->
    blobColor = board[position]
    return _.chain([0...board.length])
        # Remove all the positions that are in the blob.
        .difference(@getBlobPositions board, position)
        # Check that there are no instances of the color outside the blob.
        .all((outerPosition) => board[outerPosition] != blobColor)
        .value()

# Returns an object of {color: numberOfBlobs}.
solver.getBlobCounts = (board) ->
    return _.chain(@getBlobifiedBoard board)
        # Rewrite into {blobNumber: color}.
        .object(board)
        # There's only one value for each blob. Count them.
        .values().countBy(_.identity)
        .value()

# Returns if all given colors are contained in multiple blobs (are segmented).
# If no colors are given, it assumes all colors currently on the board instead.
solver.allBlobsSegmented = (board, colors=@getColors(board)) ->
    return _.chain(@getBlobCounts board)
        # We only care about the colors we were passed
        .pick(colors...)
        # Check that each color has more than one blob.
        .values()
        .all((count) -> count > 1)
        .value()

solver.getBlobifiedBoard = (board) ->
    blobs = new Uint16Array board.length
    blobNumber = 1
    for position in [0...board.length]
        if not blobs[position]
            for subPosition in @getBlobPositions board, position
                blobs[subPosition] = blobNumber
            blobNumber++
    return blobs

solver.solveBoardGreedy = (startBoard=@getRandomBoard(), lookAhead=0) ->
    baseGetScore = (board) => @getBlobSize board

    getScore = (board, lookAheadLeft=lookAhead) =>
        score = baseGetScore board
        if lookAheadLeft
            neighbors = @getNeighborBoards board
            if neighbors.length < 2 then return score
            lookAheadLeft--
            score += Math.min (
                getScore(b, lookAheadLeft) for b in neighbors
            )...
        return score

    return @greedySolver(
        startBoard,
        ((board) => @getColors(board).length == 1),
        @getNeighborBoards,
        getScore,
        {getKey: ((board) => "solveBoardGreedy#{@boardHash board}")}
    )

# Uses `solver.aStar` to try to find the number of moves needed to get to the
# bottom right corner, often the hardest-to-access point. This can be used to
# help form an admissable heuristic if it is itself solved optimally. It remains
# admissible, because the bottom-right corner must be turned regardless.
solver.solveBottomRight = (startBoard=@getRandomBoard(),
                           {multiplier, callback}={}) ->
    multiplier ?= 2.0
    heuristic = (board) => @getBlobDistance(board) * multiplier
    return solver.aStar(
        startBoard,
        ((board) => board.length-1 in @getBlobPositions(board)),
        @getNeighborBoards,
        (->1),
        {
            heuristic: heuristic,
            getKey: @boardHash,
            callback: callback
        }
    )


solver.solveBottomRightGreedy = (startBoard=@getRandomBoard(),
                                 {multiplier, callback}={}) ->
    score = (board) => @getBlobDistance(board)
    return solver.greedySolver(
        startBoard,
        ((board) => board.length-1 in @getBlobPositions(board)),
        @getNeighborBoards,
        score,
        {
            preferLower: true
            getKey: ((board) => "solveBottomRightGreedy#{@boardHash board}")
        }
    )

# Given a board and a position, computes a navigation mesh from any arbitrary
# position to a given endpoint. The returned function, when called, will compute
# and return the shortest possible sequence of positions that must be conqured
# to get the the mesh's endpoint from the given start-point.
#
# This doesn't make sense for much other than as an admissible heuristic.
solver.getPositionMesh = (startBoard=@getRandomBoard(),
                          finalPosition=startBoard.length-1) ->
    blobs = @getBlobifiedBoard startBoard
    blobPositions = _.object(_.values(blobs), [0...blobs.length])

    # Returns neighboring blob numbers given a blob number from the blobified
    # board.
    getNeighbors = (blob) =>
        return _.chain(@getPerimeterBlocks startBoard, blobPositions[blob])
            .map((p) => blobs[p]).uniq().value()

    mesh = @getNavigationMesh blobs[finalPosition], getNeighbors
    return (position) -> (blobPositions[i] for i in mesh(blobs[position]))

# Given a board and a list of positions, computes all the navigation meshes for
# each position. Upon being called with a position, it gives the furthest path
# from the given point that exists.
solver.getMaxPositionMesh = (startBoard=@getRandomBoard(), finalPositions=[]) ->
    # rewrite finalPositions so that we only get one position per blob (the
    # results will always be the same within blobs)
    blobs = @getBlobifiedBoard startBoard
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
solver.solveBoard = (startBoard=@getRandomBoard(), {admissible, multiplier,
                     callback, acceptableBadness}={}) ->
    admissible ?= false
    multiplier ?= .5
    acceptableBadness ?= 1
    
    hardPositions = [
        startBoard.length - 1
        @getBoardSize(startBoard) - 1
        startBoard.length - @getBoardSize(startBoard)
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
        colorsLeft = @getColors(board).length
        # But, if it isn't *just* in the top-left blob, then we know that we
        # must make n, not n-1 moves to clear the board.
        isWhole = @blobIsWhole board
        # Additionally, if none of the blobs in our perimeter are an entire
        # blob, after our next move, we won't have decreased the number of
        # colors in play, so we can say that we need at least one additional
        # move after that to start clearing off colors completely.
        isSegmented = @allBlobsSegmented board, @getPerimeterColors(board)
        # Our mesh is handy, let's find the positions for which we have data
        localHardPositions = _.intersection(hardPositions,
                                            @getBlobPositions board)
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
        ((board) => @getColors(board).length == 1),
        @getNeighborBoards,
        ((boardA, boardB) => 1),
        {
            heuristic: heuristic,
            fastSolver: fastSolver,
            getKey: @boardHash,
            callback: callback
        }
    )

# Makes `this.` and `@` work relative to solver for all solver function, as
# would be expected.
_.bindAll(solver)

# Run some tests if we're run from the command line
if not module.parent?
    # Generate our test board
    startBoard = solver.getRandomBoard 10
    
    # Test the greedy search
    greedyLength = solver.solveBoardGreedy(startBoard).length - 1
    console.log "Greedy Algorithm: #{greedyLength}"

    meshLength = solver.getPositionMesh(startBoard)(0).length - 1
    console.log "Mesh Algorithm: #{meshLength}"

    # Test the aStar search
    aStarLength = solver.solveBoard(startBoard).length - 1
    console.log "aStar Algorithm: #{aStarLength}"
