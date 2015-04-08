Datepicker = require 'datepicker'
Loglist = require 'loglist'
Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Social = require 'social'
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

today = 0|(((new Date()).getTime() - (new Date()).getTimezoneOffset()*6e4) / 864e5)
attendanceTypes =
	1: tr "Going"
	2: tr "Not going"
	3: tr "Maybe"

exports.render = !->
	eventId = Page.state.get(0)
	log 'eventId', eventId
	if eventId is 'new'
		renderEditEvent 'new'
	else if +eventId and Page.state.get(1) is 'edit'
		renderEditEvent +eventId
	else if +eventId
		renderEventDetails +eventId
	else
		renderOverview (eventId is 'past')

renderEventDetails = (eventId) !->
	log 'eventId >>', eventId
	Page.setTitle tr("Event info")
	event = Db.shared.ref('events', eventId)
	Event.showStar event.get('title')

	if Plugin.userIsAdmin() or Plugin.userId() is event?.get('by')
		Page.setActions [
			label: tr("Remove")
			icon: 'trash'
			action: !->
				Modal.confirm null, tr("Remove event?"), !->
					Server.sync 'remove', eventId, !->
						Db.shared.remove('events', eventId)
					Page.back()
			,
				label: tr("Edit")
				icon: 'edit'
				action: !-> Page.nav [eventId, 'edit']
			]

	Dom.div !->
		Dom.style margin: '-8px -8px 0', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

		Dom.div !->
			Dom.style
				padding: '14px 14px 8px 14px'
				backgroundColor: Datepicker.dayToColor(event.get('date'))
				color: '#fff'

			Dom.div !->
				Dom.style fontSize: '160%', fontWeight: 'bold'
				Dom.userText event.get('title')

			Dom.div !->
				Dom.text Datepicker.timeToString(event.get('time'))
				Dom.span !->
					Dom.style padding: '0 4px'
					Dom.text ' • '
				Dom.text Datepicker.dayToString(event.get('date'))

			Dom.div !->
				Dom.style
					fontSize: '70%'
					color: '#ddd'
					marginTop: '14px'
				Dom.text tr("Added by %1", Plugin.userName(event.get('by')))
				Dom.text " • "
				Time.deltaText event.get('created')

		# details
		if details = event.get('details')
			Dom.div !->
				Dom.style padding: '6px'
				Form.label !->
					Dom.style marginTop: '12px'
					Dom.text tr("Details")
				Dom.div !->
					Dom.style padding: '8px'
					Dom.userText details

		# attendance info..
		if event.get('rsvp')
			Dom.div !->
				Dom.style padding: '6px'
				Form.label !->
					Dom.style marginTop: '12px'
					Dom.text tr("Attendance")
				Dom.div !->
					Dom.style fontSize: '80%', margin: '12px 0'
					attendance =
						1: []
						2: []
						3: []
					event.forEach 'attendance', (user) !->
						attendance[user.get()].push user.key()

					userAtt = event.get('attendance', Plugin.userId())
					for type in [1, 2, 3] then do (type) !->
						chosen = userAtt is type
						Dom.div !->
							Dom.style Box: 'top', fontWeight: 'bold', margin: '12px 8px'
							Dom.div !->
								Dom.style
									width: '70px'
									textAlign: 'right'
								Dom.span !->
									Dom.style
										color: Colors.highlight
										padding: '6px 8px'
										margin: '-6px -4px -6px -8px'
										borderRadius: '2px'
										fontWeight: (if chosen then 'bold' else 'normal')
										opacity: (if userAtt? and !chosen then '0.5' else '1')
									Dom.text attendanceTypes[type]
									Dom.onTap !->
										Event.subscribe [event.key()] if !chosen and type in [1, 3]
										Server.sync 'attendance', event.key(), (if chosen then 0 else type), !->
											event.set 'attendance', Plugin.userId(), (if chosen then null else type)

							Dom.div !->
								Dom.style padding: '0 6px', color: '#999'
								Dom.text '(' + attendance[type].length + ')'

							Dom.div !->
								Dom.style Flex: 1

								for uid, k in attendance[type] then do (uid) !->
									if k
										Dom.span !->
											Dom.style color: '#999'
											Dom.text ', '
									Dom.span !->
										Dom.style
											whiteSpace: 'nowrap'
											color: (if Plugin.userId() is +uid then 'inherit' else '#999')
											padding: '2px 4px'
											margin: '-2px -4px'
										Dom.text Plugin.userName(uid)
										Dom.onTap (!-> Plugin.userInfo(uid))

	Dom.div !->
		Dom.style margin: '0 -8px'
		Social.renderComments eventId

renderEditEvent = (eventId) !->
	if eventId is 'new'
		Page.setTitle tr("New event")
		Form.setPageSubmit (values) !->
			values.title = Form.smileyToEmoji values.title
			values.details = Form.smileyToEmoji values.details
			Server.sync 'new', values, !->
				maxId = Db.shared.incr('events', 'maxId')
				Db.shared.set 'events', maxId,
					title: values.title||"(No title)"
					details: values.details
					date: values.date
					time: values.time
					rsvp: values.rsvp
					created: 0|(new Date()/1000)
					by: Plugin.userId()
					attendance: {}
			Page.back()

	else
		# check edit authorisation
		return if !Plugin.userIsAdmin() and Plugin.userId() isnt Db.shared.get('events', eventId, 'by')

		event = Db.shared.ref('events', eventId)

		# maybe only allow admin/owner to edit, in other mode?
		Page.setTitle tr("Edit event")

		Form.setPageSubmit (values) !->
			values.title = Form.smileyToEmoji values.title
			values.details = Form.smileyToEmoji values.details
			Server.sync 'edit', eventId, values, !->
				Db.shared.merge 'events', eventId, values
			Page.back()

	Dom.div !->
		Dom.style margin: '-8px -8px 0', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

		Form.box !->
			Dom.style padding: '8px'
			Form.input
				name: 'title'
				text: tr "Title"
				value: (if event then event.func('title') else null)
				title: tr("Title")

		Form.sep()

		# select date
		curDate = event?.get('date')||today
		Form.box !->
			Dom.text tr("Event date")
			[handleChange] = Form.makeInput
				name: 'date'
				value: curDate
				content: (value) !->
					Dom.div Datepicker.dayToString(value)

			Dom.onTap !->
				val = curDate
				Modal.confirm tr("Select date"), !->
					Datepicker.date
						value: val
						onChange: (v) !->
							val = v
				, !->
					handleChange val
					curDate = val

		Form.sep()

		time = 0|(new Date()).getHours()*3600
		curTime = (if event then event.get('time') else -1)
		Form.box !->
			Dom.text tr("Event time")
			[handleChange] = Form.makeInput
				name: 'time'
				value: curTime
				content: (value) !->
					Dom.div Datepicker.timeToString(value)

			Dom.onTap !->
				val = (if curTime<0 then null else curTime)
				Modal.show tr("Enter time"), !->
					Datepicker.time
						value: val
						onChange: (v) !->
							val = v
				, (choice) !->
					return if choice is 'cancel'
					newVal = (if choice is 'clear' then -1 else val)
					handleChange newVal
					curTime = newVal
				, ['cancel', tr("Cancel"), 'clear', tr("All day"), 'ok', tr("Set")]

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

		Form.box !->
			remind = (if event then event.get('remind') else 86400)

			getRemindText = (r) ->
				if r is -1
					tr("No reminder")
				else if r is 0
					tr("At time of event")
				else if r is 600
					tr("10 minutes before")
				else if r is 3600
					tr("1 hour before")
				else if r is 86400
					tr("1 day before", r)
				else if r is 604800
					tr("1 week before", r)

			Dom.text tr("Remind members")
			[handleChange] = Form.makeInput
				name: 'remind'
				value: remind
				content: (value) !->
					Dom.div !->
						Dom.text getRemindText(value)

			Dom.onTap !->
				Modal.show tr("Remind members"), !->
					Dom.style width: '60%'
					opts = [0, 600, 3600, 86400, 604800, -1]
					Dom.div !->
						Dom.style
							maxHeight: '45.5%'
							backgroundColor: '#eee'
							margin: '-12px'
						Dom.overflow()
						for rem in opts then do (rem) !->
							Ui.item !->
								Dom.text getRemindText(rem)
								if remind is rem
									Dom.style fontWeight: 'bold'

									Dom.div !->
										Dom.style
											Flex: 1
											padding: '0 10px'
											textAlign: 'right'
											fontSize: '150%'
											color: Plugin.colors().highlight
										Dom.text "✓"
								Dom.onTap !->
									handleChange rem
									remind = rem
									Modal.remove()

		Form.sep()

		Obs.observe !->
			ask = Obs.create (if event then event.get('rsvp') else true)
			Form.check
				name: 'rsvp'
				value: (if event then event.func('rsvp') else true)
				text: tr("Ask members if they're going")
				onChange: (v) !->
					ask.set(v)

		if eventId is 'new'
			Form.sep()
			Form.check
				name: 'notify'
				value: true
				text: tr("Notify about this event now")

mapIncr = (o, key, delta) !->
	o.modify key, (v) -> v + delta
	Obs.onClean !->
		o.modify key, (v) -> v - delta

renderOverview = (showPast) !->
	log 'renderOverview'
	events = Db.shared.ref 'events'

	if showPast
		Page.setTitle tr("Past events")
	else
		Dom.section !->
			Dom.style margin: '0 10px 14px 40px', backgroundColor: '#f6f6f6', color: Colors.highlight
			Dom.div !->
				Dom.style padding: '8px', margin: '-8px', borderRadius: '2px', textAlign: 'center', fontSize: '75%'
				Dom.div !->
					Dom.style Box: 'middle', minHeight: '20px'

					Dom.div !->
						Dom.style Flex: 1
						Dom.text tr("Show past events")

					pastUnread = Obs.create([0,0,0])

					events.observeEach (event) !->
						u = Event.getUnread([event.key()], true)
						pastUnread.modify (v) -> [ v[0]+u[0], v[1]+u[1], v[2]+u[2] ]
						Obs.onClean !->
							pastUnread.modify (v) -> [ v[0]-u[0], v[1]-u[1], v[2]-u[2] ]
					, (event) ->
						if +event.key() and event.get('date')<today
							[event.get('date'), event.get('time')]

					Obs.observe !->
						log 'renderBubble', pastUnread.get()
						Event.renderBubble false, data: pastUnread.get()

				Dom.onTap !-> Page.nav 'past'

		Page.setFooter
			label: tr "+ Add event"
			action: !-> Page.nav 'new'

	renderDate = (date, color) !->
		Dom.div !->
			Dom.style
				margin: '0 10px 0 0'
				fontSize: '80%'
				lineHeight: '130%'
				width: '30px'
				textAlign: 'center'
				textShadow: '0 1px 0 #fff'
				color: color ? Datepicker.dayToColor(date)

			Dom.text Datepicker.dayToDayString(date).toUpperCase()
			Dom.br()
			Dom.span !->
				Dom.style fontWeight: 'bold', fontSize: '170%'
				Dom.text Datepicker.dayToDayNr(date)
			Dom.br()
			Dom.text Datepicker.dayToMonthString(date).toUpperCase()


	isEmpty = Obs.create(true)
	eventCnt = 0
	Obs.observe !->
		if isEmpty.get()
			Dom.div !->
				Dom.style Box: 'top'
				renderDate today, '#888'
				Ui.emptyText (if showPast then tr("No past events") else tr("No upcoming events"))

	events.observeEach (event) !->
		Dom.div !->
			isEmpty.set !++eventCnt
			Obs.onClean !->
				isEmpty.set !++eventCnt

			Dom.style Box: 'top'
			att = event.ref 'attendance', Plugin.userId()

			renderDate event.get('date')
			Dom.section !->
				Dom.style Flex: 1, margin: '0 10px 14px 0'
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
									fontWeight: (if att.get() in [1, 3] then 'bold' else 'normal')
									color: (if Event.isNew(event.get('created')) then '#5b0' else (if att.get() in [1, 3] then Datepicker.dayToColor(event.get('date')) else '#777'))
								Dom.userText event.get('title')

							Event.renderBubble [event.key()]

						if (time = event.get('time'))? and time>=0
							Dom.div !->
								Dom.style
									fontSize: '75%'
									fontWeight: (if att.get() in [1, 3] then 'bold' else 'normal')
									color: (if att.get() in [1, 3] then Datepicker.dayToColor(event.get('date')) else '#777')
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
								Dom.userText details, {br: false}

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
									if nr = attendanceCnt.get(type)
										Dom.text ' ('+nr+')'
								Dom.onTap !->
									Event.subscribe [event.key()] if !chosen and type in [1, 3]
									Server.sync 'attendance', event.key(), (if chosen then 0 else type), !->
										event.set 'attendance', Plugin.userId(), (if chosen then null else type)

		log 'observeEach', event.key()
	, (event) ->
		if +event.key() and (if showPast then event.get('date')<today else event.get('date')>=today)
			[event.get('date'), event.get('time')]
