yaml = require 'js-yaml'
fs = require 'fs'
template = require './template'
parallel = require './parallel'

# Helper functions to check types
isstring = (s) -> typeof s is 'string'
isnumber = (s) -> typeof s is 'number'
isstringarray = (s) ->
  return no if not s instanceof Array
  for i in s
    return no if !isstring i
  yes
ischeck = (s) ->
  return no if not s instanceof Array
  for key, value of c
    return no if !validation[key]?
    return no if !validation[key] value
  yes

# The expecations
validation =
  id: isstring
  name: isstring
  tags: isstringarray
  port: isnumber
  # Not supporting checks yet
  #check: ischeck

checkvalidation =
  script: isstring
  interval: isstring
  ttl: isstring

class DOPPELGANGERFormatException extends Error
  constructor: (message) ->
    @name = 'DOPPELGANGERFormatException'
    @message = message

load = (item, cb) ->
  fs.readFile item, encoding: 'utf8', (err, content) ->
    return cb [err] if err?
    try
      configurations = yaml.safeLoad content
    catch e
      return cb [e] if e?
    
    if !configurations? or not configurations instanceof Array
      return cb [
        new DOPPELGANGERFormatException 'This YAML file is in the wrong format. Doppelganger expects consul service configurations.'
      ]
    
    # Errors are reported as a list
    errors = []
    
    # replace templates
    configurations = template configurations
    
    results = {}
    
    for c in configurations
      haderror = no
      for key, value of c
        if !validation[key]?
          errors.push new DOPPELGANGERFormatException "#{key} is not a known configuration option."
          haderror = yes
        else if !validation[key] value
          errors.push new DOPPELGANGERFormatException "#{key} was an unexpected format."
          haderror = yes
      
      continue if haderror
      
      # We always add the doppelganger tag
      result =
        ID: c.id
        Name: c.name
        Tags: ['doppelganger']
        Port: c.port
      # Append tags
      result.Tags = result.Tags.concat c.tags if c.tags?
      # Use the name as the ID if not provided
      result.ID = result.Name if !result.ID?
      # Use 0 as the port - default for consul
      result.Port = 0 if !result.Port?
      results[result.ID] = result
    
    return cb errors if errors.length isnt 0
    cb null, results

module.exports = (dir, callback) ->
  try
    items = fs.readdirSync dir
  catch e
    return callback [e]
  
  tasks = []
  errors = []
  results = {}
  
  for item in items
    continue if !item.match /\.yml$/
    do (item) ->
      tasks.push (cb) ->
        item = "#{dir}/#{item}"
        load item, (errs, config) ->
          if errs?
            errors.push path: item, errors: errs
            return cb()
          results[k] = v for k, v of config
          cb()
  
  # Async power
  parallel tasks, ->
    return callback errors, results if errors.length isnt 0
    callback null, results