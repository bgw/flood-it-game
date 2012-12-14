# Various utility functions for dealing with a board. These are all very tiny
# functions without side effects (beyond caching) which are handy in the solver,
# but aren't directly related to the problem of solving the board.

_ = require "../underscore-extra.coffee"
module.exports = boardUtil = {}

# Given a board, returns the width/height of it. The total number of elements on
# the board can be found with `board.length`.
boardUtil.getSize = (b) -> Math.sqrt b.length

# Converts an x, y pair into a position value, where x an y are offsets from the
# top-left corner. They are converted with the formula: x + y * boardSize
boardUtil.getPosition = (b, x, y) -> x + y * @getSize b

# Used wherever we need to put a board into a dictionary (object), as object
# keys must be strings. Not designed to be human readable, just computer-usable.
boardUtil.hash = _.simpleLruCache (b) -> String.fromCharCode(b...)

# Used for debugging, pretty-prints the board and returns a string.
boardUtil.toString = boardUtil.getString = (b) ->
    lines = []
    size = @getSize b
    for r in [0...size]
        lines[r] = ""
        for c in [0...size]
            lines[r] += b[r*size + c]
    return lines.join "\n"

# Takes a multi-line string and turns it into a board. This is useful for
# debugging.
boardUtil.parse = (boardString) ->
    boardString = boardString.replace /\D/g, "" # We only want digits left
    return new @type(parseInt(color, 10) for color in boardString)

# Gives the set of all colors on a given board. Colors are given as an array of
# integers.
boardUtil.getColors = _.simpleLruCache _.uniq

# Generates a random board with a given width/height and number of colors.
# Traditionally this means a 14x14 board with 6 colors.
boardUtil.getRandom = (size=14, colorCount=6) ->
    if size*size < colorCount
        throw {
            name: "Board too small",
            message: "The given size=#{size} is too small to contain all " + \
                     "the colors desired."
        }
    # Generate the array in two parts: (1) generate the range so that each color
    # will show up at least once, and (2) generate random colors to fill up the
    # rest of the space.
    #
    # We then shuffle the result, so we don't have an ordered list at the
    # beginning.
    return new @type _.shuffle _.range(colorCount).concat(
        _.random(0, colorCount) for i in [0...size*size - colorCount]
    )

# Gets the positions on the board next to a given position. Is called
# practically everywhere in the heuristic and cost functions. We use a lookup
# table to make things as fast as possible (I don't know how much this actually
# does unfortunately). Returns a list.
boardUtil.getAdjacentPositions = (b, position) ->
    data = []
    [bs, p] = [@getSize(b), position]
    if p % bs > 0        then data.push p - 1  # left
    if p % bs < bs - 1   then data.push p + 1  # right
    if p >= bs           then data.push p - bs # up
    if p < bs * (bs - 1) then data.push p + bs # down
    return data

# Returns an array of every position in a given blob on the board.
boardUtil.getBlobPositions = (board, startPosition=0) ->
    evaluated = new @type board.length
    boardSize = @getSize board
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
boardUtil.playColor = (board, color) ->
    if color == board[0] then return board
    nextBoard = new @type board
    for position in @getBlobPositions board
        nextBoard[position] = color
    return nextBoard

# Plays each color in the perimeter, and then returns the list. The amount of
# neighbors returned affects the branching factor.
boardUtil.getNeighborBoards = (board) ->
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
boardUtil.getBlobSize = _.lruCache(((board, position=0) ->
    return boardUtil.hash(board) + position
), 100, (args...) ->
    return @getBlobPositions(args...).length
)

# Computes and returns the manhattan distance between two points (not blobs).
# Manhattan distance is `abs(deltaX) + abs(deltaY)`, not
# `sqrt(deltaX^2 + deltaY^2)`.
boardUtil.getDistance = (board, positionA, positionB) ->
    bs = @getSize board
    [aX, bX] = [positionA % bs, positionB % bs]
    [aY, bY] = [Math.floor(positionA / bs), Math.floor(positionB / bs)]
    return Math.abs(aX-bX) + Math.abs(aY-bY)

# Returns the minimum manhattan distance between two blobs specified by
# positions in the blobs
boardUtil.getBlobDistance = (board, positionA=0, positionB=board.length-1) ->
    blobA = @getBlobPositions board, positionA
    if _(blobA).contains(positionB) then return 0 # the same blob
    blobB = @getBlobPositions board, positionB
    
    return _.chain(blobA)
        # Compare every position in blobA with every position in blobB
        .map((a) => _.min _.map blobB, (b) => @getDistance(board, a, b))
        .min().value()

# Returns an array of the blocks forming the perimeter around the *outside* of
# the blob containing the passed position. No blocks in the blob are given.
boardUtil.getPerimeterBlocks = _.simpleLruCache (board, position=0) ->
    blobBlocks = @getBlobPositions board, position
    # Find adjacent blocks to expand the blob out
    adjacencyList = _.chain(blobBlocks)
        .map((adjacent) => @getAdjacentPositions board, adjacent)
        # Merge all adjacency lists
        .flatten(1)
        .uniq()
        .value()
    # Remove the current blob from the adjacencyList, leaving only the outside
    perimeterBlocks = _(adjacencyList)
        .reject((adjacent) => board[adjacent] == board[position])
    return perimeterBlocks

# Returns the number of blocks outside of the blob directly touching the blob.
# Typically the larger the perimeter, the more blocks we can collect on our next
# turn.
boardUtil.getPerimeter = _.simpleLruCache (args...) ->
    return @getPerimeterBlocks(args...).length

# Returns an array of the different colors on the perimeter of the top-left
# blob. This is useful for figuring out how to branch, because it only makes
# sense to play colors that we're touching.
boardUtil.getPerimeterColors = _.simpleLruCache (board, args...) ->
    return _.chain(@getPerimeterBlocks board, args...)
        .map((position) => board[position])
        .uniq()
        .value()

# Returns true if a blob at a given position contains all of the given color. In
# the case of the top-left blob, we can use this function to see if the current
# color has been cleared on not.
boardUtil.blobIsWhole = (board, position=0) ->
    blobColor = board[position]
    return _.chain([0...board.length])
        # Remove all the positions that are in the blob.
        .difference(@getBlobPositions board, position)
        # Check that there are no instances of the color outside the blob.
        .all((outerPosition) => board[outerPosition] != blobColor)
        .value()

# Returns an object of {color: numberOfBlobs}.
boardUtil.getBlobCounts = (board) ->
    return _.chain(@getBlobifiedBoard board)
        # Rewrite into {blobNumber: color}.
        .object(board)
        # There's only one value for each blob. Count them.
        .values().countBy(_.identity)
        .value()

# Returns if all given colors are contained in multiple blobs (are segmented).
# If no colors are given, it assumes all colors currently on the board instead.
boardUtil.allBlobsSegmented = (board, colors=@getColors(board)) ->
    return _.chain(@getBlobCounts board)
        # We only care about the colors we were passed
        .pick(colors...)
        # Check that each color has more than one blob.
        .values()
        .all((count) -> count > 1)
        .value()

# Returns a board with one color for each blob, meaning that all positions of
# the same color value will be in the same blob.
boardUtil.getBlobifiedBoard = (board) ->
    blobs = new Uint16Array board.length
    blobNumber = 1
    for position in [0...board.length]
        if not blobs[position]
            for subPosition in @getBlobPositions board, position
                blobs[subPosition] = blobNumber
            blobNumber++
    return blobs

# Ensure `this` or `@` acts like we expect it to (pointing to boardUtil)
_.bindAll boardUtil

# Provides a shim replacement for Uint8Array on browsers that don't support it.
# Performance will be ultra crappy though. (This isn't even a real Array,
# because it can't be properly subclassed)
boardUtil.lookalikeType = class Uint8ArrayFallback
    BYTES_PER_ELEMENT = 1
    constructor: (value=0) ->
        if _.isNumber value
            @[i] = 0 for i in [0...value]
            @length = value
        else if value?
            @[i] = v for v, i in value
            @length = value.length
        @byteLength = @length * @BYTES_PER_ELEMENT
        @byteOffset = 0
        @buffer = @

    set: (array, offset) ->
        for v, i in array
            @[offset+i] = v

    slice: (start=0, end=@length) ->
        start = _.clamp start, 0, @length
        end = _.clamp end, 0, @length
        newData = []
        for i in [start...end]
            newData.push @[i]
        return new Uint8ArrayFallback newData

# Define our basic datatype
if Uint8Array
    boardUtil.type = Uint8Array
else
    boardUtil.type = boardUtil.fallbackType

# Forcing a fallback is useful for testing.
boardUtil.forceTypeFallback = -> boardUtil.type = boardUtil.fallbackType
