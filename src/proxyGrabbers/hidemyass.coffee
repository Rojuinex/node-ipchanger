# Nifty method for working with console text
colors = require '../colors'

for prop of colors
	# Sometimes this one doesn't work for some reason... eval is
	# discouraged by the js community, but it works every time
	#@[prop] = colors[prop]
	eval prop + ' = colors[prop]'

http    = require 'http'
qs      = require 'querystring'
fs      = require 'fs'
jsdom   = require 'jsdom'
jquery  = fs.readFileSync(__dirname + '/../jquery2.0.1.js').toString()


ProxyServer = null
db          = null
mongoose    = null

updatedTime        = "NEVER"
autoUpdateInterval = 0
autoUpdateHandle   = null

exports.setup = (_ProxyServer, _db, _mongoose)->
	ProxyServer = _ProxyServer
	db          = _db
	mongoose    = _mongoose

exports.lastUpdated = ()->
	return updatedTime

exports.nextUpdate = ()->
	if autoUpdateHandle is null
		return "NEVER"

	if updatedTime is "NEVER"
		return "Sometime in the next " + autoUpdateInterval + " ms" 
	else
		return new Date(updatedTime.getTime() + autoUpdateInterval)

exports.setUpdateInterval = (ms)->
	return if !ms? or typeof ms != "number"

	autoUpdateInterval = ms

	if autoUpdateHandle != null
		autoUpdate true

exports.autoUpdate = (turnOn)->
	if turnOn
		if autoUpdateHandle != null
			clearInterval autoUpdateHandle

		autoUpdateHandle = setInterval ()->
			update()
		, autoUpdateInterval
	else
		if autoUpdateHandle != null
			clearInterval autoUpdateHandle
			autoUpdateHandle = null


getServers = (body, cb)->
	jsdom.env 
		html: body
		src: [jquery]
		done: (errors, window)->
			updatedTime = new Date()
			$ = window.$

			console.log strX yellow, "Scraping data. Hold tight."
			$('.connection_time,.response_time').each (s)->
				$(this).text $(this).attr('rel')

			$('head').remove()
			#$('body').html $('<div>').append($('table#listtable').clone()).html()

			$table = $('table#listtable')


			console.log strX yellow, 'Removing bad elements...'

			startTime = Date.now()
			$('div,span').filter ()->
				return $(this).css('display') == 'none'
			.remove()
			
			endTime = Date.now()
			console.log strX(grey, "\tTime to remove ") + strX( ltYellow , ((endTime  - startTime)/1000) ) + strX(grey, " seconds")

			console.log strX yellow, 'Removing Style'
			$('style').remove()


			$thead = $table.find 'thead'
			$rows = $('table#listtable>tr')
			
			console.log strX yellow, 'Parsing rows'

			$rows.each (i)->
				$row = $(this)

				$dataCells = $row.children 'td'
			
				serverTemplate = [ 
					"lastUpdate",
					"ipaddress",
					"port",
					"country",
					"speed",
					"connectionTime",
					"type",
					"annon"
				]

				$dataCells.each (j)->
					$cell = $(this)

					#if /[0-9a-bA-B].+/.test($cell.text())
					attr = $.trim($cell.text())

					serverTemplate[j] = attr

					if j+1 is $dataCells.length 

						ProxyServer.findOne {
							ipaddress: serverTemplate[1], 
							port: serverTemplate[2]
						}, (err, server)->

							return console.log strX red, err if err

							if server?
								server['Last-Update']    = serverTemplate[0]
								server['ipaddress']      = serverTemplate[1]
								server['port']           = serverTemplate[2]
								server['country']        = serverTemplate[3]
								server['speed']          = serverTemplate[4]
								server['connectionTime'] = serverTemplate[5]
								server['type']           = serverTemplate[6]
								server['annon']          = serverTemplate[7]
								server.save (err)->
									return console.log strX red, err if err
									console.log strX ltGreen, "Updating server #{server['ipaddress']}"
									server.pingServer()
							else
								server = new ProxyServer 
									'Last-Update':serverTemplate[0] 
									'ipaddress':serverTemplate[1] 
									'port':serverTemplate[2]
									'country':serverTemplate[3]
									'speed':serverTemplate[4]
									'connectionTime':serverTemplate[5]
									'from':'hidemyass'
									'type': serverTemplate[6]
									'annon': serverTemplate[7]

								server.save (err)->
									return console.log strX red, err if err
									console.log strX bgGreen + black, "Adding server #{server['ipaddress']}"
									server.pingServer()

						if i+1 is $rows.length
							if cb? and typeof cb is "function"
								cb()
								window.close()

class Options
	constructor: (@path, postData)->
		@hostname = "hidemyass.com"
		@port     = 80
		@method   = "POST"
		@headers =
			'Content-Type' : 'application/x-www-form-urlencoded'
			'Content-Length': postData.length
			'User-Agent':'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:20.0) Gecko/20100101 Firefox/20.0'
			'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
			'Accept-Language':'en-US,en;q=0.5'
			'Referer':'http://hidemyass.com/proxy-list/'
			'Connection':'keep-alive'
			'Cookie':'PHPSESSID=sq6lgj469plc2kk1mjr5s0i1e2; __utma=82459535.930825937.1369329500.1369329500.1369329500.1; __utmb=82459535.2.10.1369329500; __utmc=82459535; __utmz=82459535.1369329500.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)'

searchOptions = qs.stringify
		'c[]': [
			'United States'
			'Canada'
		]

		'p': ''
		
		'pr[]': [
			'0' 
			'1' 
			#'2'
		]
		
		'a[]': [ 
			'2'
			'3'
			'4'
		]
		
		'pl': 'on'
		
		'sp[]': [
			'2'
			'3' 
		]	
		
		'ct[]': [ 
			'2'
			'3'
		]

		's': '1'
		'o': '0'
		'pp': '3'
		'sortBy': 'response_time'
	# End of Post Body Options

exports.update = update = (cb)->
	console.log strX yellow, "Grabing info from Hide My Ass..."
	options = new Options "/proxy-list/", searchOptions

	console.log strX yellow, "\tSending first request"
	req = http.request options, (res)->
		body = ''

		res.on 'data', (data)->
			body += data

		res.on 'end', ()->
			console.log strX yellow, "\tFirst response recieved\n\tSending second request"
			postData2 = "q=378"

			options2 = new Options res.headers['location'], postData2

			if res.statusCode != 200 and res.statusCode != 302
				console.log strX red, "\tFirst Status code was " + res.statusCode
				return

			req2 = http.request options2, (res2)->
				body2 = ''

				res2.on 'data', (data)->
					body2 += data

				res2.on 'end', ()->
					console.log strX yellow, "\tSecond response recieved"
					if res2.statusCode != 200
						console.log strX red, "\tSecond Status code was " + res2.statusCode
						return update()

					getServers body2, cb

			req2.on 'error', (e)->
				console.log strX red, 'Problem with second request: ' + e.message

			req2.end postData2

	req.on 'error', (e)->
		console.log strX red, 'Problem with first request: ' + e.message

	req.end searchOptions