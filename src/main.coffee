# Nifty method for working with console text
colors = require './colors'

for prop of colors
	# Sometimes this one doesn't work for some reason... eval is
	# discouraged by the js community, but it works every time
	#@[prop] = colors[prop]
	eval prop + ' = colors[prop]'

http             = require 'http'
proxy            = require 'http-proxy'
nodeTor          = require '../node_modules/node-Tor/lib/node-tor.js'
qs               = require 'querystring'
jsdom            = require 'jsdom'
util             = require 'util'
mongoose         = require 'mongoose' 
hideMyAssGrabber = require './proxyGrabbers/hidemyass'

mongoose.connect 'mongodb://localhost/ipchanger'

db = mongoose.connection

db.on 'error', console.error.bind(console, 'connection error:')

ProxyServer = null

db.once 'open', ()->

	proxyServerSchema = mongoose.Schema({
		'Last-Update':String
		'ipaddress':String
		'port':String
		'country':String
		"speed":String
		"connectionTime":String
		"ping":String
		"from":String
	})

	proxyServerSchema.methods.pingServer = ()->
		#console.log "Here I would ping #{this.ipaddress} on port #{this.port}"

	ProxyServer = mongoose.model 'ProxyServer', proxyServerSchema

	hideMyAssGrabber.setup ProxyServer, db, mongoose
	hideMyAssGrabber.update()
	# One hour (1000 ms in one sec, 60 sec in one min, 60 min in one hour)
	#                                 ms to hr constant * hours
	hideMyAssGrabber.setUpdateInterval( (1000 * 60 * 60) * 6 )
	hideMyAssGrabber.autoUpdate true

	startServer()


server = http.createServer (req,res)->
	req.on 'data', (data)->

	req.on 'end', ()->
		res.writeHead 200, "Content-Type":"text/plain"
		res.write "Current proxy grabbers: \n\tHide My Ass\tDomain: hidemyass.com\tLast Updated: #{hideMyAssGrabber.lastUpdated()}\tNext Update: #{hideMyAssGrabber.nextUpdate()}\n"

		res.write "\nServers in database: \n"
 
		ProxyServer.find (err, servers)->
			res.write util.inspect servers
			res.end "****************************************\n          No More Proxy Servers\n****************************************\n"

startServer = ()->
	logX bgGreen + black, "\t\t\t\t\t\t\tStarting Server\t\t\t\t\t\t\t"
	server.listen 8088