Datepicker = require 'datepicker'
Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Time = require 'time'
Form = require 'form'
Obs = require 'obs'
Plugin = require 'plugin'
Colors = Plugin.colors()
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
{tr} = require 'i18n'

attendanceTypes =
	1: tr "Going"
	2: tr "Not going"
	3: tr "Maybe"

exports.render = !->
	eventId = Page.state.get(0)
	log 'eventId', eventId
	if eventId
		renderEvent eventId
	else
		renderOverview()

renderEvent = (eventId) !->
	if eventId is 'new'
		Page.setTitle tr("New event")
		Form.setPageSubmit (values) !->
			Server.sync 'new', values, !->
				# predict some stuff
			Page.back()

	else
		event = Db.shared.ref('events', eventId)

		# maybe only allow admin/owner to edit, in other mode?
		Page.setTitle tr("Event details")
		Page.setActions
			label: tr("Remove")
			icon: 'trash'
			action: !->
				Modal.confirm null, tr("Remove event?"), !->
					Server.sync 'remove', eventId, !->
						Db.shared.remove(eventId)
					Page.back()

		Form.setPageSubmit (values) !->
			Server.sync 'edit', eventId, values, !->
				# predict some stuff
			Page.back()

	# (added by, when?), title, details, time (and date?), ask if people are going, show who's (not/maybe) going, reminder, comments
	Dom.div !->
		Dom.style margin: '-8px -8px 0', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

		Form.box !->
			Dom.style padding: '8px'
			Form.input
				name: 'title'
				text: tr "Title"
				value: (if event then event.func('title') else null)
				title: tr("Title")

			if event
				Dom.div !->
					Dom.style
						fontSize: '70%'
						color: '#aaa'
					Dom.text tr("Added by %1", Plugin.userName(event.get('by')))
					Dom.text " • "
					Time.deltaText event.get('created')

		Form.sep()

		# select date
		today = 0|(((new Date()).getTime() - (new Date()).getTimezoneOffset()*6e4) / 864e5)
		curDate = event?.get('date')||today
		Form.box !->
			Dom.text tr("Event date")
			[handleChange] = Form.makeInput
				name: 'date'
				value: curDate
				content: (value) !->
					Dom.div Datepicker.dayToString(value)

			Dom.onTap !->
				Modal.show tr("Select date"), !->
					Datepicker.date
						value: curDate
						onChange: (v) !->
							if v
								handleChange v
								curDate = v

		Form.sep()

		time = 0|(new Date()).getHours()*3600
		curTime = (if event then event.get('time') else -1)
		log 'curTime', curTime
		Form.box !->
			Dom.text tr("Event time")

			[handleChange] = Form.makeInput
				name: 'time'
				value: curTime
				content: (value) !->
					Dom.div Datepicker.timeToString(value)

			Dom.onTap !->
				Modal.show tr("Enter time"), !->
					Datepicker.time
						value: (if curTime<0 then null else curTime)
						onChange: (v) !->
							if v
								handleChange v
								curTime = v
				, (choice) !->
					if choice is 'clear'
						handleChange -1
						curTime = -1
				, ['clear', tr("All day"), 'ok', tr("Set")]

		Form.sep()

		Form.label !->
			Dom.style marginTop: '16px'
			Dom.text tr("Details")

		Form.box !->
			Dom.style padding: '8px'
			Form.text
				name: 'details'
				text: tr "Details about the event"
				autogrow: true
				value: (if event then event.func('details'))
				inScope: !->
					Dom.style fontSize: '140%'
					Dom.prop 'rows', 1

		Form.sep()

		Obs.observe !->
			ask = Obs.create (if event then event.get('rsvp') else true)
			Form.check
				name: 'rsvp'
				value: (if event then event.func('rsvp') else true)
				text: tr("Ask members if they're going")
				onChange: (v) !->
					ask.set(v)

			# attendance info..
			if eventId isnt 'new' and ask.get()
				Form.sep()

				Form.label !->
					Dom.style marginTop: '16px'
					Dom.text tr("Attendance")
				Dom.div !->
					Dom.style fontSize: '80%'
					attendance =
						1: []
						2: []
						3: []
					event.forEach 'attendance', (user) !->
						attendance[user.get()].push user.key()

					log 'attendance', attendance
					for type in [1, 2, 3]
						if cnt = attendance[type].length
							Dom.div !->
								Dom.style fontWeight: 'bold', margin: '8px'
								Dom.span attendanceTypes[type] + ' (' + cnt + '): '
								for uid, k in attendance[type] then do (uid) !->
									if k
										Dom.span !->
											Dom.style color: '#999'
											Dom.text ', '
									Dom.span !->
										Dom.style whiteSpace: 'nowrap', color: '#999', padding: '2px 4px', margin: '-2px -4px'
										Dom.text Plugin.userName(uid)
										Dom.onTap (!-> Plugin.userInfo(uid))


	if eventId isnt 'new'
		require('social').renderComments eventId

renderOverview = !->
	log 'renderOverview'
	Page.setFooter
		label: tr "+ Add event"
		action: !-> Page.nav 'new'

	events = Db.shared.ref 'events'

	events.observeEach (event) !->
		Dom.div !->
			Dom.style Box: 'top'
			att = event.ref 'attendance', Plugin.userId()

			Dom.div !->
				Dom.style
					margin: '0 10px 0 0'
					fontSize: '80%'
					lineHeight: '130%'
					width: '30px'
					textAlign: 'center'
					textShadow: '0 1px 0 #fff'
					color: (if att.get() in [1, 3] then '#555' else '#999')

				date = new Date(event.get('time')*1000)
				Dom.text Datepicker.dayToDayString(event.get('date')).toUpperCase()
				Dom.br()
				Dom.span !->
					Dom.style fontWeight: 'bold', fontSize: '170%'
					Dom.text Datepicker.dayToDayNr(event.get('date'))
				Dom.br()
				Dom.text Datepicker.dayToMonthString(event.get('date')).toUpperCase()
			Dom.section !->
				Dom.style Flex: 1
				Dom.div !->
					Dom.style Box: 'middle', padding: '8px', margin: '-8px', borderRadius: '2px 2px 0 0', minHeight: '36px'

					Dom.div !->
						Dom.style Flex: 1
						Dom.div !->
							Dom.style Box: 'middle'
							Dom.div !->
								Dom.style
									Flex: 1
									whiteSpace: 'nowrap'
									overflow: 'hidden'
									textOverflow: 'ellipsis'
									fontSize: '120%'
									fontWeight: 'bold'
									color: (if att.get() in [1, 3] then '#555' else '#999')
								Dom.text event.get('title')

							if unread = require('social').newComments(event.key())
								Dom.div !->
									Ui.unread unread

						if (time = event.get('time'))? and time>=0
							Dom.div !->
								Dom.style fontSize: '75%', fontWeight: 'bold', color: (if att.get() in [1, 3] then '#555' else '#999')
								Dom.text Datepicker.timeToString(time)

						if details = event.get('details')
							Dom.div !->
								Dom.style
									fontSize: '85%'
									color: '#aaa'
									margin: '4px 0'
									overflow: 'hidden'
									whiteSpace: 'nowrap'
									textOverflow: 'ellipsis'
								Dom.text details

					Dom.onTap !-> Page.nav event.key()

				if event.get('rsvp')
					Dom.div !->
						Dom.style
							Box: true
							paddingTop: '3px'
							borderTop: '1px solid #eee'
							marginTop: '8px'
							marginBottom: '-3px'
							color: Colors.highlight
							fontSize: '75%'
							textAlign: 'center'

						attendanceCnt = Obs.create()
						Obs.observe !->
							for type in [1, 2, 3] then do (type) !->
								event.observeEach 'attendance', (user) !->
									attendanceCnt.incr type, 1
									Obs.onClean !->
										attendanceCnt.incr type, -1
								, (user) ->
									if user.get() is type
										user.key()

						for type, label of attendanceTypes then do (type, label) !->
							type = +type
							Dom.div !->
								userAtt = event.get('attendance', Plugin.userId())
								chosen = userAtt is type
								Dom.style
									Flex: 1
									whiteSpace: 'nowrap'
									padding: '6px 8px'
									borderRadius: '2px'
									fontWeight: (if chosen then 'bold' else 'normal')
									opacity: (if userAtt? and !chosen then '0.5' else '1')
								Dom.text label
								Dom.span !->
									Dom.style color: '#aaa'
									log 'nr for', type, attendanceCnt.get(type)
									if nr = attendanceCnt.get(type)
										Dom.text ' ('+nr+')'
								Dom.onTap !->
									Server.sync 'attendance', event.key(), (if chosen then 0 else type), !->
										event.set 'attendance', Plugin.userId(), (if chosen then null else type)
	, (event) ->
		if +event.key()
			[event.get('date'), event.get('time')]
