# Nifty method for working with console text
colors = require './colors'

for prop of colors
	# Sometimes this one doesn't work for some reason... eval is
	# discouraged by the js community, but it works every time
	#@[prop] = colors[prop]
	eval prop + ' = colors[prop]'

http             = require 'http'
httpProxy        = require 'http-proxy'
qs               = require 'querystring'
jsdom            = require 'jsdom'
util             = require 'util'
mongoose         = require 'mongoose' 
hideMyAssGrabber = require './proxyGrabbers/hidemyass'
config           = require '../config.json'
net              = require 'net'
util             = require 'util'

lastChange       = null
currentProxy     = null

mongoose.connect 'mongodb://localhost/ipchanger'

db = mongoose.connection

db.on 'error', console.error.bind(console, 'connection error:')

ProxyServer = null

setupDatabase = (cb)->
	proxyServerSchema = mongoose.Schema({
		'Last-Update':String
		'ipaddress':String
		'port': Number
		'country':String
		'speed': Number
		'connectionTime': Number
		'ping':
			'type': Number
			'default':-1
		'from':String
		'type':String
		'annon':String
		'last-used': 
			'type': Date
			'default': new Date()
		'last-durration': 
			'type': Number
			'default': 0
	})

	proxyServerSchema.methods.pingServer = ()->
		#console.log "Here I would ping #{this.ipaddress} on port #{this.port}"

	ProxyServer = mongoose.model 'ProxyServer', proxyServerSchema

	if cb != null and typeof cb is "function"
		cb()

setupGrabbers = ()->
	hideMyAssGrabber.setup ProxyServer, db, mongoose
	# One hour (1000 ms in one sec, 60 sec in one min, 60 min in one hour)
	#                                 ms to hr constant * hours
	hideMyAssGrabber.setUpdateInterval( config.updateInterval )
	hideMyAssGrabber.autoUpdate true
	hideMyAssGrabber.update()


db.once 'open', ()->
	setupDatabase ()->
		setupGrabbers()
		updateProxy()
		startServer()



server = http.createServer (req,res)->
	req.on 'data', (data)->

	req.on 'end', ()->
		res.writeHead 200, "Content-Type":"text/plain"
		res.write "Current proxy grabbers: \n\tHide My Ass\tDomain: hidemyass.com\tLast Updated: #{hideMyAssGrabber.lastUpdated()}\tNext Update: #{hideMyAssGrabber.nextUpdate()}\n"

		res.write "\nServers in database: \n"
 
		ProxyServer.find (err, servers)->
			for server in servers
				if _i > 0
					res.write '\n\n'

				res.write 'Server ' + _i

				res.write '\n\t' + 'Last-Update     ' + server['Last-Update']
				res.write '\n\t' + 'ipaddress       ' + server['ipaddress']
				res.write '\n\t' + 'port            ' + server['port']
				res.write '\n\t' + 'country         ' + server['country']
				res.write '\n\t' + 'speed           ' + server['speed']
				res.write '\n\t' + 'connectionTime  ' + server['connectionTime']
				res.write '\n\t' + 'ping            ' + server['ping']
				res.write '\n\t' + 'from            ' + server['from']
				res.write '\n\t' + 'type            ' + server['type']
				res.write '\n\t' + 'annon           ' + server['annon']
				res.write '\n\t' + 'last-used       ' + server['last-used']
				res.write '\n\t' + 'last-durration  ' + server['last-durration'] 

				if _i is _len
					res.end "****************************************\n          No More Proxy Servers\n****************************************\n"

updateProxy = ()->

	ProxyServer.find().sort("speed").exec (err, servers)->
		logX red, err if err
		for server in servers

			if server["last-durration"] < config['max-time'] or server["last-used"].getTime() < Date.now() - config['reset-time']
				# TODO: Check to see if the proxy server is up
				
				logX ltYellow, "Now using proxy server #{server.ipaddress} on port #{server.port} with speed #{server.speed}!"
				
				if currentProxy != null and lastChange != null
					currentProxy["last-used"] = lastChange
					currentProxy["last-durration"] = Date.now() - lastChange.getTime()
					currentProxy.save (err)->
						console.error err if err

				lastChange = new Date()
				currentProxy = server

				return


startServer = ()->
	logX bgGreen + black, "\t\t\t\t\t\t\tStarting Server\t\t\t\t\t\t\t"
	logX ltGreen, "Running on port #{config['http-port']}\n"
	server.listen config['http-port']


	forwardServer = net.createServer (clientSocket)->
		connected = false
		buffers = new Array()
		proxySocket = new net.Socket()


		proxySocket.connect currentProxy.port, currentProxy.ipaddress, ()->
			logX ltYellow, "Connected to proxy 108.41.35.10 21858"
			connected = true

			if buffers.length > 0
				for buffer in buffers
					proxySocket.write buffer

		clientSocket.on 'error', (e)->
			console.log red + "client socekt error"
			console.error e
			console.log reset
			proxySocket.end()

		proxySocket.on 'error', (e)->
			console.log red + "proxy socket error"
			console.error e
			console.log reset
			clientSocket.end()

		proxySocket.on 'data', (data)->
			clientSocket.write data

		proxySocket.on 'end', ()->
			clientSocket.end()

		clientSocket.on 'end', ()->
			clientSocket.end()

		clientSocket.on 'data', (data)->
			if connected
				proxySocket.write data
			else
				buffers[buffers.length] = data


		clientSocket.on 'close', (did_error)->
			proxySocket.end()

		proxySocket.on 'close', (did_error)->
			clientSocket.end()
	# End of proxy connection handler


	forwardServer.listen config['proxy-port'], ()->
		logX bgGreen + black, "Forward server bound on port " + config['proxy-port']

	setInterval ()->
		logX ltRed, "rotating"
		updateProxy()
	, config['rotateInterval']
# End of function start server
