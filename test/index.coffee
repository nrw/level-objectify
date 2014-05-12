test = require 'tape'
level = require('level-test')()

objectify = require('../')

db = level 'level-objectify-test', {valueEncoding: 'json'}

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

test 'batch', (t) ->
  batch = objectify({depth: 1}).convertPatch c1

  t.same batch, [
    { key: 'personÿgaius', type: 'put', value: { name: 'Gaius Baltar' } }
    { key: 'personÿsix', type: 'put', value: { name: 'Six' } }
  ]
  t.end()

test 'fill', (t) ->
  batch = objectify({depth: 1}).convertPatch c1
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
  #  wraps convertPatch(computePatch(p, n))
  batch = objectify({depth: 1}).computeBatch c1, c2
  t.same batch, [
    { key: 'personÿsix', type: 'del', value: 'six' }
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
    { key: 'bipedÿhumanÿkara', type: 'del', value: 'kara' }
    { key: 'bipedÿcylonÿboomer', type: 'put', value: { name: 'Boomer' } }
  ]
  t.end()

test 'save deeper key', (t) ->
  db = level 'level-objectify-test2', {valueEncoding: 'json'}
  db.batch objectify({depth: 2}).computeBatch({}, c3), (err) ->
    t.notOk err
    t.end()

test 'deeper key compile', (t) ->
  db.readStream().pipe objectify({depth: 2}).compile (err, data) ->
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
