/*
Observable
==========

`Observable` allows for observing arrays, functions, and objects.

Function dependencies are automagically observed.

Standard array methods are proxied through to the underlying array.

*/

"use strict";

interface ObservableValue<T> extends Observable {
  (): T
  (newValue:T): T
  listeners: Function[]
  notify: (newValue:T) => void
}

interface Observable {
  observe: (fn:Function) => void
  stopObserving: (fn:Function) => void
}

var ObservableValue, addExtensions, emptySet;

emptySet = new Set();

function ObservableFunction<T extends unknown>(
  fn: ()=> T,
  context: Object
): () => T {
  var changed, notify, self;

  const listeners: Array<Function> = [];

  notify = function(newValue) {
    self._value = newValue;
    return copy(listeners).forEach(function(listener) {
      return listener(newValue);
    });
  };
  // Our return function is a function that holds only a cached value which is updated when it's dependencies change.
  // The `magicDependency` call is so other functions can depend on this computed function the same way we depend on other types of observables.
  self = function() {
    // Automagic dependency observation
    magicDependency(self);
    return self._value;
  };
  Object.assign(self, {
    _value: null,
    _observableDependencies: emptySet,
    // We expose releaseDependencies so that
    releaseDependencies: function() {
      return self._observableDependencies.forEach(function(observable) {
        return observable.stopObserving(changed);
      });
    },
    listeners: listeners,
    notify: notify,
    observe: function(listener) {
      return listeners.push(listener);
    },
    stopObserving: function(fn) {
      return remove(listeners, fn);
    }
  });
  // We need to recompute our dependencies whenever any observable value that our function depends on changes. We keep a set
  // of observables (so we don't needlessly recompute the same ones multiple times). When a dependency changes we recompute
  // the new set of dependencies and unsubscribe from the old set.
  changed = function() {
    var observableDependencies, value;
    observableDependencies = new Set();
    global.OBSERVABLE_ROOT_HACK.push(observableDependencies);
    try {
      value = fn.call(context);
    } finally {
      global.OBSERVABLE_ROOT_HACK.pop();
    }
    self.releaseDependencies();
    self._observableDependencies = observableDependencies;
    observableDependencies.forEach(function(observable) {
      return observable.observe(changed);
    });
    return notify(value);
  };
  changed();
  return self;
};

ObservableValue = function<T>(value:T) {
  var notify, self;
  // Maintain a set of listeners to observe changes and provide a helper to notify each observer.
  const listeners : Array<(x:T) => void> = [];
  notify = function(newValue) {
    self._value = newValue;
    return copy(listeners).forEach(function(listener) {
      return listener(newValue);
    });
  };
  // When called with zero arguments it is treated as a getter.
  // When called with one argument it is treated as a setter.
  // Changes to the value will trigger notifications.
  // The value is always returned.
  self = function(newValue) {
    if (arguments.length > 0) {
      if (value !== newValue) {
        value = newValue;
        notify(newValue);
      }
    } else {
      // Automagic dependency observation
      magicDependency(self);
    }
    return value;
  };
  Object.assign(self, {
    listeners: listeners,
    notify: notify,
    observe: function(listener) {
      return listeners.push(listener);
    },
    stopObserving: function(fn) {
      return remove(listeners, fn);
    }
  });
  // Non-computed observables have no dependencies, releasing them is a non-operation.
  self.releaseDependencies = noop;
  self._value = value;
  return self;
};

addExtensions = function(o) {
  var exts, v;
  v = o._value;
  exts = (function() {
    switch (typeof v) {
      case "boolean":
        return {
          toggle: function() {
            return o(!o._value);
          }
        };
      case "number":
        return {
          increment: function(n = 1) {
            return o(Number(o._value) + n);
          },
          decrement: function(n = 1) {
            return o(Number(o._value) - n);
          }
        };
      default:
        if (Array.isArray(v)) {
          return {
            // Remove an element from the array and notify observers of changes.
            remove: function(x) {
              var index, returnValue, value;
              value = o._value;
              index = value.indexOf(x);
              if (index >= 0) {
                returnValue = o.splice(index, 1)[0];
                return returnValue;
              }
            },
            get: function(index) {
              return o()[index];
            },
            first: function() {
              return o()[0];
            },
            last: function() {
              var a, length;
              ({length} = a = o());
              return a[length - 1];
            }
          };
        }
    }
  })();
  if (Array.isArray(o._value)) {
    ["concat", "every", "filter", "forEach", "indexOf", "join", "lastIndexOf", "map", "reduce", "reduceRight", "slice", "some"].forEach(function(method) {
      return o[method] = function(...args) {
        magicDependency(o);
        return o._value[method](...args);
      };
    });
    ["pop", "push", "reverse", "shift", "splice", "sort", "unshift"].forEach(function(method) {
      return o[method] = function(...args) {
        var returnValue;
        returnValue = o._value[method](...args);
        o.notify(o._value);
        return returnValue;
      };
    });
    Object.defineProperty(o, 'length', {
      get: function() {
        magicDependency(o);
        return o._value.length;
      },
      set: function(length) {
        var returnValue;
        returnValue = o._value.length = length;
        o.notify(o._value);
        return returnValue;
      }
    });
  }
  return Object.assign(o, exts);
};

module.exports = function(value, context) {
  var self;
  if (typeof (value != null ? value.observe : void 0) === "function") {
    // Return the object if it is already an observable object.
    return value;
  }
  // If `value` is a function compute dependencies and listen to observables that it depends on.
  if (typeof value === 'function') {
    self = ObservableFunction(value, context);
  } else {
    self = ObservableValue(value);
  }
  // If the value is an array then proxy array methods and add notifications to mutation events.
  addExtensions(self);
  Object.assign(self, {
    toString: function() {
      return `Observable(${self._value})`;
    }
  });
  return self;
};

// Appendix
// --------

// Super hax for computing dependencies. This needs to be a shared global so that
// different bundled versions of observable libraries can interoperate.
global.OBSERVABLE_ROOT_HACK = [];

function magicDependency(self:Observable) {
  var observerSet;
  observerSet = last(global.OBSERVABLE_ROOT_HACK);
  if (observerSet) {
    return observerSet.add(self);
  }
};

function remove<T>(array:Array<T>, value:T): T | undefined {
  var index;
  index = array.indexOf(value);
  if (index >= 0) {
    return array.splice(index, 1)[0];
  }
};

function copy<T>(array:Array<T>): Array<T> {
  return array.slice();
};

function last<T extends unknown[]>(array:T): T[number] {
  return array[array.length - 1];
}

function noop():void {}
