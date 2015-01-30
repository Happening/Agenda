Dom = require 'dom'
Form = require 'form'
Obs = require 'obs'
Page = require 'page'
Plugin = require 'plugin'
Colors = Plugin.colors()
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

exports.dayToString = (day) ->
	d = new Date(day*864e5)
	dayNames[d.getUTCDay()]+' '+d.getUTCDate()+' '+monthNames[d.getUTCMonth()]+' '+d.getUTCFullYear()

exports.timeToString = (time) ->
	if !time?
		tr("None")
	else if time<0
		tr("All day")
	else
		minutes = (time/60)%60
		minutes = '0' + minutes if minutes.toString().length is 1
		(0|(time/3600))+':'+minutes

exports.dayToDate = dayToDate = (day) ->
	new Date(day*864e5)

exports.dayToColor = (day) ->
	d = new Date(day*864e5)
	if d.getUTCDay() in [0, 6] # weekend
		'#448E80'
	else
		'#2A6A99'

exports.dayToDayString = (day) ->
	d = new Date(day*864e5)
	dayNames[d.getUTCDay()]

exports.dayToMonthString = (day) ->
	d = new Date(day*864e5)
	monthNames[d.getUTCMonth()]

exports.dayToDayNr = (day) ->
	d = new Date(day*864e5)
	d.getUTCDate()


exports.date = date = (opts) ->
	opts = {} if typeof opts!='object'
	if opts.onSave
		return Form.editInModal(opts,date)

	mode = opts.mode # 'range', 'multi', or (default) 'single'

	[handleChange,orgValue] = Form.makeInput opts, (value) ->
		if value?
			value
		else if mode=='multi'
			{}
		else if mode=='range'
			[]

	today = new Date()
	start = today = 0|((today.getTime() - today.getTimezoneOffset()*6e4) / 864e5)
	
	cur = Obs.create orgValue
	if orgValue?
		if mode=='multi'
			start = 0|k for k,v of orgValue
		else if mode=='range'
			start = orgValue[0]
		else
			start = orgValue

	start = new Date(start*864e5)
	year = Obs.create start.getUTCFullYear()
	month = Obs.create 1+start.getUTCMonth()

	renderArrow = (dir,cb) !->
		Dom.div !->
			Dom.style
				width: 0
				height: 0
				borderStyle: "solid"
				borderWidth: "15px #{if dir>0 then 0 else 30}px 15px #{if dir>0 then 30 else 0}px"
				borderColor: "transparent #{if dir>0 then 'transparent' else Colors.highlight} transparent #{if dir>0 then Colors.highlight else Colors.highlight}"
			Dom.onTap !->
				m = month.peek()+dir
				if m<1
					m = 12
					year.set year.peek()-1
				else if m>12
					m = 1
					year.set year.peek()+1
				month.set m

	Dom.div !->
		Dom.style maxWidth: '400px'
		Dom.div !->
			Dom.style Box: "middle center"
			renderArrow -1
			Dom.div !->
				Dom.style textAlign: 'center', fontWeight: 'bold', color: Colors.highlight, padding: '0 15px', minWidth: '25%'
				Dom.text monthNames[month.get()-1]+' '+year.get()
			renderArrow 1
		Dom.css
			"td,th":
				padding: "6px 0"
		Dom.table !->
			Dom.prop
				cellPadding: 0
				cellSpacing: '10px'
			Dom.style textAlign: 'center', width: '100%', tableLayout: 'fixed'
			Dom.tr !->
				for dn in dayNames
					Dom.th dn

			showDay = (day) !->
				Dom.td !->
					return unless day
					Dom.text day
					idate = monthStart+day
					if mode=='multi'
						current = cur.get(idate)
					else if mode=='range'
						current = cur.get('start')<=idate and cur.get('end')>=idate
					else
						current = cur.get()==idate
					Dom.style
						backgroundColor: if current then Colors.highlight else 'inherit'
						color: if current then Colors.highlightText else 'inherit'
					if today==idate
						Dom.style fontWeight: 'bold'
					Dom.onTap !->
						if mode=='multi'
							cur.set(idate, if cur.peek(idate) then null else true)
							handleChange cur.peek()
						else if mode=='range'
							ostart = cur.peek('start')
							oend = cur.peek('end')
							if !ostart? or ostart!=oend
								cur.set {start: idate, end: idate}
							else
								cur.set (if idate<ostart then 'start' else 'end'), idate
							handleChange [cur.peek('start'),cur.peek('end')]
						else
							cur.set idate
							handleChange idate

			monthStart = Date.UTC(year.get(), month.get()-1, 1)
			skipDays = new Date(monthStart).getUTCDay()
			monthStart = 0|(monthStart/864e5) - 1
			lastDate = (new Date(year.get(), month.get(), 0)).getDate()
			curDay = 0
			while curDay<lastDate
				Dom.tr !->
					for i in [0...7]
						if skipDays
							skipDays--
							showDay()
						else if curDay<lastDate
							showDay ++curDay
						else
							showDay()


# The time input is kind of special, as it doesn't have a no-state value. So if the value wasn't set, a change is triggered immediately.
exports.time = time = (opts) ->
	opts = {} if typeof opts!='object'
	if opts.onSave
		return Form.editInModal(opts,time)

	sanitize = opts.normalize = (v) ->
		if v<0
			v + 24*60*60
		else
			v % (24*60*60)

	[handleChange,orgValue] = Form.makeInput opts

	offset = 0
	if opts.gmt and orgValue?
		offset = (new Date).getTimezoneOffset() * 60
		orgValue -= offset

	if orgValue?
		orgValue = 0|(sanitize(orgValue)/60)
		hours = 0|(orgValue/60)
		minutes = orgValue%60
	else
		hours = 15
		minutes = 0
	hours = Obs.create hours
	minutes = Obs.create minutes
	Obs.observe !->
		handleChange sanitize(hours.get()*60*60 + minutes.get()*60 + offset)

	renderArrow = (obsVal, dir, max) !->
		Dom.div !->
			Dom.style
				width: 0
				height: 0
				borderStyle: "solid"
				borderWidth: "#{if dir>0 then 0 else 20}px 20px #{if dir>0 then 20 else 0}px 20px"
				borderColor: "#{if dir>0 then 'transparent' else Colors.highlight} transparent #{if dir>0 then Colors.highlight else Colors.highlight} transparent"
			Dom.onTap !->
				nv = Math.round(((obsVal.peek()+dir) % max)/dir)*dir
				nv=max-1 if nv<0
				obsVal.set nv

	renderInput = (obsVal,max,step) !->
		Dom.div !->
			Dom.style Box: "vertical center"
			renderArrow obsVal, step, max
			Dom.input !->
				inputE = Dom.get()
				val = ''+obsVal.get()
				val = '0'+val if val.length<2
				Dom.prop
					size: 2
					value: val
				Dom.style
					fontFamily: 'monospace'
					fontSize: '30px'
					fontWeight: 'bold'
					textAlign: 'center'
					border: 'inherit'
					backgroundColor: 'inherit'
					color: 'inherit'
				Dom.on 'change', !->
					obsVal.set(inputE.value()%max)
				Dom.on 'click', !-> inputE.select()
			renderArrow obsVal, -step, max
	Dom.div !->
		Dom.style Box: "middle"
		renderInput hours, 24, 1
		Dom.div !->
			Dom.style
				fontFamily: 'monospace'
				fontSize: '30px'
				fontWeight: 'bold'
				padding: '0 4px'
			Dom.text ':'
		renderInput minutes, 60, opts.minuteStep||5
		

exports.datetime
