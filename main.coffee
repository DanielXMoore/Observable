###
Observable
==========

`Observable` allows for observing arrays, functions, and objects.

Function dependencies are automagically observed.

Standard array methods are proxied through to the underlying array.

###

"use strict"

module.exports = Observable = (value, context) ->

  # Return the object if it is already an observable object.
  return value if typeof value?.observe is "function"

  # Maintain a set of listeners to observe changes and provide a helper to notify each observer.
  listeners = []
  notify = (newValue) ->
    copy(listeners).forEach (listener) ->
      listener(newValue)

  # If `value` is a function compute dependencies and listen to observables that it depends on.
  if typeof value is 'function'
    fn = value

    # Our return function is a function that holds only a cached value which is updated when it's dependencies change.
    # The `magicDependency` call is so other functions can depend on this computed function the same way we depend on other types of observables.
    self = ->
      # Automagic dependency observation
      magicDependency(self)

      return value

    # We expose releaseDependencies so that
    self.releaseDependencies = ->
      self._observableDependencies?.forEach (observable) ->
        observable.stopObserving changed

    # We need to recompute our dependencies whenever any observable value that our function depends on changes. We keep a set
    # of observables (so we don't needlessly recompute the same ones multiple times). When a dependency changes we recompute
    # the new set of dependencies and unsubscribe from the old set.
    changed = ->
      observableDependencies = new Set

      value = tryCallWithFinallyPop observableDependencies, fn, context

      self.releaseDependencies()
      self._observableDependencies = observableDependencies
      observableDependencies.forEach (observable) ->
        observable.observe changed

      notify(value)

    changed()

  else
    # When called with zero arguments it is treated as a getter. When called with one argument it is treated as a setter.
    # Changes to the value will trigger notifications. The value is always returned.
    self = (newValue) ->
      if arguments.length > 0
        if value != newValue
          value = newValue

          notify(newValue)
      else
        # Automagic dependency observation
        magicDependency(self)

      return value

    # Non-computed observables have no dependencies, releasing them is a non-operation.
    self.releaseDependencies = noop

  # If the value is an array then proxy array methods and add notifications to mutation events.
  if Array.isArray(value)
    [
      "concat"
      "every"
      "filter"
      "forEach"
      "indexOf"
      "join"
      "lastIndexOf"
      "map"
      "reduce"
      "reduceRight"
      "slice"
      "some"
    ].forEach (method) ->
      self[method] = (args...) ->
        magicDependency(self)
        value[method](args...)

    [
      "pop"
      "push"
      "reverse"
      "shift"
      "splice"
      "sort"
      "unshift"
    ].forEach (method) ->
      self[method] = (args...) ->
        returnValue = value[method](args...)
        notify(value)
        return returnValue

    # Provide length on a best effort basis because older browsers choke
    if PROXY_LENGTH
      Object.defineProperty self, 'length',
        get: ->
          magicDependency(self)
          value.length
        set: (length) ->
          returnValue = value.length = length
          notify(value)
          return returnValue

    # Extra methods for array observables
    extend self,
      # Remove an element from the array and notify observers of changes.
      remove: (object) ->
        index = value.indexOf(object)

        if index >= 0
          returnValue = value.splice(index, 1)[0]
          notify(value)
          return returnValue

      get: (index) ->
        magicDependency(self)
        value[index]

      first: ->
        magicDependency(self)
        value[0]

      last: ->
        magicDependency(self)
        value[value.length-1]

      size: ->
        magicDependency(self)
        value.length
  if Object::toString.call(value) is '[object Object]'
      # proxy object properties and add notifications to mutation events
      defProp = (property) ->
        Object.defineProperty self, property,
          get: ->
            magicDependency(self)
            # if object property is Observable, e.g obj = Observable { a: Observable 1 }
            if typeof value[property]?.observe is "function"
              value[property]()
            else
              value[property]
          set: (val) ->
            # if object property is Observable, e.g obj = Observable { a: Observable 1 }
            if typeof value[property]?.observe is "function"
              value[property] val
            else
              value[property] = val
              notify value

      defProp prop for own prop of value

      # Proxy object methods, e.g. Object.keys(obj)
      [
        "keys"
        "values"
        "entries"
      ].forEach (method) ->
        Object.defineProperty self, method,
          get: ->
            magicDependency(self)
            Object[method] value

      # Extra methods for object observables
      extend self,
        # Remove an element from the object and notify observers of changes.
        remove: (object) ->
          if returnValue = value[object]
            delete value[object]
            notify(value)
            return returnValue

        extend: (obj) ->
          magicDependency(self)
          value = Object.assign {}, value, obj
          defProp prop for own prop of obj
          notify value

      # alias
      self.assign = self.extend

  extend self,
    listeners: listeners

    observe: (listener) ->
      listeners.push listener

    stopObserving: (fn) ->
      remove listeners, fn

    toggle: ->
      self !value

    increment: (n=1) ->
      self value + n

    decrement: (n=1) ->
      self value - n

    toString: ->
      "Observable(#{value})"

  return self

# Appendix
# --------

extend = Object.assign

# Super hax for computing dependencies. This needs to be a shared global so that different bundled versions of observable libraries can interoperate.
global.OBSERVABLE_ROOT_HACK = []

magicDependency = (self) ->
  observerSet = last(global.OBSERVABLE_ROOT_HACK)
  if observerSet
    observerSet.add self


# Optimization: Keep the function containing the try-catch as small as possible.
tryCallWithFinallyPop = (observableDependencies, fn, context) ->
  global.OBSERVABLE_ROOT_HACK.push(observableDependencies)

  try
    fn.call(context)
  finally
    global.OBSERVABLE_ROOT_HACK.pop()


remove = (array, value) ->
  index = array.indexOf(value)

  if index >= 0
    array.splice(index, 1)[0]

copy = (array) ->
  array.concat([])

last = (array) ->
  array[array.length - 1]

noop = ->

# Check if we can proxy function length property.
try
  Object.defineProperty (->), 'length',
    get: noop
    set: noop

  PROXY_LENGTH = true
catch
  PROXY_LENGTH = false
