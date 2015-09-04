Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'
Timer = require 'timer'
{tr} = require 'i18n'

dayNames = [
	tr 'Sun'
	tr 'Mon'
	tr 'Tue'
	tr 'Wed'
	tr 'Thu'
	tr 'Fri'
	tr 'Sat'
]

monthNames = [
	tr 'Jan'
	tr 'Feb'
	tr 'Mar'
	tr 'Apr'
	tr 'May'
	tr 'Jun'
	tr 'Jul'
	tr 'Aug'
	tr 'Sep'
	tr 'Oct'
	tr 'Nov'
	tr 'Dec'
]

# convert daycount to 00:00 unix timestamp
dayToUnix = (day) ->
	d = new Date(day*864e5)
	offset = d.getTimezoneOffset() * 60 # seconds
	day * 86400 + offset

dayToString = (day) ->
	d = new Date(day*864e5)
	dayNames[d.getUTCDay()]+' '+d.getUTCDate()+' '+monthNames[d.getUTCMonth()]+' '+d.getUTCFullYear()

timeToString = (time) ->
	if !time?
		tr("None")
	else if time<0
		tr("All day")
	else
		minutes = (time/60)%60
		minutes = '0' + minutes if minutes.toString().length is 1
		(0|(time/3600))+':'+minutes

exports.getTitle = -> # will otherwise be confused with adding an event

exports.onInstall = ->
	# anything to do?

exports.client_new = (values, onCreated) !->
	event =
		title: values.title||"(No title)"
		details: values.details
		date: values.date
		time: values.time
		remind: values.remind
		rsvp: values.rsvp
		created: 0|(new Date()/1000)
		by: Plugin.userId()
		attendance: {}

	maxId = Db.shared.incr('events', 'maxId')
	Db.shared.set('events', maxId, event)

	if values.notify
		whenText = (if values.time>=0 then timeToString(values.time)+' ' else '')
		whenText += dayToString(values.date)
		Event.create
			#unit: 'event'
			text: "#{Plugin.userName()} added an event: #{values.title} (#{whenText})"
			sender: Plugin.userId()

	setRemindTimer maxId
	onCreated.reply maxId
 
setRemindTimer = (eventId) !->
	event = Db.shared.get 'events', eventId
	remind = event?.remind ? 86400
	Timer.cancel 'reminder', eventId

	log 'event, remind, Plugin.time()', JSON.stringify(event), remind, Plugin.time()
	return if !event or remind<0

	# -1 means no reminder
	if remind >= 0
		startTime = dayToUnix(event.date)*1000 - remind*1000
		if remind >= 86400 # a day (or more) in advance
			startTime += (12*3600*1000)
		else if event.time>0
			startTime += event.time*1000

		remindTimeout = startTime - Plugin.time()*1000
		if remindTimeout>0
			log 'setting remindTimeout', remindTimeout
			Timer.set remindTimeout, 'reminder', eventId

exports.reminder = (eventId) !->
	event = Db.shared.get 'events', eventId
	return if !event

	whenText = (if event.time>=0 then timeToString(event.time)+' ' else '')
	whenText += dayToString(event.date)

	log "event reminder #{event.title} (#{whenText})"
	eventObj =
		unit: 'event'
		text: "Event reminder: #{event.title} (#{whenText})"
	include = []
	if event.rsvp
		for userId in Plugin.userIds()
			include.push userId unless event.attendance[userId] is 2
		eventObj.for = include
	Event.create eventObj unless event.rsvp and include.length is 0
	Db.shared.set 'events', eventId, 'reminded', Math.round(Plugin.time())

exports.client_remove = (eventId) !->
	return if !Plugin.userIsAdmin() and Plugin.userId() isnt Db.shared.get('events', eventId, 'by')
	Db.shared.remove('events', eventId)
	Timer.cancel 'reminder', eventId

exports.client_edit = (eventId, values) !->
	return if !Plugin.userIsAdmin() and Plugin.userId() isnt Db.shared.get('events', eventId, 'by')
	oldEvent = Db.shared.get('events', eventId)
	Db.shared.merge('events', eventId, values)

	# possibly re-set the reminder
	if values.remind isnt oldEvent.remind or values.date isnt oldEvent.date or values.time isnt oldEvent.time
		setRemindTimer eventId

exports.client_attendance = (eventId, value) !->
	event = Db.shared.ref 'events', eventId
	if value is 0
		event.remove 'attendance', Plugin.userId()
	else if value in [1, 2, 3] # going, notgoing, maybe
		event.set 'attendance', Plugin.userId(), value

