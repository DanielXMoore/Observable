Observable
==========

`Observable` allows for observing arrays, functions, and objects.

Function dependencies are automagically observed.

Standard array methods are proxied through to the underlying array.

    Observable = (value, context) ->

Return the object if it is already an observable object.

      return value if typeof value?.observe is "function"

Maintain a set of listeners to observe changes and provide a helper to notify each observer.

      listeners = []

      notify = (newValue) ->
        listeners.forEach (listener) ->
          listener(newValue)

Our observable function is stored as a reference to `self`.

If `value` is a function compute dependencies and listen to observables that it depends on.

      if typeof value is 'function'
        fn = value

Our return function is a function that holds only a cached value which is updated
when it's dependencies change.

The `magicDependency` call is so other functions can depend on this computed function the
same way we depend on other types of observables.

        self = ->
          # Automagic dependency observation
          magicDependency(self)

          return value

        self.observe = (listener) ->
          listeners.push listener

        changed = ->
          value = fn.call(context)
          notify(value)

        value = computeDependencies(fn, changed, context)

      else

When called with zero arguments it is treated as a getter. When called with one argument it is treated as a setter.

Changes to the value will trigger notifications.

The value is always returned.

        self = (newValue) ->
          if arguments.length > 0
            if value != newValue
              value = newValue

              notify(newValue)
          else
            # Automagic dependency observation
            magicDependency(self)

          return value

Add a listener for when this object changes.

        self.observe = (listener) ->
          listeners.push listener

This `each` iterator is similar to [the Maybe monad](http://en.wikipedia.org/wiki/Monad_&#40;functional_programming&#41;#The_Maybe_monad) in that our observable may contain a single value or nothing at all.

      self.each = (args...) ->
        if value?
          [value].forEach(args...)

If the value is an array then proxy array methods and add notifications to mutation events.

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
            notifyReturning value[method](args...)

        notifyReturning = (returnValue) ->
          notify(value)

          return returnValue

Add some extra helpful methods to array observables.

        extend self,
          each: (args...) ->
            self.forEach(args...)

            return self

Remove an element from the array and notify observers of changes.

          remove: (object) ->
            index = value.indexOf(object)

            if index >= 0
              notifyReturning value.splice(index, 1)[0]

          get: (index) ->
            value[index]

          first: ->
            value[0]

          last: ->
            value[value.length-1]

      extend self,
        stopObserving: (fn) ->
          remove listeners, fn

        toggle: ->
          self !value

        increment: (n) ->
          self value + n

        decrement: (n) ->
          self value - n

        toString: ->
          "Observable(#{value})"

      return self

Export `Observable`

    module.exports = Observable

Appendix
--------

The extend method adds one objects properties to another.

    extend = (target, sources...) ->
      for source in sources
        for name of source
          target[name] = source[name]

      return target

Super hax for computing dependencies. This needs to be a shared global so that
different bundled versions of observable libraries can interoperate.

    global.OBSERVABLE_ROOT_HACK = undefined

    magicDependency = (self) ->
      if base = global.OBSERVABLE_ROOT_HACK
        self.observe base

    withBase = (root, fn) ->
      global.OBSERVABLE_ROOT_HACK = root
      try
        value = fn()
      finally
        global.OBSERVABLE_ROOT_HACK = undefined

      return value

    base = ->
      global.OBSERVABLE_ROOT_HACK

Automagically compute dependencies.

    computeDependencies = (fn, root, context) ->
      withBase root, ->
        fn.call(context)

Remove a value from an array.

    remove = (array, value) ->
      index = array.indexOf(value)

      if index >= 0
        array.splice(index, 1)[0]
