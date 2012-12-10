# Provides a minheap implementation to the solver

_ = require "../underscore-extra.coffee"

# Maintains a binary min-heap of a set of values. This is used in `solver.aStar`
# to guarantee O(1) lookups of the lowest-cost node with O(log n) insert times.
# This is a very minimal implementation. Duplicate keys are allowed.
#
# For a description of a min-heap, see: http://en.wikipedia.org/wiki/Binary_heap
class MinHeap
    # Keys are stored as integers in typed arrays. Changing keyStorageType to a
    # given typed array type will influence the possible range of keys.
    constructor: (@keyStorageType=Float32Array) ->
        @keyStorage = new @keyStorageType 16
        @valueStorage = []
        @keyValueMapStorage = new Uint16Array 16
        @length = 0
        @previousPuts = []

    # Places a key-value pair into the heap. Takes O(log n) time.
    put: (key, value) ->
        if @keyStorage.length == @length # double the capacity
            oldKeyStorage = @keyStorage
            @keyStorage = new @keyStorageType 2*oldKeyStorage.length
            @keyStorage.set oldKeyStorage
            oldKeyValueMapStorage = @keyValueMapStorage
            @keyValueMapStorage = new Uint16Array 2*oldKeyValueMapStorage.length
            @keyValueMapStorage.set oldKeyValueMapStorage
        ksIndex = @length
        vsIndex = @valueStorage.length
        @valueStorage.push value

        # Put the new entry at the bottom of the tree, and move it up into
        # place.
        @keyStorage[ksIndex] = key
        @keyValueMapStorage[ksIndex] = vsIndex
        @length++
        if @length > 1
            @_moveUp ksIndex
        return value

    # Moves an index up until it is in its proper place.
    _moveUp: (index) ->
        key = @keyStorage[index]
        while index > 0 # Until we become root (or until we're the right place)
            parent = Math.max((index - 1) >> 1, 0)
            if key >= @keyStorage[parent] then return # We're in the right place
            @_swap parent, index
            index = parent

    # Moves an index down until it is in its proper place.
    _moveDown: (index) ->
        while index < (@length >> 1)
            child = 2*index + 1
            if child < @length - 1 and @keyStorage[child] > @keyStorage[child+1]
                # This way, we're always comparing against the lowest-key child
                child++
            if @keyStorage[index] <= @keyStorage[child]
                # The key is less than the lowest of the subkeys, so we must be
                # in the right spot
                return
            @_swap index, child
            index = child

    # Switches the values at the given indexes for both the `@keyStorage` and
    # `@keyValueMapStorage`.
    _swap: (indexA, indexB) ->
        [@keyStorage[indexA], @keyStorage[indexB]] = \
            [@keyStorage[indexB], @keyStorage[indexA]]
        [@keyValueMapStorage[indexA], @keyValueMapStorage[indexB]] = \
            [@keyValueMapStorage[indexB], @keyValueMapStorage[indexA]]

    # Returns the [key, value] pair with the lowest key and removes it. Takes
    # O(log n) time.
    popPair: ->
        if @length == 0
            throw new RangeError "Cannot pop from an empty MinHeap"
        key = @keyStorage[0]
        value = @valueStorage[@keyValueMapStorage[0]]
        @valueStorage[@keyValueMapStorage[0]] = undefined # A little bit leaky
        @length--
        if @length == 0 then return [key, value] # No more work to be done

        # Make the last node the top node and then move it down until everything
        # fits, effectively filling in the empty top-spot
        @_swap 0, @length
        @_moveDown 0

        return [key, value]

    popKey: -> @popPair()[0]
    popValue: -> @popPair()[1]

module.exports = MinHeap
