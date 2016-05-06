Observable
==========

`Observable` allows for observing arrays, functions, and objects.

Function dependencies are automagically observed.

Standard array methods are proxied through to the underlying array.

    module.exports = Observable = (value, context) ->

Return the object if it is already an observable object.

      return value if typeof value?.observe is "function"

Maintain a set of listeners to observe changes and provide a helper to notify each observer.

      listeners = []

      notify = (newValue) ->
        copy(listeners).forEach (listener) ->
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

        changed = ->
          value = computeDependencies(self, fn, changed, context)
          notify(value)

        changed()

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

This `each` iterator is similar to [the Maybe monad](http://en.wikipedia.org/wiki/Monad_&#40;functional_programming&#41;#The_Maybe_monad) in that our observable may contain a single value or nothing at all.

      self.each = (callback) ->
        magicDependency(self)

        if value?
          [value].forEach (item) ->
            callback.call(item, item)

        return self

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
            notifyReturning value[method](args...)

        # Provide length on a best effort basis because older browsers choke
        if PROXY_LENGTH
          Object.defineProperty self, 'length',
            get: ->
              magicDependency(self)
              value.length
            set: (length) ->
              value.length = length
              notifyReturning(value.length)

        notifyReturning = (returnValue) ->
          notify(value)

          return returnValue

Add some extra helpful methods to array observables.

        extend self,
          each: (callback) ->
            self.forEach (item, index) ->
              callback.call(item, item, index, self)

            return self

Remove an element from the array and notify observers of changes.

          remove: (object) ->
            index = value.indexOf(object)

            if index >= 0
              notifyReturning value.splice(index, 1)[0]

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

      extend self,
        listeners: listeners

        observe: (listener) ->
          listeners.push listener

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

    Observable.concat = ->
      # Optimization: Manually copy arguments to an array
      args = new Array(arguments.length)
      for arg, i in arguments
        args[i] = arguments[i]

      collection = Observable(args)

      o = Observable ->
        flatten collection.map(splat)

      o.push = collection.push

      return o

Appendix
--------

The extend method adds one object's properties to another.

    extend = (target) ->
      # Optimization: iterate through arguments manually rather than pass to slice to create an array
      for source, i in arguments
        # The first argument is target, so skip it
        if i > 0
          for name of source
            target[name] = source[name]

      return target

Super hax for computing dependencies. This needs to be a shared global so that
different bundled versions of observable libraries can interoperate.

    global.OBSERVABLE_ROOT_HACK = []

    magicDependency = (self) ->
      observerSet = last(global.OBSERVABLE_ROOT_HACK)
      if observerSet
        observerSet.add self

Optimization: Keep the function containing the try-catch as small as possible.

    tryCallWithFinallyPop = (fn, context) ->
      try
        fn.call(context)
      finally
        global.OBSERVABLE_ROOT_HACK.pop()

Automagically compute dependencies.

    computeDependencies = (self, fn, update, context) ->
      deps = new Set

      global.OBSERVABLE_ROOT_HACK.push(deps)

      value = tryCallWithFinallyPop fn, context

      self._deps?.forEach (observable) ->
        observable.stopObserving update

      self._deps = deps

      deps.forEach (observable) ->
        observable.observe update

      return value

Check if we can proxy function length property.

    try
      Object.defineProperty (->), 'length',
        get: ->
        set: ->

      PROXY_LENGTH = true
    catch
      PROXY_LENGTH = false

Remove a value from an array.

    remove = (array, value) ->
      index = array.indexOf(value)

      if index >= 0
        array.splice(index, 1)[0]

    copy = (array) ->
      array.concat([])

    get = (arg) ->
      if typeof arg is "function"
        arg()
      else
        arg

    splat = (item) ->
      results = []

      return results unless item?

      if typeof item.forEach is "function"
        item.forEach (i) ->
          results.push i
      else
        result = get item

        results.push result if result?

      results

    last = (array) ->
      array[array.length - 1]

    flatten = (array) ->
      array.reduce (a, b) ->
        a.concat(b)
      , []
