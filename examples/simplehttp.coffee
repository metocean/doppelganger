module.exports =
  config: http: port: 8888
  bind: (redwire, bindings) ->
    bindings
      .http 'http://localhost:8888/'
      .use redwire.setHost 'www.google.co.nz'
      .use redwire.proxy 'http://www.google.co.nz/'

