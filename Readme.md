# level-objectify [![build status](https://secure.travis-ci.org/nrw/level-objectify.png)](http://travis-ci.org/nrw/level-objectify)

Compile the contents of a leveldb read stream into an object and create a patch for changes as a batch update.

[![testling badge](https://ci.testling.com/nrw/level-objectify.png)](https://ci.testling.com/nrw/level-objectify)

## Example

```js
level = require('level-test')()
objectify = require('../')

db = level 'level-objectify-test', {valueEncoding: 'json'}

var c1 = {
  person: {
    gaius: {name: 'Gaius Baltar'},
    six: {name: 'Six'}
  }
}

// {depth: 1} = use the first layer of keys as a prefix to their children
var batch = objectify({depth: 1}).computeBatch({}, c1)
// returns a valid leveldb batch of operations.
// [
//   { key: 'personÿgaius', type: 'put', value: { name: 'Gaius Baltar' } },
//   { key: 'personÿsix', type: 'put', value: { name: 'Six' } }
// ]

db.batch(batch)

// with data already in the db, the contents can be objectified
db.readStream().pipe(objectify({depth: 1}).compile(function (err, result) {
  if (err) return console.log('problem', err)

  // `result` matches the object we started with!
  assert.deepEqual(c1, result)
  // see the tests for more examples.
}))
```

## Usage

### var obj = objectify(opts={})

#### options

- `opts.depth = 0` the depth of key that should be used as a prefix for each property
- `opts.separator = '\xff'` the string to use to separate sections of the prefix.

## Methods

### obj.compile(callback(err, result))

Returns a writable stream that expects data in the format `{key: ..., value: ...}`
(like the data emitted by `level.readStream()`). When the stream ends, `callback`
is called with any error and the compiled result.

### obj.computeBatch(prev, next)

Returns a batch operations array (compatible with `leveldb`) that will patch the
database in the state `prev` to match the state of `next`. Behind the scenes,
this method just calls `obj.convertPatch(obj.computePatch(prev, next))`.

### obj.computePatch(prev, next)

Exports `computePatch()` from [patcher](https://www.npmjs.org/package/patcher).

## Contributing

Please make any changes to the `.coffee` source files and `npm build` before
sending a pull request.

## License

MIT
