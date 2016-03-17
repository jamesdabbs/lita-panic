# lita-panic

[![Build Status](https://travis-ci.org/jamesdabbs/lita-panic.png?branch=master)](https://travis-ci.org/jamesdabbs/lita-panic)
[![Coverage Status](https://coveralls.io/repos/jamesdabbs/lita-panic/badge.png)](https://coveralls.io/r/jamesdabbs/lita-panic)

![This is fine](http://i.imgur.com/Fp1O435.png)

## Installation

Add lita-panic to your Lita instance's Gemfile:

``` ruby
gem "lita-panic"
```

## Configuration

`hostname` - where your instance is deployed; will be used to generate the CSV export link

## Usage

Many commands require your account to be in the `instructors` or `staff` groups; be sure you have added one if needed.

* `Lita: how is everyone?` - privately prompts everyone in the current room for a panic score
* `Lita: how is everyone in #room?` - similarly, but in a specified room
* `Lita: panic export` - generates a link to download a CSV of all responses

N.B. The response parser is pretty dumb at the moment, and needs a _single_ digit (so no `3-4` or `3.5`).