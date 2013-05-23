http     = require 'http'
proxy    = require 'http-proxy'
nodeTor  = require '../node_modules/node-Tor/lib/node-tor.js'
qs       = require 'querystring'
jsdom    = require 'jsdom'
util     = require 'util'
mongoose = require 'mongoose' 

mongoose.connect 'mongodb://localhost/ipchanger'

ProxyServer = mongoose.model 'ProxyServer', {'Last-Update':String, 'ipaddress':String, 'port':String,'country':String}

getServers = (body, req, res)->
	jsdom.env 
		html: body
		scripts: [
			'http://code.jquery.com/jquery-1.5.min.js'
		]
	, (err, window)->
		$ = window.jQuery

		res.writeHead 200, 
			'Content-Type':'text/plain'
			'Connection':'keep-alive'
			'Transfer-Encoding':'chunked'


		console.log 'Starting to scrape\n'
		console.log 'Removing bad elements...'

		$('div,span', 'table#listtable').filter(()->
			return  if ($(this).css('display') is 'none') or ($(this).html() is "") then true else false
		).remove()

		console.log 'Removing Style'

		$('style').remove()


		$table = $('table#listtable')
		$thead = $table.find 'thead'
		$rows = $('table#listtable>tr')
		
		console.log 'Parsing rows'

		$rows.each (i)->
			res.write "\n" if i > 0
			console.log "Proxy Server " + i + "\n---------------------------"
			res.write "Proxy Server " + i + "\n---------------------------\n"


			$row = $(this)

			$dataCells = $row.children 'td'
		
			$dataCells.each (j)->
				$cell = $(this)

				if /[0-9a-bA-B].+/.test($cell.text())
					console.log $.trim($cell.text())
					res.write $.trim($cell.text())+ "\n"

				if j+1 is $dataCells.length and i+1 is $rows.length
					res.end("********************* FINISHED *********************")

				#res.write util.inspect $cell
				#res.write $cell.html()
				#res.write "\n"


		#res.write "***********************\nHTML\n***********************\n" 
		#res.write $table.html()

		#res.end()

		#res.writeHead 200, 'Content-Type':'text/html'


server = http.createServer (req,res)->

	req.on 'data', (data)->

	req.on 'end', ()->

		#postData = 'c%5B%5D=United+States&p=&pr%5B%5D=0&pr%5B%5D=1&pr%5B%5D=2&a%5B%5D=2&a%5B%5D=3&a%5B%5D=4&pl=on&sp%5B%5D=2&sp%5B%5D=3&ct%5B%5D=2&ct%5B%5D=3&s=1&o=0&pp=3&sortBy=response_time'

		postData = qs.stringify
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


		options = 
			hostname: "hidemyass.com"
			port: 80
			path: "/proxy-list/"
			method: "POST"
			headers:
				'Content-Type' : 'application/x-www-form-urlencoded'
				'Content-Length':postData.length
				'User-Agent':'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:20.0) Gecko/20100101 Firefox/20.0'
				'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
				'Accept-Language':'en-US,en;q=0.5'
				'Referer':'http://hidemyass.com/proxy-list/'
				'Connection':'keep-alive'
				'Cookie':'PHPSESSID=sq6lgj469plc2kk1mjr5s0i1e2; __utma=82459535.930825937.1369329500.1369329500.1369329500.1; __utmb=82459535.2.10.1369329500; __utmc=82459535; __utmz=82459535.1369329500.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)'

		hmareq = http.request options, (hmares)->
			body = ''

			hmares.on 'data', (data)->
				body += data

			hmares.on 'end', ()->
				#res.writeHead 200, 'Content-Type':'text/html'
				#res.writeHead hmares.statusCode, hmares.headers
				#res.end body

				#console.log hmares.headers
				#console.log body

				postData2 = "q=378"

				options2 = 
					hostname: "hidemyass.com"
					port: 80
					path: hmares.headers['location']
					method: "POST"
					headers:
						'Content-Type' : 'application/x-www-form-urlencoded'
						'Content-Length':postData2.length
						'User-Agent':'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:20.0) Gecko/20100101 Firefox/20.0'
						'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
						'Accept-Language':'en-US,en;q=0.5'
						'Referer':'http://hidemyass.com/proxy-list/'
						'Connection':'keep-alive'
						'Cookie':'PHPSESSID=sq6lgj469plc2kk1mjr5s0i1e2; __utma=82459535.930825937.1369329500.1369329500.1369329500.1; __utmb=82459535.2.10.1369329500; __utmc=82459535; __utmz=82459535.1369329500.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)'


				hmareq2 = http.request options2, (hmares2)->
					body2 = ''

					hmares2.on 'data', (data)->
						body2 += data

					hmares2.on 'end', ()->
						getServers body2, req, res

						#console.log "Second response"
						#console.log hmares2.headers
						#console.log body2

				hmareq2.write postData2
				hmareq2.end()

		hmareq.on 'error', (e)->
			console.log 'Problem with request: ' + e.message

		hmareq.write postData
		hmareq.end()

server.listen 8088