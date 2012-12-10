solver = require "./solver.coffee"

width = 320
height = 320

paper = Raphael document.getElementById("game-container"), width, height
colors = ["#FF2424", "#B39919", "#FBFF24", "#19B323", "#24A7FF", "#A600FF"]

# An implementation of board state, containing both a Raphael set, and data in
# the format required by the AI
class Board
    constructor: (@paper, @x, @y, @width, @height, @boardBlocks=14,
                  @colorCount=colors.length, @boardData=undefined) ->
        @boardData ?= (Math.floor(Math.random() * @colorCount) \
                       for i in [0...@boardBlocks*@boardBlocks])
        @boardData = new Uint8Array @boardData

    updateRaphael: () ->
        [blockWidth, blockHeight] = [@width/@boardBlocks, @height/@boardBlocks]
        @raphaelSet?.remove()
        @raphaelSet = @paper.set()
        for row in [0...@size]
            for col in [0...@size]
                rect = @raphaelSet.push(@paper.rect(
                    @x + blockWidth * col, @y + blockHeight * row,
                    blockWidth, blockHeight
                ))
                rect.attr color: colors[@boardData[row * @boardBlocks + col]]
        return @raphaelSet

b = new Board paper, 0, 0, width, height
b.updateRaphael()
