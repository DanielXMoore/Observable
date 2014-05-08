Observable
==========

Installation
------------

Node

    npm install git://github.com/distri/observable#npm-v0.1.2

Distri

    dependencies:
      observable: "distri/observable:v0.1.2"
      ...

Usage
-----

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
