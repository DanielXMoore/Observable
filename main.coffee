###
Observable
==========

`Observable` allows for observing arrays, functions, and objects.

Function dependencies are automagically observed.

Standard array methods are proxied through to the underlying array.

###

"use strict"

emptySet = new Set

ObservableFunction = (fn, context) ->
  listeners = []

  notify = (newValue) ->
    self._value = newValue
    copy(listeners).forEach (listener) ->
      listener(newValue)

  # Our return function is a function that holds only a cached value which is updated when it's dependencies change.
  # The `magicDependency` call is so other functions can depend on this computed function the same way we depend on other types of observables.
  self = ->
    # Automagic dependency observation
    magicDependency(self)
    return self._value

  Object.assign self,
    _value: null
    _observableDependencies: emptySet

    # We expose releaseDependencies so that
    releaseDependencies: ->
      self._observableDependencies.forEach (observable) ->
        observable.stopObserving changed

    listeners: listeners

    notify: notify

    observe: (listener) ->
      listeners.push listener

    stopObserving: (fn) ->
      remove listeners, fn

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

  return self

ObservableValue = (value) ->
  # Maintain a set of listeners to observe changes and provide a helper to notify each observer.
  listeners = []
  notify = (newValue) ->
    self._value = newValue
    copy(listeners).forEach (listener) ->
      listener(newValue)

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

  Object.assign self,
    listeners: listeners

    notify: notify

    observe: (listener) ->
      listeners.push listener

    stopObserving: (fn) ->
      remove listeners, fn

  # Non-computed observables have no dependencies, releasing them is a non-operation.
  self.releaseDependencies = noop
  self._value = value

  return self

addExtensions = (o) ->
  v = o._value
  exts = switch typeof v
    when "boolean"
      toggle: ->
        o !o._value
    when "number"
      increment: (n=1) ->
        o Number(o._value) + n

      decrement: (n=1) ->
        o Number(o._value) - n
    else
      if Array.isArray v
        # Remove an element from the array and notify observers of changes.
        remove: (x) ->
          value = o._value
          index = value.indexOf(x)

          if index >= 0
            returnValue = o.splice(index, 1)[0]
            return returnValue

        get: (index) ->
          o()[index]

        first: ->
          o()[0]

        last: ->
          {length} = a = o()
          a[length-1]

  if Array.isArray(o._value)
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
      o[method] = (args...) ->
        magicDependency(o)
        o._value[method](args...)

    [
      "pop"
      "push"
      "reverse"
      "shift"
      "splice"
      "sort"
      "unshift"
    ].forEach (method) ->
      o[method] = (args...) ->
        returnValue = o._value[method](args...)
        o.notify(o._value)
        return returnValue

    Object.defineProperty o, 'length',
      get: ->
        magicDependency(o)
        o._value.length
      set: (length) ->
        returnValue = o._value.length = length
        o.notify(o._value)
        return returnValue

  Object.assign o, exts

module.exports = (value, context) ->

  # Return the object if it is already an observable object.
  return value if typeof value?.observe is "function"

  # If `value` is a function compute dependencies and listen to observables that it depends on.
  if typeof value is 'function'
    self = ObservableFunction(value, context)
  else
    self = ObservableValue(value)

  # If the value is an array then proxy array methods and add notifications to mutation events.
  addExtensions(self)

  Object.assign self,
    toString: ->
      "Observable(#{self._value})"

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
