###
Observable
==========

`Observable` allows for observing arrays, functions, and objects.

Function dependencies are automagically observed.

Standard array methods are proxied through to the underlying array.

###

"use strict"

module.exports = (value, context) ->

  # Return the object if it is already an observable object.
  return value if typeof value?.observe is "function"

  # Maintain a set of listeners to observe changes and provide a helper to notify each observer.
  listeners = []
  notify = (newValue) ->
    self._value = newValue
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
      global.OBSERVABLE_ROOT_HACK.push(observableDependencies)
      try
        value = fn.call(context)
      finally
        global.OBSERVABLE_ROOT_HACK.pop()

      self.releaseDependencies()
      self._observableDependencies = observableDependencies
      observableDependencies.forEach (observable) ->
        observable.observe changed

      notify(value)

    changed()

  else
    # When called with zero arguments it is treated as a getter.
    # When called with one argument it is treated as a setter.
    # Changes to the value will trigger notifications.
    # The value is always returned.
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
    self._value = value

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

    Object.defineProperty self, 'length',
      get: ->
        magicDependency(self)
        value.length
      set: (length) ->
        returnValue = value.length = length
        notify(value)
        return returnValue

    # Extra methods for array observables
    Object.assign self,
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

  Object.assign self,
    listeners: listeners

    observe: (listener) ->
      listeners.push listener

    stopObserving: (fn) ->
      remove listeners, fn

    toggle: ->
      self !value

    increment: (n=1) ->
      self Number(value) + n

    decrement: (n=1) ->
      self Number(value) - n

    toString: ->
      "Observable(#{value})"

  return self

# Appendix
# --------

# Super hax for computing dependencies. This needs to be a shared global so that
# different bundled versions of observable libraries can interoperate.
global.OBSERVABLE_ROOT_HACK = []

magicDependency = (self) ->
  observerSet = last(global.OBSERVABLE_ROOT_HACK)
  if observerSet
    observerSet.add self

remove = (array, value) ->
  index = array.indexOf(value)

  if index >= 0
    array.splice(index, 1)[0]

copy = (array) ->
  array.concat([])

last = (array) ->
  array[array.length - 1]

noop = ->
