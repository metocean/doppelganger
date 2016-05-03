usage = """

Usage: doppelganger [source] [target] [services...]

  source        Copy from this consul http api address
  target        Save to this consul http api address
  directory     Read configuration files from this directory

"""

onerror = (err) -> console.error err.stack ? err

args = process.argv.slice 2
if args.length < 2
  console.log usage
  process.exit 1

[sourceHttpAddr, targetHttpAddr, servicesToSync...] = args
configDir = process.cwd()



consul = require 'consul-utils'
mb = require 'meatbag'
url_parse = require('url').parse
http = require 'http'
async = require 'odo-async'

deregister = (httpAddr, id, cb) ->
  http
    .get "http://#{httpAddr}/v1/agent/service/deregister/#{encodeURIComponent id}", -> cb null
    .on 'error', cb

register = (httpAddr, service, cb) ->
  params = url_parse "http://#{httpAddr}"
  params.path = '/v1/agent/service/register'
  params.method = 'PUT'
  res = http
    .request params, -> cb null
    .on 'error', cb
  res.write JSON.stringify service
  res.end()

get = (url, cb) ->
  http
    .get url, (res) ->
      res.setEncoding 'utf8'
      if res.statusCode isnt 200
        error = ''
        res.on 'data', (data) -> error += data
        return res.on 'end', -> cb error
      body = ''
      res.on 'data', (data) -> body += data
      res.on 'end', -> cb null, JSON.parse body
    .on 'error', cb


getservices = (httpAddr, id, cb) ->
  get "http://#{httpAddr}/v1/catalog/service/#{encodeURIComponent id}", cb

getagentservices = (httpAddr, cb) ->
  get "http://#{httpAddr}/v1/agent/services", cb

getaddress = (service) ->
  return service.Address if !service.ServiceAddress?
  return service.Address if service.ServiceAddress is ''
  service.ServiceAddress

getid = (service) ->
  "#{getaddress service}/#{service.ServiceID}"

byserviceidsource = (services) ->
  result = {}
  for service in services
    result[getid service] = service
  result

byserviceidtarget = (services) ->
  result = {}
  for service in services
    result[service.ServiceID] = service
  result


createService = (id, service, cb) ->
  service =
    ID: id
    Name: service.ServiceName
    Tags: service.ServiceTags
    Port: service.ServicePort
    Address: getaddress service
  register targetHttpAddr, service, (err) ->
    onerror err if err?
    console.log " + #{id}"
    cb()

updateService = (id, service, cb) ->
  service =
    ID: id
    Name: service.ServiceName
    Tags: service.ServiceTags
    Port: service.ServicePort
    Address: getaddress service
  register targetHttpAddr, service, (err) ->
    onerror err if err?
    console.log " . #{id}"
    cb()

deleteService = (id, service, cb) ->
  deregister targetHttpAddr, id, (err) ->
    onerror err if err?
    console.log " - #{id}"
    cb()

convertfromwatch = (service) ->
  Address: service.address
  ServiceID: service.id
  ServiceName: service.name
  ServiceTags: service.tags
  ServicePort: service.port

# this section should retry with a timeout
services = {}
getagentservices targetHttpAddr, (err, targetAgentServices) ->
  servicesToCreate = {}
  servicesToUpdate = {}
  servicesToDelete = {}
  targetAgentServices = Object.keys(targetAgentServices).map (id) ->
    service = targetAgentServices[id]
    Address: service.Address
    ServiceID: service.ID
    ServiceName: service.Service
    ServiceTags: service.Tags
    ServicePort: service.Port
  diffTasks = servicesToSync.map (servicename) -> (cb) ->
    getservices sourceHttpAddr, servicename, (err, sourceServices) ->
      sourceServices = byserviceidsource sourceServices
      targetServices = byserviceidtarget targetAgentServices.filter (service) ->
        service.ServiceName is servicename
      for id, service of sourceServices
        if targetServices[id]?
          # TODO: diff to update?
          #servicesToUpdate[id] = service
        else
          servicesToCreate[id] = service
        services[id] = service
      for id, service of targetServices
        continue if sourceServices[id]?
        servicesToDelete[id] = service
      cb()
  async.series diffTasks, ->
    updateTasks = []
    updateTasks = updateTasks.concat Object.keys(servicesToCreate).map (id) -> (cb) ->
      createService id, servicesToCreate[id], cb
    updateTasks = updateTasks.concat Object.keys(servicesToUpdate).map (id) -> (cb) ->
      updateService id, servicesToUpdate[id], cb
    updateTasks = updateTasks.concat Object.keys(servicesToDelete).map (id) -> (cb) ->
      deleteService id, servicesToDelete[id], cb
    async.series updateTasks, ->
      watches = {}
      watchservice = (name) ->
        watches[name] = new consul.Service sourceHttpAddr, name, (added, removed) ->
          added = added.map convertfromwatch
          removed = removed.map convertfromwatch
          for service in added
            id = getid service
            # TODO: diff to update?
            continue if services[id]?
            createService id, service, (err) ->
              services[id] = service
              onerror err if err?
          for service in removed
            id = getid service
            if services[service.id]?
              deleteService id, service, (err) ->
                delete services[service.id]
                onerror err if err?


      console.log "#{mb.plural servicesToSync.length, 'service', 'services'} syncing from #{sourceHttpAddr} -> #{targetHttpAddr}"
      watchservice servicename for servicename in servicesToSync

      hascleaned = no
      clean = (cb) ->
        if !cb?
          cb = ->
        return cb() if hascleaned
        hascleaned = yes
        deleteTasks = Object.keys(services).map (id) -> (cb) ->
          service = services[id]
          deleteService id, service, (err) ->
            delete services[service.id]
            onerror err if err?
            cb()
        async.series deleteTasks, cb

      process.on 'exit', -> clean()
      process.on 'SIGINT', -> clean -> process.exit 0
      process.on 'SIGTERM', -> clean -> process.exit 0
      process.on 'uncaughtException', (err) ->
        onerror err
        process.exit 1
