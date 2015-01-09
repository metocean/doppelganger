Doppelganger = require '../src/doppelganger'
doppelganger = new Doppelganger
process.on 'SIGHUP', doppelganger.tick
process.on 'uncaughtException', (err) ->
    console.error err
    process.exit 1