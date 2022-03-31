/*
Observable
==========

`Observable` allows for observing arrays, functions, and objects.

Function dependencies are automagically observed.

Standard array methods are proxied through to the underlying array.

*/

"use strict";

interface ObservableArray<T> extends Array<T>, ObservableValue<Array<T>> {
  first: () => Array<T>[number]
  last: () => Array<T>[number]
  get: (index: number) => Array<T>[number]
  remove: (item: T) => T | undefined
}

interface ComputedArray<T> extends Array<T>, Computed<Array<T>> {

}

interface Computed<T> extends Observable<T> {
  _observableDependencies: Set<Observable<unknown>>
}

interface ObservableBoolean<T> extends ObservableValue<T> {
  toggle: () => boolean
}

interface ObservableNumber<T> extends ObservableValue<T> {
  increment: (increment?: number) => number
  decrement: (decrement?: number) => number
}

interface ObservableValue<T> extends Observable<T> {
  (newValue: T): T
}

interface Observable<T> {
  (): T
  _value: T
  listeners: Array<(x: T) => void>
  notify: (newValue: T) => void
  observe: (fn: (x: T) => void) => void
  stopObserving: (fn: (x: T) => void) => void
  releaseDependencies: () => void
}

function Observable(): ObservableValue<any>
function Observable(v: null | undefined): Observable<any>
function Observable<T, O extends Observable<T>>(value: O): O
function Observable<T, F extends (this: C) => T[], C>(fn: F, context?: C): ComputedArray<ReturnType<F>>
function Observable<T, F extends (this: C) => T, C>(fn: F, context?: C): Computed<ReturnType<F>>
function Observable<T, A extends Array<T>>(value: A): ObservableArray<A[number]>
function Observable<T>(value: T):
  T extends boolean ? ObservableBoolean<T> :
  T extends number ? ObservableNumber<T> :
  ObservableValue<T>
function Observable<T>(value?: any, context?: Object): Observable<any> {

  /* istanbul ignore next */
  if (typeof (value as Observable<T>)?.observe === "function") {
    return value as Observable<T>
  }

  var self: Observable<T>;

  // If `value` is a function compute dependencies and listen to observables that it depends on.
  if (typeof value === 'function') {
    self = ObservableFunction(value as () => T, context);
  } else {
    self = ObservableValue(value);
  }
  // If the value is an array then proxy array methods and add notifications to mutation events.
  addExtensions(self as ObservableValue<unknown>);
  Object.assign(self, {
    toString: function () {
      return `Observable(${self._value})`;
    }
  });
  return self;
};

const emptySet: Set<Observable<unknown>> = new Set();

function ObservableFunction<T>(
  fn: () => T,
  context?: Object
): Computed<T> {

  const listeners: Array<(x: T) => void> = [];

  function notify(newValue: T) {
    self._value = newValue;
    copy(listeners).forEach(function (listener) {
      listener(newValue);
    });
  };
  // Our return function is a function that holds only a cached value which is updated when it's dependencies change.
  // The `magicDependency` call is so other functions can depend on this computed function the same way we depend on other types of observables.
  const self: Computed<T> = Object.assign(function () {
    // Automagic dependency observation
    magicDependency(self as Observable<unknown>);
    return self._value;
  }, {
    _value: null as unknown as T,
    _observableDependencies: emptySet,
    // We expose releaseDependencies so that
    releaseDependencies: function () {
      self._observableDependencies.forEach(function (observable: Observable<unknown>) {
        observable.stopObserving(changed);
      });
    },
    listeners: listeners,
    notify: notify,
    observe: function (listener: (x: T) => void) {
      listeners.push(listener);
    },
    stopObserving: function (listener: (x: T) => void) {
      remove(listeners, listener);
    }
  });
  // We need to recompute our dependencies whenever any observable value that our function depends on changes. We keep a set
  // of observables (so we don't needlessly recompute the same ones multiple times). When a dependency changes we recompute
  // the new set of dependencies and unsubscribe from the old set.
  function changed() {
    let value: T;
    const observableDependencies = new Set<Observable<unknown>>();
    OBSERVABLE_ROOT.push(observableDependencies);
    try {
      value = fn.call(context);
    } finally {
      OBSERVABLE_ROOT.pop();
    }
    self.releaseDependencies();
    self._observableDependencies = observableDependencies;
    observableDependencies.forEach(function (observable) {
      return observable.observe(changed);
    });
    return notify(value);
  };

  changed();
  return self;
};

function ObservableValue<T>(value: T): ObservableValue<T> {

  // Maintain a set of listeners to observe changes and provide a helper to notify each observer.
  const listeners: Array<(x: T) => void> = [];

  function notify(newValue: T) {
    self._value = newValue;
    copy(listeners).forEach(function (listener) {
      listener(newValue);
    });
  };
  // When called with zero arguments it is treated as a getter.
  // When called with one argument it is treated as a setter.
  // Changes to the value will trigger notifications.
  // The value is always returned.
  const self: ObservableValue<T> = Object.assign(function (newValue?: T) {
    if (arguments.length) {
      if (value !== newValue) {
        // Must have a value if there were arguments
        notify(value = newValue as T);
      }
    } else {
      // Automagic dependency observation
      magicDependency(self as Observable<unknown>);
    }
    return value;
  }, {
    listeners: listeners,
    notify: notify,
    observe: function (listener: (x: T) => void) {
      listeners.push(listener);
    },
    stopObserving: function (listener: (x: T) => void) {
      remove(listeners, listener);
    },
    releaseDependencies: noop,
    _value: value
  });

  // Non-computed observables have no dependencies, releasing them is a non-operation.

  return self;
};

function arrayExtensions<T>(o: ObservableArray<T>) {
  (["concat", "every", "filter", "forEach", "indexOf", "join", "lastIndexOf", "map", "reduce", "reduceRight", "slice", "some"] as const).forEach(function (method) {
    // @ts-ignore
    o[method] = function (...args: Parameters<Array<T>[typeof method]>) {
      magicDependency(o as Observable<unknown>);
      // @ts-ignore
      return o._value[method](...args);
    };
  });
  (["pop", "push", "reverse", "shift", "splice", "sort", "unshift"] as const).forEach(function (method) {
    // @ts-ignore
    o[method] = function (...args) {
      var returnValue;
      // @ts-ignore
      returnValue = o._value[method](...args);
      o.notify(o._value);
      return returnValue;
    };
  });
  Object.defineProperty(o, 'length', {
    get: function () {
      magicDependency(o as Observable<unknown>);
      return (o._value as Array<unknown>).length;
    },
    set: function (length) {
      var returnValue;
      returnValue = (o._value as Array<unknown>).length = length;
      o.notify(o._value);
      return returnValue;
    }
  });

  Object.assign(o, {
    // Remove an element from the array and notify observers of changes.
    remove: function (x: unknown) {
      const value = o._value as Array<unknown>;
      const index = value.indexOf(x);
      if (index >= 0) {
        return o.splice(index, 1)[0];
      }
    },
    get: function (index: number) {
      return o()[index];
    },
    first: function () {
      return o()[0];
    },
    last: function () {
      const a = o() as Array<unknown>
      const { length } = a;
      return a[length - 1];
    }
  });
}

function addExtensions(o: ObservableValue<unknown>) {
  const v = o._value;

  if (Array.isArray(v)) {
    arrayExtensions(o as ObservableArray<unknown>)
    return
  }

  const exts = (function () {
    switch (typeof v) {
      case "boolean":
        return {
          toggle: function () {
            return o(!o._value);
          }
        };
      case "number":
        return {
          increment: function (n = 1) {
            return o(Number(o._value) + n);
          },
          decrement: function (n = 1) {
            return o(Number(o._value) - n);
          }
        };
    }
  })();

  return Object.assign(o, exts);
};

// Appendix
// --------

// Dropping support for simultaneous use of different versions
const OBSERVABLE_ROOT: Array<Set<Observable<unknown>>> = [];

function magicDependency(self: Observable<unknown>) {
  var observerSet;
  observerSet = last(OBSERVABLE_ROOT);
  if (observerSet) {
    return observerSet.add(self);
  }
};

function remove<T>(array: Array<T>, value: T): T | undefined {
  const index = array.indexOf(value);
  if (index >= 0) {
    return array.splice(index, 1)[0];
  }
};

function copy<T>(array: Array<T>): Array<T> {
  return array.slice();
};

function last<T>(array: T[]): T {
  return array[array.length - 1];
}

function noop(): void { }

Observable.OBSERVABLE_ROOT = OBSERVABLE_ROOT;

export = Observable;
