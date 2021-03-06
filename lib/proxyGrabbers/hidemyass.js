// Generated by CoffeeScript 1.6.2
var Options, ProxyServer, autoUpdateHandle, autoUpdateInterval, colors, db, fs, getServers, http, jquery, jsdom, mongoose, prop, qs, searchOptions, update, updatedTime;

colors = require('../colors');

for (prop in colors) {
  eval(prop + ' = colors[prop]');
}

http = require('http');

qs = require('querystring');

fs = require('fs');

jsdom = require('jsdom');

jquery = fs.readFileSync(__dirname + '/../jquery2.0.1.js').toString();

ProxyServer = null;

db = null;

mongoose = null;

updatedTime = "NEVER";

autoUpdateInterval = 0;

autoUpdateHandle = null;

exports.setup = function(_ProxyServer, _db, _mongoose) {
  ProxyServer = _ProxyServer;
  db = _db;
  return mongoose = _mongoose;
};

exports.lastUpdated = function() {
  return updatedTime;
};

exports.nextUpdate = function() {
  if (autoUpdateHandle === null) {
    return "NEVER";
  }
  if (updatedTime === "NEVER") {
    return "Sometime in the next " + autoUpdateInterval + " ms";
  } else {
    return new Date(updatedTime.getTime() + autoUpdateInterval);
  }
};

exports.setUpdateInterval = function(ms) {
  if ((ms == null) || typeof ms !== "number") {
    return;
  }
  autoUpdateInterval = ms;
  if (autoUpdateHandle !== null) {
    return autoUpdate(true);
  }
};

exports.autoUpdate = function(turnOn) {
  if (turnOn) {
    if (autoUpdateHandle !== null) {
      clearInterval(autoUpdateHandle);
    }
    return autoUpdateHandle = setInterval(function() {
      return update();
    }, autoUpdateInterval);
  } else {
    if (autoUpdateHandle !== null) {
      clearInterval(autoUpdateHandle);
      return autoUpdateHandle = null;
    }
  }
};

getServers = function(body, cb) {
  return jsdom.env({
    html: body,
    src: [jquery],
    done: function(errors, window) {
      var $, $rows, $table, $thead, endTime, startTime;

      updatedTime = new Date();
      $ = window.$;
      logX(yellow, "Scraping data. Hold tight.");
      $('.connection_time,.response_time').each(function(s) {
        return $(this).text($(this).attr('rel'));
      });
      $('head').remove();
      $table = $('table#listtable');
      logX(yellow, 'Removing bad elements...');
      startTime = Date.now();
      $('div,span').filter(function() {
        return $(this).css('display') === 'none';
      }).remove();
      endTime = Date.now();
      logX("", strX(grey, "\tTime to remove ") + strX(ltYellow, (endTime - startTime) / 1000) + strX(grey, " seconds"));
      logX(yellow, 'Removing Style');
      $('style').remove();
      $thead = $table.find('thead');
      $rows = $('table#listtable>tr');
      logX(yellow, 'Parsing rows');
      return $rows.each(function(i) {
        var $dataCells, $row, serverTemplate;

        $row = $(this);
        $dataCells = $row.children('td');
        serverTemplate = ["lastUpdate", "ipaddress", "port", "country", "speed", "connectionTime", "type", "annon"];
        return $dataCells.each(function(j) {
          var $cell, attr;

          $cell = $(this);
          attr = $.trim($cell.text());
          serverTemplate[j] = attr;
          if (j + 1 === $dataCells.length) {
            ProxyServer.findOne({
              ipaddress: serverTemplate[1],
              port: serverTemplate[2]
            }, function(err, server) {
              if (err) {
                return logX(red, err);
              }
              if (server != null) {
                server['Last-Update'] = serverTemplate[0];
                server['ipaddress'] = serverTemplate[1];
                server['port'] = serverTemplate[2];
                server['country'] = serverTemplate[3];
                server['speed'] = serverTemplate[4];
                server['connectionTime'] = serverTemplate[5];
                server['type'] = serverTemplate[6];
                server['annon'] = serverTemplate[7];
                return server.save(function(err) {
                  if (err) {
                    return logX(red, err);
                  }
                  logX(ltGreen, "Updating server " + server['ipaddress']);
                  return server.pingServer();
                });
              } else {
                server = new ProxyServer({
                  'Last-Update': serverTemplate[0],
                  'ipaddress': serverTemplate[1],
                  'port': serverTemplate[2],
                  'country': serverTemplate[3],
                  'speed': serverTemplate[4],
                  'connectionTime': serverTemplate[5],
                  'from': 'hidemyass',
                  'type': serverTemplate[6],
                  'annon': serverTemplate[7]
                });
                return server.save(function(err) {
                  if (err) {
                    return logX(red, err);
                  }
                  logX(bgGreen + black, "Adding server " + server['ipaddress']);
                  return server.pingServer();
                });
              }
            });
            if (i + 1 === $rows.length) {
              window.close();
              if ((cb != null) && typeof cb === "function") {
                return cb();
              }
            }
          }
        });
      });
    }
  });
};

Options = (function() {
  function Options(path, postData) {
    this.path = path;
    this.hostname = "hidemyass.com";
    this.port = 80;
    this.method = "POST";
    this.headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': postData.length,
      'User-Agent': 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:20.0) Gecko/20100101 Firefox/20.0',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Referer': 'http://hidemyass.com/proxy-list/',
      'Connection': 'keep-alive',
      'Cookie': 'PHPSESSID=sq6lgj469plc2kk1mjr5s0i1e2; __utma=82459535.930825937.1369329500.1369329500.1369329500.1; __utmb=82459535.2.10.1369329500; __utmc=82459535; __utmz=82459535.1369329500.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)'
    };
  }

  return Options;

})();

searchOptions = qs.stringify({
  'c[]': ['United States', 'Canada'],
  'p': '',
  'pr[]': ['0', '1'],
  'a[]': ['2', '3', '4'],
  'pl': 'on',
  'sp[]': ['2', '3'],
  'ct[]': ['2', '3'],
  's': '1',
  'o': '0',
  'pp': '3',
  'sortBy': 'response_time'
});

exports.update = update = function(cb) {
  var options, req;

  logX(yellow, "Grabing info from Hide My Ass...");
  options = new Options("/proxy-list/", searchOptions);
  logX(yellow, "\tSending first request");
  req = http.request(options, function(res) {
    var body;

    body = '';
    res.on('data', function(data) {
      return body += data;
    });
    return res.on('end', function() {
      var options2, postData2, req2;

      logX(yellow, "\tFirst response recieved");
      logX(yellow, "\tSending second request");
      postData2 = "q=378";
      options2 = new Options(res.headers['location'], postData2);
      if (res.statusCode !== 200 && res.statusCode !== 302) {
        logX(red, "\tFirst Status code was " + res.statusCode);
        return;
      }
      req2 = http.request(options2, function(res2) {
        var body2;

        body2 = '';
        res2.on('data', function(data) {
          return body2 += data;
        });
        return res2.on('end', function() {
          logX(yellow, "\tSecond response recieved");
          if (res2.statusCode !== 200) {
            logX(red, "\tSecond Status code was " + res2.statusCode);
            return update();
          }
          return getServers(body2, cb);
        });
      });
      req2.on('error', function(e) {
        return logX(red, 'Problem with second request: ' + e.message);
      });
      return req2.end(postData2);
    });
  });
  req.on('error', function(e) {
    return logX(red, 'Problem with first request: ' + e.message);
  });
  return req.end(searchOptions);
};
