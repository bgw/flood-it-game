Raphael = require "raphael-browserify"
solver = require "./solver.coffee"
_ = require "./underscore-extra.coffee"

colors = ["#FF2424", "#B39919", "#FBFF24", "#19B323", "#24A7FF", "#A600FF"]

# An implementation of board state, containing both a Raphael set, and data in
# the format required by the AI
class Board
    constructor: (@paper, @x, @y, @width, @height, @boardBlocks=14,
                  @colorCount=colors.length, @boardData=undefined) ->
        @boardData ?= (Math.floor(Math.random() * @colorCount) \
                       for i in [0...@boardBlocks*@boardBlocks])
        @boardData = new Uint8Array @boardData

    # Redraws all the blocks after a move.
    updateRaphael: ->
        [blockWidth, blockHeight] = [@width/@boardBlocks, @height/@boardBlocks]
        @raphaelSet?.remove()
        @raphaelSet = @paper.set()
        for row in [0...@boardBlocks]
            for col in [0...@boardBlocks]
                # Compute top-left positions and round them
                tlx = Math.ceil @x + blockWidth * col
                tly = Math.ceil @y + blockHeight * row
                # Compute bottom-right positions and round them
                brx = Math.ceil @x + blockWidth * (col + 1)
                bry = Math.ceil @y + blockHeight * (row + 1)
                # Recompute x, y, width, and height from these now rounded
                # points (which fixes subpixel drawing issues)
                rect = @paper.rect(
                    tlx, tly, brx-tlx, bry-tly
                )
                rect.attr
                    fill: colors[@boardData[row*@boardBlocks + col]]
                @raphaelSet.push(rect)
        @raphaelSet.attr
            stroke: "none"
        return @raphaelSet

# Define the code that gets run when the page loads
run = _.once ->
    width = 320
    height = 320
    paper = Raphael document.getElementById("game-container"), width, height
    b = new Board paper, 0, 0, width, height
    b.updateRaphael()

# For browsers that support it
document.addEventListener "DOMContentLoaded", run, false
# For browsers that don't (a fallback)
window.addEventListener "load", run, false
