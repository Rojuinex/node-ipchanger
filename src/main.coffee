Array.prototype.in = (item)->
	for val in this
		if val is item
			return true
		if _i + 1 is _len
			return false


# Nifty method for working with console text
colors = require './colors'

for prop of colors
	# Sometimes this one doesn't work for some reason... eval is
	# discouraged by the js community, but it works every time
	#@[prop] = colors[prop]
	eval prop + ' = colors[prop]'

process.on 'uncaughtException', (err)->
	errorX red, "Uncaught error!!!"
	errorX red, err.stack


http               = require 'http'
qs                 = require 'querystring'
jsdom              = require 'jsdom'
util               = require 'util'
mongoose           = require 'mongoose' 
hideMyAssGrabber   = require './proxyGrabbers/hidemyass'
config             = require '../config.json'
blacklist          = require '../blacklist.json'
net                = require 'net'
util               = require 'util'

lastChange         = null
currentProxy       = null
proxyServerStarted = false
forwardServer      = null
connResetCounter   = 0

mongoose.connect 'mongodb://localhost/ipchanger'

db = mongoose.connection

db.on 'error', console.error.bind(console, new Date() + '\nconnection error:')

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
			'default': 0
		'last-duration': 
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
	#hideMyAssGrabber.setUpdateInterval( config.updateInterval )
	#hideMyAssGrabber.autoUpdate true
	hideMyAssGrabber.update ()->
		setTimeout updateProxy, 1000


db.once 'open', ()->
	setupDatabase ()->
		startServer()
		setupGrabbers()
		


updating = false
updateProxy = ()->
	return if updating
	updating = true
	foundProxy = false

	logX bgBlue + ltYellow, "Updating proxy..."

	checkProxy = (server,cb)->
		timeOutFunction = null
		proxySocket = new net.Socket()
		connected = false

		proxySocket.connect server.port, server.ipaddress, ()->
			connected = true

		proxySocket.on 'error', (e)->
			if e.code is "ECONNREFUSED"
				server['last-duration'] = config['max-time']
				server['last-used'] = Date.now()
				server.save (err)->
					errorX red, "Save error " + err if err
				logX ltYellow, "Server #{server.ipaddress}:#{server.port} not active!"
				if !connected and !foundProxy
					cb false
			else
				errorX red, "Check Proxy error " + e.stack

		proxySocket.on 'connect', ()->
			logX blue, "connected to proxy #{server.ipaddress}:#{server.port}" if config.loglevel.verbose
			connected = true
			foundProxy = true
			cb true
			if timeOutFunction != null
				clearTimeout timeOutFunction
			proxySocket.end()

		timeOutFunction = setTimeout ()->
			if !connected
				proxySocket.end()
				cb false
		, 5000

	index = 0

	findNext = (servers)->
		return if foundProxy
		len = servers.len
		if index is len
			index = 0

		server = servers[index++]

		if currentProxy != null and server.ipaddress is currentProxy.ipaddress
			return findNext servers, index
		
		if blacklist.in(server.ipaddress)
			logX bgRed + black, "Server "+server.ipaddress + " is blacklisted!"
			return findNext servers,index


		if config.loglevel.verbose
			logX blue, "trying server #{server.ipaddress}:#{server.port}" 
		
		if server["last-duration"] < config['max-time'] or server["last-used"].getTime() < Date.now() - config['reset-time']
			# TODO: Check to see if the proxy server is up

			checkProxy server,(active)->
				if active
					logX ltYellow, "Now using proxy server #{server.ipaddress} on port #{server.port} with speed #{server.speed}!"
					if config.loglevel.verbose
						logX blue, "Selected because last duration " + (server["last-duration"] < config['max-time']) + " Reset Time passed " + (server["last-used"].getTime() < Date.now() - config['reset-time'])
						logX blue, "\tLast Duration #{server['last-duration']}"
						logX blue, "\tLast Used #{server["last-used"].getTime()}"

					lastChange = new Date()
					currentProxy = server
					updating = false
					if !proxyServerStarted
						startProxyServer()
				else
					findNext servers
				

		else
			logX blue, "server #{server.ipaddress}:#{server.port} disqualified because" if config.loglevel.verbose
			logX(blue, "\tLast Duration (#{server['last-duration']}) > Max Time (#{config['max-time']})") if (server["last-duration"] >= config['max-time']) and config.loglevel.verbose
			logX(blue, "\tLast Used (#{server['last-used'].getTime()}) > Now (#{Date.now()}) - reset time (#{config['reset-time']})") if (server["last-used"].getTime() >= Date.now() - config['reset-time']) and config.loglevel.verbose
			findNext servers

	getServers = ()->
		ProxyServer.find().sort("speed").exec (err, servers)->
			logX red, err if err
			if servers is null or servers.length <= 0
				setTimeout getServers, 1000
			else
				findNext servers

	if currentProxy != null and lastChange != null
		currentProxy["last-used"] = lastChange
		# real metod... may need to substute for always max here... rounding maybe?
		#currentProxy["last-duration"] = Date.now() - lastChange.getTime() + 5000
		currentProxy["last-duration"] = config["max-time"]
		currentProxy.save (err)->
			errorX err if err
			getServers()
	else
		getServers()



httpServer = http.createServer (req,res)->
	req.on 'data', (data)->

	req.on 'end', ()->
		res.writeHead 200, "Content-Type":"text/plain"
		res.write "Proxy server running #{proxyServerStarted}\n"
		res.write "\ton port#{config['proxy-port']}\n" if proxyServerStarted
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
				res.write '\n\t' + 'last-duration  ' + server['last-duration'] 

				if _i is _len
					res.end "****************************************\n          No More Proxy Servers\n****************************************\n"


startServer = ()->
	logX bgGreen + black, "\t\t\t\t\t\tStarting Web Server\t\t\t\t\t\t\t"
	#logX bgGreen + black, "\t\t\t\t\t#{new Date()}\t\t\t\t\t\t"
	logX ltGreen, "Web server running on port #{config['http-port']}"
	httpServer.listen config['http-port']


startProxyServer = ()->
	logX bgGreen + black, "\t\t\t\t\t\tStarting Proxy Server\t\t\t\t\t\t\t"
	#logX bgGreen + black, "\t\t\t\t\t#{new Date()}\t\t\t\t\t\t"
	proxyServerStarted = true
	forwardServer = net.createServer (clientSocket)->
		connected   = false
		changing    = false
		closed      = false
		buffers     = new Array()
		proxySocket = new net.Socket()

		proxySocket.connect currentProxy.port, currentProxy.ipaddress, ()->
			connected = true
			changing  = false
			if buffers.length > 0
				for buffer in buffers
					proxySocket.write buffer

		clientSocket.on 'error', (e)->
			errorX red, "client socket error"
			errorX red, e

		proxySocket.on 'error', (e)->
			if e.code is "ECONNREFUSED"
				logX red + "Connection Refused... trying new server"
				if !changing
					changing = true
					updateProxy()
			###
			else if e.code is "ECONNRESET"
				connected = false
				connResetCounter++
				if connResetCounter >= 10
					connResetCounter = 0
					if !changing
						changing = true
						updateProxy()	
				else
					proxySocket.connect currentProxy.port, currentProxy.ipaddress, ()->
						connected = true
						changing  = false
						if buffers.length > 0
							for buffer in buffers
								proxySocket.write buffer
			###

			errorX red, "proxy socket error"
			errorX red, e

		proxySocket.on 'data', (data)->
			clientSocket.write data

		clientSocket.on 'data', (data)->
			buffers[buffers.length] = data
			if connected and !closed
				proxySocket.write data

		clientSocket.on 'close', (did_error)->
			proxySocket.end()

		proxySocket.on 'close', (did_error)->
			closed = true
			clientSocket.end()
	# End of proxy connection handler


	forwardServer.listen config['proxy-port'], ()->
		logX ltGreen, "Proxy server bound on port " + config['proxy-port']

	setInterval ()->
		hideMyAssGrabber.update updateProxy
	, config['rotateInterval']
# End of function start server