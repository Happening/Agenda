Db = require 'db'
Plugin = require 'plugin'
	
exports.onInstall = ->
	# anything to do?

exports.client_new = (values) !->
	event =
		title: values.title
		details: values.details
		date: values.date
		time: values.time
		rsvp: values.rsvp
		created: 0|(new Date()/1000)
		by: Plugin.userId()
		attendance: {}

	maxId = Db.shared.incr('events', 'maxId')
	Db.shared.set('events', maxId, event)

exports.client_remove = (eventId) !->
	return if !Plugin.userIsAdmin() and Plugin.userId() isnt Db.shared.get('events', eventId, 'by')
	Db.shared.remove('events', eventId)

exports.client_edit = (eventId, values) !->
	return if !Plugin.userIsAdmin() and Plugin.userId() isnt Db.shared.get('events', eventId, 'by')
	Db.shared.merge('events', eventId, values)

exports.client_attendance = (eventId, value) !->
	event = Db.shared.ref 'events', eventId
	if value is 0
		event.remove 'attendance', Plugin.userId()
	else if value in [1, 2, 3] # going, notgoing, maybe
		event.set 'attendance', Plugin.userId(), value

