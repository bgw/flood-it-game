# Adds extra Jasmine matchers from the Underscore functions. Names are prefixed
# with "us" to prevent conflicts. For example, `_.all` turns into `usAll`. The
# spec should call us with a context function like `beforeEach`:
# `require("./jasmine-underscore.coffee")(beforeEach)`

_ = require "underscore-extra.coffee"

nameTransform = (functionName) ->
    return "us" + functionName[0].toUpperCase() + functionName[1..]

module.exports = (context) ->
    extraMatchers = {}
    for [key, value] in _.pairs(_)
        extraMatchers[nameTransform key] = (args...) ->
            return value(@actual, args...)
    context ->
        @addMatchers extraMatchers
