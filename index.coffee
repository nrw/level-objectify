patcher = require 'patcher'
reduce = require 'stream-reduce'

exports = module.exports = (opts = {}) ->
  opts.separator or= '\xff'
  opts.depth or= 0
  opts.depth = 0 if opts.depth < 0

  computePatch = patcher.computePatch

  computeBatch = (prev, next) ->
    patch = computePatch prev, next

    # all docs at opts.depth in the patch need to be changed
    paths = getPaths patch, opts.depth

    # 'next' is in the state we want
    # create an operation for each doc in paths
    batch = []

    add = (type, path, value = null) ->
      key = path.join(opts.separator)
      obj = {type, key}
      obj.value = value if value
      batch.push obj

    for path in paths
      if path.length < opts.depth+1
        state = prev
        state = state?[key] for key in path
        keys = getKeys(state, path, opts.depth-path.length)

        add('del', key) for key in keys

      else
        state = next
        state = state?[key] for key in path
        if state
          add('put', path, state)
        else
          add('del', path)
    batch

  compile = (cb = ->) ->
    reducer = (acc, h) ->
      [prefix..., id] = h.key.split opts.separator

      obj = acc
      for fix in prefix
        obj[fix] or= {}
        obj = obj[fix]
      obj[id] = h.value
      acc

    stream = reduce reducer, {}
    stream.on 'data', (data) -> cb null, data
    stream.on 'err', cb

  {
    computeBatch, computePatch, compile
    writeStream: compile, createWriteStream: compile
  }

getKeys = (state, base, depth, acc = []) ->
  if depth < 0
    acc.push base
    return base

  for k, v of state
    path = base.slice(0)
    path.push k
    getKeys v, path, depth-1, acc
  acc

getPaths = (patch, depth, base = [], acc = []) ->
  if depth < 0
    acc.push base
    return base

  for k, v of patch
    path = base.slice(0)
    if k is '$r'
      v = [v] unless Array.isArray(v)
      for rm in v
        p = path.slice(0)
        p.push rm
        getPaths null, -1, p, acc
    else
      path.push k
      getPaths v, depth-1, path, acc

  acc
