// Generated by CoffeeScript 1.9.2
var args, async, byserviceidsource, byserviceidtarget, configDir, consul, convertfromwatch, createService, deleteService, deregister, get, getaddress, getagentservices, getid, getservices, http, mb, onerror, register, services, servicesToSync, sourceHttpAddr, targetHttpAddr, updateService, url_parse, usage,
  slice = [].slice;

usage = "\nUsage: doppelganger [source] [target] [services...]\n\n  source        Copy from this consul http api address\n  target        Save to this consul http api address\n  directory     Read configuration files from this directory\n";

onerror = function(err) {
  var ref;
  return console.error((ref = err.stack) != null ? ref : err);
};

args = process.argv.slice(2);

if (args.length < 2) {
  console.log(usage);
  process.exit(1);
}

sourceHttpAddr = args[0], targetHttpAddr = args[1], servicesToSync = 3 <= args.length ? slice.call(args, 2) : [];

configDir = process.cwd();

consul = require('consul-utils');

mb = require('meatbag');

url_parse = require('url').parse;

http = require('http');

async = require('odo-async');

deregister = function(httpAddr, id, cb) {
  return http.get("http://" + httpAddr + "/v1/agent/service/deregister/" + (encodeURIComponent(id)), function() {
    return cb(null);
  }).on('error', cb);
};

register = function(httpAddr, service, cb) {
  var params, res;
  params = url_parse("http://" + httpAddr);
  params.path = '/v1/agent/service/register';
  params.method = 'PUT';
  res = http.request(params, function() {
    return cb(null);
  }).on('error', cb);
  res.write(JSON.stringify(service));
  return res.end();
};

get = function(url, cb) {
  return http.get(url, function(res) {
    var body, error;
    res.setEncoding('utf8');
    if (res.statusCode !== 200) {
      error = '';
      res.on('data', function(data) {
        return error += data;
      });
      return res.on('end', function() {
        return cb(error);
      });
    }
    body = '';
    res.on('data', function(data) {
      return body += data;
    });
    return res.on('end', function() {
      return cb(null, JSON.parse(body));
    });
  }).on('error', cb);
};

getservices = function(httpAddr, id, cb) {
  return get("http://" + httpAddr + "/v1/catalog/service/" + (encodeURIComponent(id)), cb);
};

getagentservices = function(httpAddr, cb) {
  return get("http://" + httpAddr + "/v1/agent/services", cb);
};

getaddress = function(service) {
  if (service.ServiceAddress == null) {
    return service.Address;
  }
  if (service.ServiceAddress === '') {
    return service.Address;
  }
  return service.ServiceAddress;
};

getid = function(service) {
  return (getaddress(service)) + "/" + service.ServiceID;
};

byserviceidsource = function(services) {
  var i, len, result, service;
  result = {};
  for (i = 0, len = services.length; i < len; i++) {
    service = services[i];
    result[getid(service)] = service;
  }
  return result;
};

byserviceidtarget = function(services) {
  var i, len, result, service;
  result = {};
  for (i = 0, len = services.length; i < len; i++) {
    service = services[i];
    result[service.ServiceID] = service;
  }
  return result;
};

createService = function(id, service, cb) {
  service = {
    ID: id,
    Name: service.ServiceName,
    Tags: service.ServiceTags,
    Port: service.ServicePort,
    Address: getaddress(service)
  };
  return register(targetHttpAddr, service, function(err) {
    if (err != null) {
      onerror(err);
    }
    console.log(" + " + id);
    return cb();
  });
};

updateService = function(id, service, cb) {
  service = {
    ID: id,
    Name: service.ServiceName,
    Tags: service.ServiceTags,
    Port: service.ServicePort,
    Address: getaddress(service)
  };
  return register(targetHttpAddr, service, function(err) {
    if (err != null) {
      onerror(err);
    }
    console.log(" . " + id);
    return cb();
  });
};

deleteService = function(id, service, cb) {
  return deregister(targetHttpAddr, id, function(err) {
    if (err != null) {
      onerror(err);
    }
    console.log(" - " + id);
    return cb();
  });
};

convertfromwatch = function(service) {
  return {
    Address: service.address,
    ServiceID: service.id,
    ServiceName: service.name,
    ServiceTags: service.tags,
    ServicePort: service.port
  };
};

services = {};

getagentservices(targetHttpAddr, function(err, targetAgentServices) {
  var diffTasks, servicesToCreate, servicesToDelete, servicesToUpdate;
  if (err != null) {
    onerror(err);
    process.exit(1);
  }
  servicesToCreate = {};
  servicesToUpdate = {};
  servicesToDelete = {};
  targetAgentServices = Object.keys(targetAgentServices).map(function(id) {
    var service;
    service = targetAgentServices[id];
    return {
      Address: service.Address,
      ServiceID: service.ID,
      ServiceName: service.Service,
      ServiceTags: service.Tags,
      ServicePort: service.Port
    };
  });
  diffTasks = servicesToSync.map(function(servicename) {
    return function(cb) {
      return getservices(sourceHttpAddr, servicename, function(err, sourceServices) {
        var id, service, targetServices;
        if (err != null) {
          onerror(err);
          process.exit(1);
        }
        sourceServices = byserviceidsource(sourceServices);
        targetServices = byserviceidtarget(targetAgentServices.filter(function(service) {
          return service.ServiceName === servicename;
        }));
        for (id in sourceServices) {
          service = sourceServices[id];
          if (targetServices[id] != null) {

          } else {
            servicesToCreate[id] = service;
          }
          services[id] = service;
        }
        for (id in targetServices) {
          service = targetServices[id];
          if (sourceServices[id] != null) {
            continue;
          }
          servicesToDelete[id] = service;
        }
        return cb();
      });
    };
  });
  return async.series(diffTasks, function() {
    var updateTasks;
    updateTasks = [];
    updateTasks = updateTasks.concat(Object.keys(servicesToCreate).map(function(id) {
      return function(cb) {
        return createService(id, servicesToCreate[id], cb);
      };
    }));
    updateTasks = updateTasks.concat(Object.keys(servicesToUpdate).map(function(id) {
      return function(cb) {
        return updateService(id, servicesToUpdate[id], cb);
      };
    }));
    updateTasks = updateTasks.concat(Object.keys(servicesToDelete).map(function(id) {
      return function(cb) {
        return deleteService(id, servicesToDelete[id], cb);
      };
    }));
    return async.series(updateTasks, function() {
      var clean, hascleaned, i, len, servicename, watches, watchservice;
      watches = {};
      watchservice = function(name) {
        new Watch(httpAddr + "/v1/catalog/service/" + serviceId, (function(_this) {
          return function(services) {};
        })(this));
        return watches[name] = new consul.Service(sourceHttpAddr, name, function(added, removed) {
          var i, id, j, len, len1, results, service;
          console.log((added.map(function(s) {
            return s.id;
          }).join(', ')) + " added, " + (removed.map(function(s) {
            return s.id;
          }).join(', ')) + " removed");
          added = added.map(convertfromwatch);
          removed = removed.map(convertfromwatch);
          for (i = 0, len = added.length; i < len; i++) {
            service = added[i];
            id = getid(service);
            if (services[id] != null) {
              continue;
            }
            createService(id, service, function(err) {
              services[id] = service;
              if (err != null) {
                return onerror(err);
              }
            });
          }
          results = [];
          for (j = 0, len1 = removed.length; j < len1; j++) {
            service = removed[j];
            id = getid(service);
            if (services[service.id] != null) {
              results.push(deleteService(id, service, function(err) {
                delete services[service.id];
                if (err != null) {
                  return onerror(err);
                }
              }));
            } else {
              results.push(void 0);
            }
          }
          return results;
        });
      };
      console.log((mb.plural(servicesToSync.length, 'service', 'services')) + " syncing from " + sourceHttpAddr + " -> " + targetHttpAddr);
      for (i = 0, len = servicesToSync.length; i < len; i++) {
        servicename = servicesToSync[i];
        watchservice(servicename);
      }
      hascleaned = false;
      clean = function(cb) {
        var deleteTasks;
        if (cb == null) {
          cb = function() {};
        }
        if (hascleaned) {
          return cb();
        }
        hascleaned = true;
        deleteTasks = Object.keys(services).map(function(id) {
          return function(cb) {
            var service;
            service = services[id];
            return deleteService(id, service, function(err) {
              delete services[service.id];
              if (err != null) {
                onerror(err);
              }
              return cb();
            });
          };
        });
        return async.series(deleteTasks, cb);
      };
      process.on('exit', function() {
        return clean();
      });
      process.on('SIGINT', function() {
        return clean(function() {
          return process.exit(0);
        });
      });
      process.on('SIGTERM', function() {
        return clean(function() {
          return process.exit(0);
        });
      });
      return process.on('uncaughtException', function(err) {
        onerror(err);
        return process.exit(1);
      });
    });
  });
});
