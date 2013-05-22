http = require 'http'
nodeTor = require '../node_modules/node-Tor/lib/node-tor.js'

server = http.createServer (req,res)->
	res.end 'Test'


server.listen 8088
