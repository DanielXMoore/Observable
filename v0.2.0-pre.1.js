// Generated by CoffeeScript 1.7.1
(function() {
  var Observable, autoDeps, computeDependencies, copy, extend, flatten, get, last, magicDependency, remove, splat, withBase,
    __slice = [].slice;

  Observable = function(value, context) {
    var changed, fn, listeners, notify, notifyReturning, self;
    if (typeof (value != null ? value.observe : void 0) === "function") {
      return value;
    }
    listeners = [];
    notify = function(newValue) {
      return copy(listeners).forEach(function(listener) {
        return listener(newValue);
      });
    };
    if (typeof value === 'function') {
      fn = value;
      self = function() {
        magicDependency(self);
        return value;
      };
      self.each = function() {
        var args, _ref;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        magicDependency(self);
        return (_ref = splat(value)).forEach.apply(_ref, args);
      };
      changed = function() {
        value = computeDependencies(self, fn, changed, context);
        return notify(value);
      };
      value = computeDependencies(self, fn, changed, context);
    } else {
      self = function(newValue) {
        if (arguments.length > 0) {
          if (value !== newValue) {
            value = newValue;
            notify(newValue);
          }
        } else {
          magicDependency(self);
        }
        return value;
      };
    }
    self.each = function() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      magicDependency(self);
      if (value != null) {
        return (_ref = [value]).forEach.apply(_ref, args);
      }
    };
    if (Array.isArray(value)) {
      ["concat", "every", "filter", "forEach", "indexOf", "join", "lastIndexOf", "map", "reduce", "reduceRight", "slice", "some"].forEach(function(method) {
        return self[method] = function() {
          var args;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          magicDependency(self);
          return value[method].apply(value, args);
        };
      });
      ["pop", "push", "reverse", "shift", "splice", "sort", "unshift"].forEach(function(method) {
        return self[method] = function() {
          var args;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          return notifyReturning(value[method].apply(value, args));
        };
      });
      notifyReturning = function(returnValue) {
        notify(value);
        return returnValue;
      };
      extend(self, {
        each: function() {
          var args;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          self.forEach.apply(self, args);
          return self;
        },
        remove: function(object) {
          var index;
          index = value.indexOf(object);
          if (index >= 0) {
            return notifyReturning(value.splice(index, 1)[0]);
          }
        },
        get: function(index) {
          return value[index];
        },
        first: function() {
          return value[0];
        },
        last: function() {
          return value[value.length - 1];
        }
      });
    }
    extend(self, {
      listeners: listeners,
      observe: function(listener) {
        return listeners.push(listener);
      },
      stopObserving: function(fn) {
        return remove(listeners, fn);
      },
      toggle: function() {
        return self(!value);
      },
      increment: function(n) {
        return self(value + n);
      },
      decrement: function(n) {
        return self(value - n);
      },
      toString: function() {
        return "Observable(" + value + ")";
      }
    });
    return self;
  };

  Observable.concat = function() {
    var args, o;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    args = Observable(args);
    o = Observable(function() {
      return flatten(args.map(splat));
    });
    o.push = args.push;
    return o;
  };

  module.exports = Observable;

  extend = function() {
    var name, source, sources, target, _i, _len;
    target = arguments[0], sources = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    for (_i = 0, _len = sources.length; _i < _len; _i++) {
      source = sources[_i];
      for (name in source) {
        target[name] = source[name];
      }
    }
    return target;
  };

  global.OBSERVABLE_ROOT_HACK = [];

  autoDeps = function() {
    return last(global.OBSERVABLE_ROOT_HACK);
  };

  magicDependency = function(self) {
    var observerStack;
    if (observerStack = autoDeps()) {
      return observerStack.push(self);
    }
  };

  withBase = function(self, update, fn) {
    var deps, value, _ref;
    global.OBSERVABLE_ROOT_HACK.push(deps = []);
    try {
      value = fn();
      if ((_ref = self._deps) != null) {
        _ref.forEach(function(observable) {
          return observable.stopObserving(update);
        });
      }
      self._deps = deps;
      deps.forEach(function(observable) {
        return observable.observe(update);
      });
    } finally {
      global.OBSERVABLE_ROOT_HACK.pop();
    }
    return value;
  };

  computeDependencies = function(self, fn, update, context) {
    return withBase(self, update, function() {
      return fn.call(context);
    });
  };

  remove = function(array, value) {
    var index;
    index = array.indexOf(value);
    if (index >= 0) {
      return array.splice(index, 1)[0];
    }
  };

  copy = function(array) {
    return array.concat([]);
  };

  get = function(arg) {
    if (typeof arg === "function") {
      return arg();
    } else {
      return arg;
    }
  };

  splat = function(item) {
    var result, results;
    results = [];
    if (typeof item.forEach === "function") {
      item.forEach(function(i) {
        return results.push(i);
      });
    } else {
      result = get(item);
      if (result != null) {
        results.push(result);
      }
    }
    return results;
  };

  last = function(array) {
    return array[array.length - 1];
  };

  flatten = function(array) {
    return array.reduce(function(a, b) {
      return a.concat(b);
    }, []);
  };

}).call(this);
