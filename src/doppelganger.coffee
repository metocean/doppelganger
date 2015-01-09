consul = require 'consul-utils'
configuration = require './configuration'
servicediff = require './servicediff'
series = require './series'

url_parse = require('url').parse
http = require 'http'

deregister = (httpAddr, id, callback) ->
  http
    .get "#{httpAddr}/v1/agent/service/deregister/#{id}", (res) -> callback null
    .on 'error', callback

register = (httpAddr, service, callback) ->
  params = url_parse httpAddr
  params.path = '/v1/agent/service/register'
  params.method = 'PUT'
  res = http
    .request params, (res) -> callback null
    .on 'error', callback
  res.write JSON.stringify service
  res.end()

# Copy all of the properties on source to target, recurse if an object
copy = (source, target) ->
  for key, value of source
    if typeof value is 'object'
      target[key] = {} if !target[key]? or typeof target[key] isnt 'object'
      copy value, target[key]
    else
      target[key] = value

module.exports = class Doppelganger
  constructor: (options) ->
    @_options =
      configurationdir: process.cwd()
      consulhost: process.env.CONSUL_HOST ? '127.0.0.1:8500'
      refresh: no
    
    copy options, @_options
    
    if @_options.consulhost.indexOf('http://') isnt 0
      @_options.consulhost = "http://#{@_options.consulhost}"
    
    @tick()
    
    noop = ->
    # Stay alive even with nothing listening
    @_interval = if @_options.refresh
      setInterval @tick, @_options.refresh
    else
      setInterval noop, 60000
  
  error: (error) =>
    if error.stack?
      console.error error.stack
    else
      console.error error
  
  # Trall through the directory looking for .yml files
  # Errors are returned as a list
  tick: =>
    configuration @_options.configurationdir, (errors, config) =>
      if errors?
        @error e for e in errors
        return
      consul.AgentServices @_options.consulhost, (errs, services) =>
        if errors?
          @error e for e in errors
          return
        
        tasks = []
        @update servicediff services, config
  
  update: (diff) =>
    tasks = []
    
    for id, _ of diff.removed
      do (id) =>
        tasks.push (cb) =>
          console.log "Deleting #{id}..."
          deregister @_options.consulhost, id, (err) =>
            @error err if err?
            cb()
    
    for id, service of diff.modified
      do (id, service) =>
        tasks.push (cb) =>
          console.log "Recreating #{id}..."
          deregister @_options.consulhost, id, (err) =>
            @error err if err?
            register @_options.consulhost, service, (err) =>
              @error err if err?
              cb()
    
    for id, service of diff.added
      do (id, service) =>
        tasks.push (cb) =>
          console.log "Creating #{id}..."
          register @_options.consulhost, service, (err) =>
            @error err if err?
            cb()
    
    if tasks.length is 0
      console.log 'Everything is up to date'
    else
      series tasks, =>
        console.log 'Doppelganger changes complete'
  
  close: =>
    clearInterval @_interval