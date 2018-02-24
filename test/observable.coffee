global.Observable = require "../main"

describe 'Observable', ->
  it 'should create an observable for an object', ->
    n = 5

    observable = Observable(n)

    assert.equal(observable(), n)

  it 'should fire events when setting', ->
    string = "yolo"

    observable = Observable(string)
    observable.observe (newValue) ->
      assert.equal newValue, "4life"

    observable("4life")

  it "should not fire when setting to the same value", ->
    o = Observable 5

    o.observe ->
      assert false

    o(5)

  it 'should be idempotent', ->
    o = Observable(5)

    assert.equal o, Observable(o)

  it "should have releaseDependencies as a noop because primitive observables don't have any dependencies", ->
    o = Observable(5)
    o.releaseDependencies()

  it "should allow for stopping observation", ->
    observable = Observable("string")

    called = 0
    fn = (newValue) ->
      called += 1
      assert.equal newValue, "4life"

    observable.observe fn

    observable("4life")

    observable.stopObserving fn

    observable("wat")

    assert.equal called, 1

  it "should do nothing when removing a listener that's not present", ->
    observable = Observable("string")
    observable.stopObserving ->

  it "should increment", ->
    observable = Observable 1

    observable.increment(5)
    assert.equal observable(), 6

    observable.increment()
    assert.equal observable(), 7

  it "should decremnet", ->
    observable = Observable 1

    observable.decrement 5
    assert.equal observable(), -4

    observable.decrement()
    assert.equal observable(), -5

  it "should toggle", ->
    observable = Observable false

    observable.toggle()
    assert.equal observable(), true

    observable.toggle()
    assert.equal observable(), false

  it "should trigger when toggling", (done) ->
    observable = Observable true
    observable.observe (v) ->
      assert.equal v, false
      done()

    observable.toggle()

  it "should have a nice toString", ->
    observable = Observable 5

    assert.equal observable.toString(), "Observable(5)"

describe "Observable Array", ->
  it "should proxy array methods", ->
    o = Observable [5]

    o.map (n) ->
      assert.equal n, 5

  it "should notify on mutation methods", (done) ->
    o = Observable []

    o.observe (newValue) ->
      assert.equal newValue[0], 1

    o.push 1

    done()

  it "#get", ->
    o = Observable [0, 1, 2, 3]

    assert.equal o.get(2), 2

  it "#first", ->
    o = Observable [0, 1, 2, 3]

    assert.equal o.first(), 0

  it "#last", ->
    o = Observable [0, 1, 2, 3]

    assert.equal o.last(), 3

  it "#remove", ->
    o = Observable [0, 1, 2, 3]

    assert.equal o.remove(2), 2
    assert.equal o.length, 3
    assert.equal o.remove(-5), undefined
    assert.equal o.length, 3

  it "#remove non-existent element", ->
    o = Observable [1, 2, 3]

    assert.equal o.remove(0), undefined

  it "should proxy the length property", ->
    o = Observable [1, 2, 3]

    assert.equal o.length, 3

    called = false
    o.observe (value) ->
      assert.equal value[0], 1
      assert.equal value[1], undefined
      called = true

    o.length = 1
    assert.equal o.length, 1
    assert.equal called, true

  it "should auto detect conditionals of length as a dependency", ->
    observableArray = Observable [1, 2, 3]

    o = Observable ->
      if observableArray.length > 5
        true
      else
        false

    assert.equal o(), false

    called = 0
    o.observe ->
      called += 1

    observableArray.push 4, 5, 6

    assert.equal called, 1

describe "Observable functions", ->
  it "should compute dependencies", (done) ->
    firstName = Observable "Duder"
    lastName = Observable "Man"

    o = Observable ->
      "#{firstName()} #{lastName()}"

    o.observe (newValue) ->
      assert.equal newValue, "Duder Bro"

      done()

    lastName "Bro"

  it "should compute array#get as a dependency", ->
    observableArray = Observable [0, 1, 2]

    observableFn = Observable ->
      observableArray.get(0)

    assert.equal observableFn(), 0

    observableArray([5])

    assert.equal observableFn(), 5

  it "should compute array#first as a dependency", ->
    observableArray = Observable [0, 1, 2]

    observableFn = Observable ->
      observableArray.first() + 1

    assert.equal observableFn(), 1

    observableArray([5])

    assert.equal observableFn(), 6

  it "should compute array#last as a dependency", ->
    observableArray = Observable [0, 1, 2]

    observableFn = Observable ->
      observableArray.last()

    assert.equal observableFn(), 2

    observableArray.pop()

    assert.equal observableFn(), 1

    observableArray([5])

    assert.equal observableFn(), 5

  it "should compute array#size as a dependency", ->
    observableArray = Observable [0, 1, 2]

    observableFn = Observable ->
      observableArray.size() * 2

    assert.equal observableFn(), 6

    observableArray.pop()
    assert.equal observableFn(), 4
    observableArray.shift()
    assert.equal observableFn(), 2

  it "should allow double nesting", (done) ->
    bottom = Observable "rad"
    middle = Observable ->
      bottom()
    top = Observable ->
      middle()

    top.observe (newValue) ->
      assert.equal newValue, "wat"
      assert.equal top(), newValue
      assert.equal middle(), newValue

      done()

    bottom("wat")

  it "should work with dynamic dependencies", ->
    observableArray = Observable []

    dynamicObservable = Observable ->
      observableArray.filter (item) ->
        item.age() > 3

    assert.equal dynamicObservable().length, 0

    observableArray.push
      age: Observable 1

    observableArray()[0].age 5
    assert.equal dynamicObservable().length, 1

  it "should work with context", ->
    model =
      a: Observable "Hello"
      b: Observable "there"

    model.c = Observable ->
      "#{@a()} #{@b()}"
    , model

    assert.equal model.c(), "Hello there"

    model.b "world"

    assert.equal model.c(), "Hello world"

  it "should be ok even if the function throws an exception", ->
    assert.throws ->
      t = Observable ->
        throw "wat"

    # TODO: Should be able to find a test case that is affected by this rather that
    # checking it directly
    assert.equal global.OBSERVABLE_ROOT_HACK.length, 0

  it "should work on an array dependency", ->
    oA = Observable [1, 2, 3]

    o = Observable ->
      oA()[0]

    last = Observable ->
      oA()[oA().length-1]

    assert.equal o(), 1

    oA.unshift 0

    assert.equal o(), 0

    oA.push 4

    assert.equal last(), 4, "Last should be 4"

  it "should work with multiple dependencies", ->
    letter = Observable "A"
    checked = ->
      l = letter()
      @name().indexOf(l) is 0

    first = {name: Observable("Andrew")}
    first.checked = Observable checked, first

    second = {name: Observable("Benjamin")}
    second.checked = Observable checked, second

    assert.equal first.checked(), true
    assert.equal second.checked(), false

    assert.equal letter.listeners.length, 2

    letter "B"

    assert.equal first.checked(), false
    assert.equal second.checked(), true

  it "shouldn't double count dependencies", ->
    dep = Observable "yo"

    o = Observable ->
      dep()
      dep()
      dep()

    count = 0
    o.observe ->
      count += 1

    dep('heyy')

    assert.equal count, 1

  it "should recompute the correct number of times", ->
    joiner = Observable ","

    items = Observable [
      "A"
      "B"
      "C"
    ]

    called = 0
    fn = Observable ->
      called += 1
      items.join joiner()

    assert.equal fn(), "A,B,C"
    assert.equal called, 1

    items.push "D"
    assert.equal fn(), "A,B,C,D"
    assert.equal called, 2

    joiner "."
    assert.equal fn(), "A.B.C.D"
    assert.equal called, 3

    items.push "E"
    assert.equal fn(), "A.B.C.D.E"
    assert.equal called, 4

  it "should work with nested observable construction", ->
    gen = Observable ->
      Observable "Duder"

    o = gen()
    o2 = gen()
    assert.equal o, o2

    assert.equal o(), "Duder"

    o("wat")

    assert.equal o(), "wat"

  it "should be scoped to optional context", (done) ->
    model =
      firstName: Observable "Duder"
      lastName: Observable "Man"

    model.name = Observable ->
      "#{@firstName()} #{@lastName()}"
    , model

    model.name.observe (newValue) ->
      assert.equal newValue, "Duder Bro"

      done()

    model.lastName "Bro"

describe "Observable object", ->
  it "should proxy properties", ->
    obj = Observable
      a: 1

    assert.equal obj.a, 1
    assert.equal obj().a, obj.a

    obj.a = 2

    assert.equal obj.a, 2
    assert.equal obj().a, obj.a

  it "should work with observable properties", ->
    obj = Observable
      a: Observable 1

    assert.equal obj.a, 1
    assert.equal obj().a(), obj.a

    obj().a 2

    assert.equal obj.a, 2
    assert.equal obj().a(), obj.a

    obj.a = 3

    assert.equal obj.a, 3
    assert.equal obj().a(), obj.a

  it "should compute object#extend as a dependency", ->
    obj = Observable
      a: 1

    obj.extend b: 2

    assert.equal obj.b, 2
    assert.equal obj().b, obj.b

    # alias
    obj.assign c: 3

    assert.equal obj.c, 3
    assert.equal obj().c, obj.c

  it "should compute object#remove as a dependency", ->
    obj = Observable
      a: 1
      b: 2

    obj.remove "b"

    assert.equal obj.b, undefined

  it "should proxy object methods", ->
    obj = Observable
      a: 1
      b: 2

    assert.deepEqual obj.keys, ["a", "b"]
    assert.deepEqual obj.values, [1, 2]
    assert.deepEqual obj.entries, [["a", 1], ["b", 2]]
