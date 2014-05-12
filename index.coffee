patcher = require 'patcher'
reduce = require 'stream-reduce'

exports = module.exports = (opts = {}) ->
  opts.separator or= '\xff'
  opts.depth or= 0

  computePatch = patcher.computePatch

  convertPatch = (patch) ->
    batch = []
    walkDiff batch, patch, [], opts
    batch

  computeBatch = (prev, next) ->
    patch = computePatch prev, next
    convertPatch patch

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
    computeBatch, computePatch, convertPatch, compile
    writeStream: compile
    createWriteStream: compile
  }

walkDiff = (batch, obj, path, opts) ->
  base = path

  for key, value of obj
    path = base.slice(0)
    path.push key

    if path.length - 1 >= opts.depth
      # bank change
      finish batch, value, path, opts
    else
      # recurse
      walkDiff batch, value, path, opts
  null

finish = (batch, value, path, opts) ->
  if path[path.length-1] is '$r'
    path.pop()
    path.push value
    type = 'del'
  else
    type = 'put'
  batch.push chg type, path.join(opts.separator), value

chg = (type, key, value) ->
  obj = {type, key}
  obj.value = value if value
  obj
