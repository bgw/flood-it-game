boardUtil = require "../../src_cs/solver/board.coffee"
_ = require "../../src_cs/underscore-extra.coffee"
require("../jasmine-underscore.coffee")(beforeEach)
BoardData = boardUtil.type

describe "Board size", ->
    it "gives the width or height of a square board.", ->
        expect(boardUtil.getSize(new BoardData 100)).toBe 10

# We'll assume the getPosition family of functions is okay: They're extensively
# implicitly tested via their dependent functions' tests. Besides, they're
# horribly simple functions.

describe "Board hashing", ->
    it "should be unique for every possible input board.", ->
        boardList = []
        for i0 in [0...5]
            for i1 in [0...5]
                for i2 in [0...5]
                    for i3 in [0...5]
                        boardList.push new BoardData [i0, i1, i2, i3]
        hashList = _.map boardList, boardUtil.hash
        expect(hashList).toEqual _.uniq(hashList)
    it "should give a string", ->
        expect(boardUtil.hash(new BoardData 25)).usIsString()

describe "Converting a board to a human-readable string", ->
    board = new BoardData [
        0, 1, 2, 3,
        4, 5, 6, 7,
        8, 9, 0, 1,
        2, 3, 4, 5
    ]
    boardSize = boardUtil.getSize board
    boardString = boardUtil.toString board
    it "should give a string of as many lines as the board has rows", ->
        newlines = _.filter boardString, (character) -> character == "\n"
        expect(newlines.length).toBe boardSize-1 # no ending newline
    it "should have lines of the same length as the board", ->
        expect(boardString.split "\n").usAll (line) -> line.length is boardSize

describe "Parsing a board from a string", ->
    board = [
        0, 1, 2,
        3, 4, 5,
        6, 7, 8
    ]
    it "should parse a board string correctly", ->
        expect(_.toArray boardUtil.parse "012345678").toEqual board
    it "should strip out bad characters", ->
        expect(_.toArray boardUtil.parse "--0*1kbc\n23 456i7_8 ")
            .toEqual board
    it "should be able to parse the result of toString", ->
        expect(_.toArray boardUtil.parse(boardUtil.toString board))
            .toEqual board

describe "Getting the board colors", ->
    board = new BoardData [
        0, 0, 1
        0, 6, 2
        2, 1, 0
    ]
    colors = boardUtil.getColors(board)
    it "will give an array contain one of each color", ->
        expect(colors).toEqual _.uniq(colors)
    it "results in an array of the proper length", ->
        expect(colors.length).toBe 4

describe "Generating a random board", ->
    it "gives a board containing all the specified colors", ->
        expect(boardUtil.getColors(boardUtil.getRandom 5, 25).length).toBe 25
        expect(boardUtil.getColors(boardUtil.getRandom 5, 10).length).toBe 10
    it "checks that there are enough spaces for all the colors", ->
        expect(-> boardUtil.getRandom 5, 26).toThrow()
    it "gives the right-sized board", ->
        expect(boardUtil.getRandom(10).length).toBe 100
        expect(boardUtil.getSize boardUtil.getRandom 10).toBe 10
    it "is a typed array", ->
        expect(boardUtil.getRandom() instanceof BoardData).toBe true
    it "is efficient with tight color constraints", ->
        # Performance should remain O(n)
        expect(boardUtil.getRandom(100, 100*100).length).toBe 100*100

describe "Getting adjacent positions", ->
    board = boardUtil.getRandom 10
    gap = _.bind boardUtil.getAdjacentPositions, @, board
    it "gives two results in a corner", ->
        expect(gap(0).length).toBe 2
        expect(gap(9).length).toBe 2
        expect(gap(90).length).toBe 2
        expect(gap(99).length).toBe 2
    it "gives three results on an edge", ->
        expect(gap(5).length).toBe 3
        expect(gap(50).length).toBe 3
        expect(gap(59).length).toBe 3
        expect(gap(95).length).toBe 3
    it "gives four results in interior positions", ->
        expect(gap(55).length).toBe 4

describe "Getting the position of blobs on the board", ->
    it "gives an array", ->
        expect(_.isArray boardUtil.getBlobPositions boardUtil.getRandom())
            .toBe true
    it "is all positions when the board is filled", ->
        expect(_(boardUtil.getBlobPositions(boardUtil.parse """
            1111
            1111
            1111
            1111
        """)).sortBy(_.identity)).toEqual _.range(16)
    it "is just one position when all blobs are one block in size", ->
        segmentedBoard = boardUtil.parse """
            0123
            4567
            8901
            2345
        """
        for i in [0...segmentedBoard.length]
            expect(boardUtil.getBlobPositions(segmentedBoard, i).length).toBe 1

describe "Playing a color on the board", ->
    it "replaces the color positions in the top-left blob", ->
        boardA = boardUtil.parse """
            0001
            0203
            0455
            0000
        """
        boardB = boardUtil.parse """
            9991
            9293
            9455
            9999
        """
        expect(_.toArray boardUtil.playColor boardA, 9).toEqual _.toArray boardB
    it "should not mutate the passed in board", ->
        board = boardUtil.getRandom(); original = new BoardData(board)
        boardUtil.playColor board, 9
        expect(_.toArray board).toEqual _.toArray original

describe "Finding neighbor boards", ->
    board = boardUtil.getRandom()
    neighbors = boardUtil.getNeighborBoards(board)
    it "is an array of boards", ->
        expect(neighbors).usIsArray()
        expect(neighbors).usAll (n) -> n instanceof BoardData
    it "does not return the passed in board", ->
        expect(neighbors).usAll (n) -> _.isEqual(_.toArray n, _.toArray board)
    it "changes the top-left color", ->
        expect(neighbors).usAll (n) -> n[0] != board[0]
    it "gives only one result when a color could be completely eliminated", ->
        expect(boardUtil.getNeighborBoards(boardUtil.parse """
            0012
            0223
            1332
            1144
        """).length).toBe 1

describe "Computing blob size", ->
    board = boardUtil.parse """
        000
        001
        011
    """
    it "works on a sample board", ->
        expect(boardUtil.getBlobSize board).toBe 6
        expect(boardUtil.getBlobSize board, board.length-1).toBe 3

describe "Manhattan distance", ->
    board = boardUtil.getRandom(10)
    p = _.bind boardUtil.getPosition, @, board
    d = _.bind boardUtil.getDistance, @, board
    it "is the delta x plus the delta y", ->
        expect(d p(0, 0), p(5, 0)).toBe 5
        expect(d p(0, 0), p(0, 5)).toBe 5
        expect(d p(9, 9), p(0, 0)).toBe 18
        expect(d p(4, 6), p(6, 5)).toBe 3

describe "Blob distance", ->
    board = boardUtil.parse """
        0001
        1111
        3114
        1122
    """
    p = _.bind boardUtil.getPosition, @, board
    it "is the direct distance between one-point blobs", ->
        expect(boardUtil.getBlobDistance board, p(0, 2), p(3, 2)).toBe 3
    it "minimizes the distance function", ->
        expect(boardUtil.getBlobDistance board).toBe 3
    it "is zero when the blob is the same", ->
        expect(boardUtil.getBlobDistance board, p(0, 0), p(1, 0)).toBe 0
    it "is one when the blobs are adjacent", ->
        expect(boardUtil.getBlobDistance board, p(0, 0), p(1, 1)).toBe 1

describe "Perimeter blocks", ->
    it "is the adjacent positions in a one-position blob", ->
        board = boardUtil.parse """
            00000
            00000
            00100
            00000
            00000
        """
        p = _.bind boardUtil.getPosition, @, board
        expect(Array::sort.call boardUtil.getPerimeterBlocks(board, p(2, 2)))
            .toEqual Array::sort.call \
                boardUtil.getAdjacentPositions(board, p 2, 2)
    it "is valid for a large blob", ->
        board = boardUtil.parse """
            00100
            01101
            00110
            00000
            02100
        """
        p = _.bind boardUtil.getPosition, @, board
        perimeter = [p(1, 0), p(3, 0), p(0, 1), p(3, 1), p(1, 2), p(4, 2),
                     p(2, 3), p(3, 3)]
        expect(Array::sort.call boardUtil.getPerimeterBlocks board, p(1, 1))
            .toEqual Array::sort.call perimeter

# Generates a board like
#     00000
#     01110
#     01110
#     01110
#     00000
# with a given size.
insetSquareBoard = (bs) ->
    b = new BoardData bs*bs
    for value, position in b
        [x, y] = boardUtil.getPositionPair b, position
        b[position] = Number(_.intersection([x, y], [0, bs-1]).length is 0)
    return b

describe "Perimeter blobs", ->
    it "contains only one element when there is only one surrounding blob", ->
        expect(boardUtil.getPerimeterBlobs(insetSquareBoard(3), 4).length)
            .toBe 1
    it "contains four elements when every position on is a different color", ->
        expect(
            boardUtil.getPerimeterBlobs(boardUtil.getRandom(5, 25), 7).length)
                .toBe 4

describe "Perimeter length", ->
    it "equals zero when the board is filled", ->
        # It must be zero because perimeter blocks cannot be off the board
        for i in [1..20]
            expect(boardUtil.getPerimeter new BoardData i*i).toBe 0
    it "equals 4*(n-2) for an nxn board with a 1-position inset n-1 square", ->
        for bs in [3..20]
            b = insetSquareBoard bs
            expect(boardUtil.getPerimeter b, boardUtil.getPosition(b, 1, 1))
                .toBe 4*(bs-2)
    it "is correct for an arbitrary board with gaps", ->
        board = boardUtil.parse """
            212221
            222321
            002220
            000111
            111111
            222222
        """
        expect(boardUtil.getPerimeter board).toBe 10

describe "Perimeter colors", ->
    it "is an empty list when there is no perimeter", ->
        expect(boardUtil.getPerimeterColors new BoardData 25).toEqual []
    it "is an Array type", ->
        expect(boardUtil.getPerimeterColors insetSquareBoard 5).usIsArray()
    it "are correct when there are multiple colors", ->
        board = boardUtil.parse """
            212221
            222321
            002220
            000111
            111111
            222222
        """
        expect(Array::sort.call boardUtil.getPerimeterColors board)
            .toEqual [0, 1, 3]

describe "Blob is whole", ->
    board = boardUtil.parse """
        012
        122
        222
    """
    it "for any one-position blob", ->
        expect(boardUtil.blobIsWhole board).toBeTruthy()
    it "is valid for a multi-position blob", ->
        expect(boardUtil.blobIsWhole board, 2).toBeTruthy()
    it "gives a false value when the blob is not whole", ->
        expect(boardUtil.blobIsWhole board, 1).toBeFalsy()

describe "Blob counts", ->
    it "has a number of keys equal to the number of blobs", ->
        for i in [1..25]
            b = boardUtil.getRandom 5, i
            expect(_.keys(boardUtil.getBlobCounts b).length).toBe i
    it "has the proper number of keys when the color range has gaps", ->
        board = boardUtil.parse """
            343
            334
            979
        """
        expect(_.keys(boardUtil.getBlobCounts board).length).toBe 4
    it "will total the number of blobs when summed", ->
        for i in [1..25]
            b = boardUtil.getRandom 5, i
            expect(_.sum _.values boardUtil.getBlobCounts b)
                .toBe boardUtil.getNetBlobCount b

describe "Color segmentation", ->
    # In this function we describe racism.
    board = boardUtil.parse """
        0112
        2221
        1111
        3443
    """
    it "exists when each passed color in an arbitary board is split", ->
        expect(boardUtil.areColorsSegmented board, [1, 2, 3]).toBeTruthy()
    it "does not exist when none of the colors are split", ->
        expect(boardUtil.areColorsSegmented board, [0, 4]).toBeFalsy()

describe "A blobified board", ->
    it "has as many colors as there are blobs", ->
        board = boardUtil.getRandom 5, 10
        expect(boardUtil.getColors(boardUtil.getBlobifiedBoard board).length)
            .toBe boardUtil.getNetBlobCount board

describe "Net blob count", ->
    it "gives the number of colors when no color is segmented", ->
        board = boardUtil.getRandom 5, 5*5
        expect(boardUtil.getNetBlobCount board).toBe 25
    it "is one when there is an empty board", ->
        expect(boardUtil.getNetBlobCount new BoardData 25).toBe 1
