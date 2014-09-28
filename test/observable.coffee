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

  describe "#each", ->
    it "should be invoked once if there is an observable", ->
      o = Observable(5)
      called = 0

      o.each (value) ->
        called += 1
        assert.equal value, 5

      assert.equal called, 1

    it "should not be invoked if observable is null", ->
      o = Observable(null)
      called = 0

      o.each (value) ->
        called += 1

      assert.equal called, 0

    it "should have the correct `this` scope for items", (done) ->
      o = Observable 5

      o.each ->
        assert.equal this, 5
        done()

    it "should have the correct `this` scope for items in observable arrays", ->
      scopes = []

      o = Observable ["I'm", "an", "array"]

      o.each ->
        scopes.push this

      assert.equal scopes[0], "I'm"
      assert.equal scopes[1], "an"
      assert.equal scopes[2], "array"

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

  it "should increment", ->
    observable = Observable 1

    observable.increment(5)

    assert.equal observable(), 6

  it "should decremnet", ->
    observable = Observable 1

    observable.decrement 5

    assert.equal observable(), -4

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

  it "should have an each method", ->
    o = Observable []

    assert o.each

  it "#get", ->
    o = Observable [0, 1, 2, 3]

    assert.equal o.get(2), 2

  it "#first", ->
    o = Observable [0, 1, 2, 3]

    assert.equal o.first(), 0

  it "#last", ->
    o = Observable [0, 1, 2, 3]

    assert.equal o.last(), 3

  it "#remove", (done) ->
    o = Observable [0, 1, 2, 3]

    o.observe (newValue) ->
      assert.equal newValue.length, 3
      setTimeout ->
        done()
      , 0

    assert.equal o.remove(2), 2

  it "#remove non-existent element", ->
    o = Observable [1, 2, 3]

    assert.equal o.remove(0), undefined

  # TODO: This looks like it might be impossible
  it "should proxy the length property"

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

  it "should have an each method", ->
    o = Observable ->

    assert o.each()

  it "should not invoke when returning undefined", ->
    o = Observable ->

    o.each ->
      assert false

  it "should invoke when returning any defined value", (done) ->
    o = Observable -> 5

    o.each (n) ->
      assert.equal n, 5
      done()

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

  it "should work with nested observable construction", ->
    gen = Observable ->
      Observable "Duder"

    o = gen()

    assert.equal o(), "Duder"

    o("wat")

    assert.equal o(), "wat"

  describe "Scoping", ->
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

  describe "concat", ->
    it "should work with a single observable", ->
      observable = Observable "something"
      observableArray = Observable.concat observable
      assert.equal observableArray.last(), "something"

      observable "something else"
      assert.equal observableArray.last(), "something else"

    it "should work with an undefined observable", ->
      observable = Observable undefined
      observableArray = Observable.concat observable
      assert.equal observableArray.size(), 0

      observable "defined"
      assert.equal observableArray.size(), 1

    it "should work with undefined", ->
      observableArray = Observable.concat undefined
      assert.equal observableArray.size(), 0

    it "should work with []", ->
      observableArray = Observable.concat []
      assert.equal observableArray.size(), 0

    it "should return an observable array that changes based on changes in inputs", ->
      numbers = Observable [1, 2, 3]
      letters = Observable ["a", "b", "c"]
      item = Observable({})
      nullable = Observable null

      observableArray = Observable.concat numbers, "literal", letters, item, nullable

      assert.equal observableArray().length, 3 + 1 + 3 + 1

      assert.equal observableArray()[0], 1
      assert.equal observableArray()[3], "literal"
      assert.equal observableArray()[4], "a"
      assert.equal observableArray()[7], item()

      numbers.push 4

      assert.equal observableArray().length, 9

      nullable "cool"

      assert.equal observableArray().length, 10

    it "should work with observable functions that return arrays", ->
      item = Observable("wat")

      computedArray = Observable ->
        [item()]

      observableArray = Observable.concat computedArray, computedArray

      assert.equal observableArray().length, 2

      assert.equal observableArray()[1], "wat"

      item "yolo"

      assert.equal observableArray()[1], "yolo"

    it "should have a push method", ->
      observableArray = Observable.concat()

      observable = Observable "hey"

      observableArray.push observable

      assert.equal observableArray()[0], "hey"

      observable "wat"

      assert.equal observableArray()[0], "wat"

      observableArray.push "cool"
      observableArray.push "radical"

      assert.equal observableArray().length, 3

    it "should be observable", (done) ->
      observableArray = Observable.concat()

      observableArray.observe (items) ->
        assert.equal items.length, 3
        done()

      observableArray.push ["A", "B", "C"]

    it "should have an each method", ->
      observableArray = Observable.concat(["A", "B", "C"])

      n = 0
      observableArray.each () ->
        n += 1

      assert.equal n, 3

  describe "nesting dependencies", ->
    it "should update the correct observable", ->
      a = Observable "a"
      b = Observable "b"

      results = Observable ->
        r = Observable.concat()

        r.push a
        r.push b

        r

      # TODO: Should this just be
      #     results.first()
      assert.equal results().first(), "a"

      a("newA")

      assert.equal results().first(), "newA"
