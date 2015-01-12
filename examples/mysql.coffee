module.exports =
  config: tcp: port: 3306
  bind: (redwire, bindings) ->
    bindings
      .tcp  'anotherserver:3306'
