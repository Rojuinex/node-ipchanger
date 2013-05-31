###  Colors Include
      Author: Caleb Bartholomew <caleb@freqntr.com>
     Version: 0.0.1
Date Created: December 30th, 2012
  Decription: Tools for working in the console
###

# Codes for working with text in the console.
addTimeStamp      = true
strcode           = "\u001b["
exports.reset     = "#{strcode}0m"
exports.bold      = "#{strcode}1m"
exports.grey      = "#{strcode}2m"
exports.underline = "#{strcode}4m"
exports.flash     = "#{strcode}5m"
exports.invert    = "#{strcode}7m"
exports.invisible = "#{strcode}8m"

exports.black     = "#{strcode}30m"
exports.red       = "#{strcode}31m"
exports.green     = "#{strcode}32m"
exports.yellow    = "#{strcode}33m"
exports.blue      = "#{strcode}34m"
exports.magenta   = "#{strcode}35m"
exports.cyan      = "#{strcode}36m"
exports.white     = "#{strcode}37m"

exports.bgClear   = "#{strcode}40m"
exports.bgRed     = "#{strcode}41m"
exports.bgGreen   = "#{strcode}42m"
exports.bgYellow  = "#{strcode}43m"
exports.bgBlue    = "#{strcode}44m"
exports.bgMagenta = "#{strcode}45m"
exports.bgCyan    = "#{strcode}46m"
exports.bgWhite   = "#{strcode}47m"

exports.ltGrey    = "#{strcode}90m"
exports.ltRed     = "#{strcode}91m"
exports.ltGreen   = "#{strcode}92m"
exports.ltYellow  = "#{strcode}93m"
exports.ltBlue    = "#{strcode}94m"
exports.ltMagenta = "#{strcode}95m"
exports.ltCyan    = "#{strcode}96m"
exports.ltWhite   = "#{strcode}97m"
exports.none      = ""

timeStamp = (string)->
	parseString = string.replace "\r\n", "\n"
	parseString = parseString.replace "\n\r", "\n"
	parseString = parseString.replace "\r", "\n"
	parseString = parseString.replace /\n/, "\n                                       \t\t"
	timeString = "#{new Date()}\t\t" + parseString

exports.strX    = (format, string)->
	return format + string + reset

exports.logX    = (format, string)->
	logString = strX(format, string)
	if addTimeStamp
		logString = timeStamp logString

	console.log logString

exports.errorX = (format, string)->
	console.log 

	logString = strX(format, string)
	if addTimeStamp
		logString = timeStamp logString

	console.error logString
