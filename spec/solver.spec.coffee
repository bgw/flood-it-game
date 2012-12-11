solver = require "../src_cs/solver.coffee"
_ = require "../src_cs/underscore-extra.coffee"
require("./jasmine-underscore.coffee")(beforeEach)

describe "Board size", ->
    it "gives the width or height of a square board.", ->
        expect(solver.getBoardSize new Uint8Array 100).toBe 10

describe "Board hashing", ->
    it "should be unique for every possible input board.", ->
        boardList = []
        for i0 in [0...5]
            for i1 in [0...5]
                for i2 in [0...5]
                    for i3 in [0...5]
                        boardList.push new Uint8Array [i0, i1, i2, i3]
        hashList = _.map boardList, solver.boardHash
        expect(hashList).toEqual _.uniq(hashList)
    it "should give a string", ->
        expect(solver.boardHash(new Uint8Array 25)).usIsString()

describe "Converting a board to a human-readable string", ->
    board = new Uint8Array [
        0, 1, 2, 3,
        4, 5, 6, 7,
        8, 9, 0, 1,
        2, 3, 4, 5
    ]
    boardSize = solver.getBoardSize board
    boardString = solver.getBoardString board
    it "should give a string of as many lines as the board has rows, " +
                                                                "minus one.", ->
        newlines = _.filter boardString, (character) -> character == "\n"
        expect(newlines.length).toBe boardSize-1

describe "Parsing a board from a string", ->
    board = [
        0, 1, 2,
        3, 4, 5,
        6, 7, 8
    ]
    it "should parse a board string correctly", ->
        expect(_.toArray solver.parseBoard "012345678").toEqual board
    it "should strip out bad characters", ->
        expect(_.toArray solver.parseBoard "--0*1kbc\n23 456i7_8 ")
            .toEqual board
    it "should be able to parse the result of getBoardString", ->
        expect(_.toArray solver.parseBoard(solver.getBoardString board))
            .toEqual board

describe "Getting the board colors", ->
    board = new Uint8Array [
        0, 0, 1
        0, 6, 2
        2, 1, 0
    ]
    colors = solver.getColors(board)
    it "will give an array contain one of each color", ->
        expect(colors).toEqual _.uniq(colors)
    it "results in an array of the proper length", ->
        expect(colors.length).toBe 4

describe "Generating a random board", ->
    it "gives a board containing all the specified colors", ->
        expect(solver.getColors(solver.getRandomBoard 5, 25).length).toBe 25
    it "checks that there are enough spaces for all the colors", ->
        expect(-> solver.getRandomBoard 5, 26).toThrow()
    it "gives the right-sized board", ->
        expect(solver.getRandomBoard(10).length).toBe 100
        expect(solver.getBoardSize solver.getRandomBoard 10).toBe 10
    it "is a typed array", ->
        expect(solver.getRandomBoard() instanceof Uint8Array).toBe true

describe "Getting adjacent positions", ->
    board = solver.getRandomBoard 10
    gap = _.bind solver.getAdjacentPositions, @, board
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
        expect(_.isArray solver.getBlobPositions solver.getRandomBoard())
            .toBe true
    it "is all positions when the board is filled", ->
        expect(_(solver.getBlobPositions(solver.parseBoard """
            1111
            1111
            1111
            1111
        """)).sortBy(_.identity)).toEqual _.range(16)
    it "is just one position when all blobs are one block in size", ->
        segmentedBoard = solver.parseBoard """
            0123
            4567
            8901
            2345
        """
        for i in [0...segmentedBoard.length]
            expect(solver.getBlobPositions(segmentedBoard, i).length).toBe 1

describe "Playing a color on the board", ->
    it "replaces the color positions in the top-left blob", ->
        boardA = solver.parseBoard """
            0001
            0203
            0455
            0000
        """
        boardB = solver.parseBoard """
            9991
            9293
            9455
            9999
        """
        expect(_.toArray solver.playColor boardA, 9).toEqual _.toArray boardB
    it "should not mutate the passed in board", ->
        board = solver.getRandomBoard(); original = new Uint8Array(board)
        solver.playColor board, 9
        expect(_.toArray board).toEqual _.toArray original

describe "Finding neighbor boards", ->
    board = solver.getRandomBoard()
    neighbors = solver.getNeighborBoards(board)
    it "is an array of boards", ->
        expect(neighbors).usIsArray()
        expect(neighbors).usAll (n) -> n instanceof Uint8Array
    it "does not return the passed in board", ->
        expect(neighbors).usAll (n) -> _.isEqual(_.toArray n, _.toArray board)
    it "changes the top-left color", ->
        expect(neighbors).usAll (n) -> n[0] != board[0]
    it "gives only one result when a color could be completely eliminated", ->
        expect(solver.getNeighborBoards(solver.parseBoard """
            0012
            0223
            1332
            1144
        """).length).toBe 1

describe "Computing blob size", ->
    board = solver.parseBoard """
        000
        001
        011
    """
    it "works on a sample board", ->
        expect(solver.getBlobSize board).toBe 6
        expect(solver.getBlobSize board, board.length-1).toBe 3

describe "Manhattan distance", ->
    board = solver.getRandomBoard(10)
    p = _.bind solver.getBoardPosition, @, board
    d = _.bind solver.getDistance, @, board
    it "is the delta x plus the delta y", ->
        expect(d p(0, 0), p(5, 0)).toBe 5
        expect(d p(0, 0), p(0, 5)).toBe 5
        expect(d p(9, 9), p(0, 0)).toBe 18
        expect(d p(4, 6), p(6, 5)).toBe 3

describe "Blob distance", ->
    board = solver.parseBoard """
        0001
        1111
        3114
        1122
    """
    p = _.bind solver.getBoardPosition, @, board
    it "is the direct distance between one-point blobs", ->
        expect(solver.getBlobDistance board, p(0, 2), p(3, 2)).toBe 3
    it "minimizes the distance function", ->
        expect(solver.getBlobDistance board).toBe 3
    it "is zero when the blob is the same", ->
        expect(solver.getBlobDistance board, p(0, 0), p(1, 0)).toBe 0
    it "is one when the blobs are adjacent", ->
        expect(solver.getBlobDistance board, p(0, 0), p(1, 1)).toBe 1

describe "Perimeter blocks", ->
    it "is the adjacent positions in a one-position blob", ->
        board = solver.parseBoard """
            00000
            00000
            00100
            00000
            00000
        """
        p = _.bind solver.getBoardPosition, @, board
        expect(Array::sort solver.getPerimeterBlocks(board, p(2, 2)))
            .toEqual Array::sort solver.getAdjacentPositions(board, p 2, 2)
    it "is valid for a large blob", ->
        board = solver.parseBoard """
            00100
            01101
            00110
            00000
            02100
        """
        p = _.bind solver.getBoardPosition, @, board
        perimeter = [p(1, 0), p(3, 0), p(0, 1), p(3, 1), p(1, 2), p(4, 2),
                     p(2, 3), p(3, 3)]
        expect(Array::sort solver.getPerimeterBlocks board, p(1, 1))
            .toEqual Array::sort perimeter

describe "Perimeter length", ->
    it "equals zero when the board is filled", ->
        # It must be zero because perimeter blocks cannot be off the board
        expect(solver.getPerimeter new Uint8Array i*i).toBe(0) for i in [1..20]
