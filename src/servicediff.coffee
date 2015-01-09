servicediff = (source, target) ->
  if source.Name isnt target.Name
    return "Name different #{source.Name} -> #{target.Name}"
  if source.Port isnt target.Port
    return "Port different #{source.Port} -> #{target.Port}"
  if source.Tags.length isnt target.Tags.length
    return "Different tags (#{source.Tags.join ', '}) -> (#{target.Tags.join ', '})"
  for tag in target.Tags.length
    unless tag in source.Tags
      return "New tag #{tag}"
  null

module.exports = (services, config, callback) ->
  parsedservices = {}
  for _, s of services
    continue unless s.Tags and 'doppelganger' in s.Tags
    parsedservices[s.ID] =
      ID: s.ID
      Name: s.Service
      Tags: s.Tags
      Port: s.Port
  
  pool = {}
  pool[k] = v for k, v of parsedservices
  
  result = added: {}, removed: {}, modified: {}, unchanged: {}
  for id, service of config
    if pool[id]?
      difference = servicediff pool[id], service
      if !difference?
        result.unchanged[id] = service
      else
        console.log difference
        result.modified[id] = service
      delete pool[id]
    else
      result.added[id] = service
  # Anything left over is removed
  result.removed[k] = v for k, v of pool
  result