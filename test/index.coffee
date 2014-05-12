test = require 'tape'
level = require('level-test')({mem: yes})

objectify = require('../')

db = level 'level-objectify-test', {valueEncoding: 'json'}
db2 = level 'level-objectify-test2', {valueEncoding: 'json'}

c1 = person: {gaius: {name: 'Gaius Baltar'}, six: {name: 'Six'}}
c2 = person: {gaius: {name: 'Gaius Baltar'}, kara: {name: 'Kara Thrace'}}
c3 = biped:
  human: {gaius: {name: 'Gaius Baltar'}, kara: {name: 'Kara Thrace'}}
  cylon: {six: {name: 'Six'}}
c4 = biped:
  human: {gaius: {name: 'Gaius Baltar'}}
  cylon: {six: {name: 'Six'}, boomer: {name: 'Boomer'}}

test 'identity', (t) ->
  patch = objectify({depth: 1}).computePatch {}, c1

  t.same patch, c1
  t.end()

test 'fill', (t) ->
  batch = objectify({depth: 1}).computeBatch {}, c1
  db.batch batch, (err) ->
    t.notOk err
    t.end()

test 'compile stream', (t) ->
  db.readStream().pipe objectify({depth: 1}).compile (err, prev) ->
    t.notOk err
    t.ok prev
    t.same prev, c1
    t.end()

test 'compute batch', (t) ->
  batch = objectify({depth: 1}).computeBatch c1, c2
  t.same batch, [
    { key: 'personÿsix', type: 'del' }
    { key: 'personÿkara', type: 'put', value: { name: 'Kara Thrace' } }
  ]
  t.end()

test 'deeper key', (t) ->
  batch = objectify({depth: 2}).computeBatch {}, c3

  t.same batch, [
    { key: 'bipedÿhumanÿgaius', type: 'put', value: { name: 'Gaius Baltar' } }
    { key: 'bipedÿhumanÿkara', type: 'put', value: { name: 'Kara Thrace' } }
    { key: 'bipedÿcylonÿsix', type: 'put', value: { name: 'Six' } }
  ]
  t.end()

test 'deeper key mod', (t) ->
  batch = objectify({depth: 2}).computeBatch c3, c4

  t.same batch, [
    { key: 'bipedÿhumanÿkara', type: 'del' }
    { key: 'bipedÿcylonÿboomer', type: 'put', value: { name: 'Boomer' } }
  ]
  t.end()

test 'save deeper key', (t) ->
  db2.batch objectify({depth: 2}).computeBatch({}, c3), (err) ->
    t.notOk err
    t.end()

test 'deeper key compile', (t) ->
  db2.readStream().pipe objectify({depth: 2}).compile (err, data) ->
    t.notOk err
    t.same data, c3
    t.end()

test 'zero depth', (t) ->
  batch = objectify({depth: 0}).computeBatch {}, c3
  batch1 = objectify({depth: 1}).computeBatch {}, c3
  t.notSame batch, batch1
  t.same batch, [{ key: 'biped', type: 'put', value: {
    cylon: { six: { name: 'Six' } }
    human: {
      gaius: { name: 'Gaius Baltar' },
      kara: { name: 'Kara Thrace' } }
    }
  }]
  t.end()

test 'multiple deletes', (t) ->
  c5 = {a: 'a', b: 'b', c: 'c', d: {e: 'e', f: 'f'}}
  c6 = {a: 'a', d: {e: 'e'}}

  batch = objectify({depth: 0}).computeBatch c5, c6

  t.same batch, [
    { key: 'b', type: 'del' },
    { key: 'c', type: 'del' },
    { key: 'd', type: 'put', value: { e: 'e' } } ]
  t.end()

test 'deep nesting', (t) ->
  c7 =
    a:
      a:
        b: 'b'
        c: 'b'
        d: 'e'
        f:
          g: [1,2,3]
    b: b: {b: 'b'}
    c: c: {c: 'c'}
    d: d: {e: 'e', f: 'f'}
    e:
      a:
        b: 'b'
        c: 'b'
        d: 'e'
        f:
          g: [1,2,3]
          h: ['x','y','z']

  c8 =
    a:
      a:
        b: 'b'
        c: 'b'
        d: 'e'
        f:
          g: [1,3] # dropped 2
    b: b: {b: 'b'}
    # dropped c: c: c
    d: {} # dropped d: d: {e: 'e', f: 'f'}
    e:
      a:
        b: 'b'
        c: 'b'
        d: 'e'
        f:
          g: [1,2,3]
          h:
            a: ['x','y','z'] # moved array to 'a'

  batch = objectify({depth: 2}).computeBatch c7, c8

  t.same batch, [
    {type: "del", key: "cÿcÿc"},
    {type: "put", key: "aÿaÿf", value: { g: [1, 3] }},
    {type: "del", key: "dÿdÿe"},
    {type: "del", key: "dÿdÿf"},
    {type: "put", key: "eÿaÿf", value: { g: [1, 2, 3], h: {a: ["x", "y", "z"]}} }
  ]
  t.end()
