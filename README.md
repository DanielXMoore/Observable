[![Build](https://github.com/DanielXMoore/Observable/actions/workflows/build.yml/badge.svg)](https://github.com/DanielXMoore/Observable/actions/workflows/build.yml)
[![Coverage Status](https://coveralls.io/repos/github/DanielXMoore/Observable/badge.svg?branch=master)](https://coveralls.io/github/DanielXMoore/Observable?branch=master)

Observable
==========

Installation
------------

Node

    npm @danielx/observable

Usage
-----

    Observable = require "@danielx/observable"

Get notified when the value changes.

    observable = Observable 5

    observable() # 5

    observable.observe (newValue) ->
      console.log newValue

    observable 10 # logs 10 to console

Arrays
------

Proxy array methods.

    observable = Observable [1, 2, 3]

    observable.forEach (value) ->
      # 1, 2, 3

Functions
---------

Automagically compute dependencies for observable functions.

    firstName = Observable "Duder"
    lastName = Observable "Man"

    o = Observable ->
      "#{firstName()} #{lastName()}"

    o.observe (newValue) ->
      assert.equal newValue, "Duder Bro"

    lastName "Bro"

Changelog
---------

### 0.6.0

- ES6 Exports

### 0.5.1

- Exporting TypeScript types
