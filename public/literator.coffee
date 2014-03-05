class window.LiterateLoader
	constructor: () ->
		@debug 			= yes
		@print_buffer 	= []
		@segments 		= []
		@segment_types = [ConstraintSegment, CodeSegment, ConsoleSegment, MarkdownSegment]

	identify_segment: (line) ->
		if line == ""
		 	return "blank"
		# Note that the order here matters: it is possible
		# to have multiple types claim the same line, so the
		# order must specify the preference.
		for s in @segment_types
			if s.identifier.test line 
				return s
		assert false, "No identifier matched the target line: '#{line}'"

	load: (text) ->
		@clear()
		# Carriage returns are silly, delete them
		text = text.replace /[\r]/gm,""
		# Split everything into lines
		lines = text.split /\n/
		block_type = null
		code = markdown = ""
		seg_type = "blank"
		@segments = []

		# Get the first line.
		line = lines.shift()
		# Which type of segment does it correspond to?
		seg_type = @identify_segment line
		# If we draw a blank line, throw it away.
		while seg_type == "blank"
			line = lines.shift()
			seg_type = @identify_segment line
		segment = new seg_type()
		# Add the current line to the segment's list
		segment.lines.push line

		for line in lines
			console.log "Looking at line #{line}..."
			console.log "Identified character zero: #{line.charCodeAt 0}"
			this_seg_type = @identify_segment line 
			console.log "Type: #{this_seg_type}"
			if this_seg_type == "blank" || this_seg_type == seg_type
				segment.lines.push line
			else 
				seg_type = this_seg_type
				segment.finish_loading()
				@segments.push segment
				segment = new this_seg_type()
				segment.lines.push line 

		segment.finish_loading()
		@segments.push segment

	render: ->
		$('.segments').html('')
		for s in @segments
			$('.segments').append s.encapsulate()
		@contentUpdated()

	# This can be used to produce console output
	# in the literary mode.
	print: (text) ->
		@print_buffer.push text

	# This is called by the console segment in order
	# to display buffered output.
	empty_print_buffer: ->
		p = @print_buffer
		@print_buffer = []
		return p

	insertNewSegment: (index, segment_type) ->
		seg = new segment_type()
		#seg.load("This is some new content")
		console.log @segments.join()
		@segments.splice(index, 0, seg)
		console.log @segments.join()
		@render()

	findSegmentIndexBySegment: (segment) ->
		index = null
		for i in [0..@segments.length]
			if @segments[i] == segment
				index = i
		assert index?, "Tried to find nonexistant segment."
		return index

	destroySegment: (segment) ->
		@segments.splice @findSegmentIndexBySegment(segment),1
		@render()

	# Insert a new segment into the document after
	# the segment that is passed into the function.
	insertAfter: (segment) ->
		# Let's find the index of the segment that we are
		# trying to insert after.
		index = null
		me = @
		for i in [0..@segments.length]
			if @segments[i] == segment
				index = i + 1
		assert index?, "Invalid insertAfter called on LiterateLoader"

		buttons = []
		for s in @segment_types
			buttons.push { 
				text: s.readable_name, 
				onclick: ((segment, i, m) ->
						return -> m.insertNewSegment i,segment
					)(s,index,me)
			}

		window.overlaymenu = new OverlayMenu()
		overlaymenu.options = {
			"Choose which items to insert:": buttons,
			"Or, go back:": [
				{ 
					text: 'Cancel', red:yes, 
					onclick: => 
						overlaymenu.close()
				}
			]
		}

		overlaymenu.display()

	run: ->
		# Clear out the constraintsolver memory banks.
		window.constraintsolver = new ConstraintSolver()
		success = yes
		try
			for s in @segments
				s.run()
		catch error
			console.log "Execution halted due to errors: ", error
			success = no

		if success
			# If we got this far, we are pretty well safe. Let's light up
			# the light!
			$('.run-button').addClass('success')
			$('.run-button').removeClass('failure')
			setTimeout ->
				$('.run-button').removeClass('success')
			,2000
		else 
			$('.run-button').addClass('failure')

	export: ->
		code = []
		for s in @segments
			code.push s.export()
		return code.join("")


	# This function gets called when the keypress "ctrl+s" gets pushed.
	save: ->
		# First, distribute the event to all segments that might currently be
		# editing so they can all do their saving.
		for s in @segments
			if s.is_editing
				s.save()
		# And now export the document and save to the server.
		$.post "/raw/#{window.filename}", {data: @export() }


	clear: ->
		$('.segments').html ''

	contentUpdated: ->
		$('.markdown').each ->
			# Check for the data attribute. If you don't include this, there's
			# a good chance that we'll run this multiple times and fuck it up.
			if $(@).attr('data-markdown')?
				$(@).html marked($(@).attr('data-markdown'))
			else 
				console.warn "Note: you have a markdown element that is relying on HTML -> HTML transfer. This is unreliable."
				$(@).html $(@).text()
		$('.code').each ->
			# If we can support it, we'll check for the data attribute
			# which will be simpler and less error-prone to decode.
			if $(@).attr('data-code')?
				$(@).html hljs.highlight( 'coffeescript', $(@).attr('data-code') ).value
			# Otherwise, we'll use the internal contents.
			else
				$(@).html hljs.highlight( 'coffeescript', $(@).html() ).value
				console.warn "Note: you have a code element that is relying on HTML -> HTML transfer. This is unreliable."

		$('.constraints').each ->
			# If we can support it, we'll check for the data attribute
			# which will be simpler and less error-prone to decode.
			if $(@).attr('data-constraints')?
				$(@).html hljs.highlight( 'coffeescript', $(@).attr('data-constraints') ).value
			# Otherwise, we'll use the internal contents.
			else
				$(@).html hljs.highlight( 'coffeescript', $(@).html() ).value
				console.warn "Note: you have a code element that is relying on HTML -> HTML transfer. This is unreliable."

class DocumentSegment
	constructor: (@encapsulation_id = false) ->
		@dom_element = null
		if !@encapsulation_id
			@encapsulation_id = "" + Math.floor( Math.random() * 1000000 )
		@lines = []
		# By default, elements don't permit editing.
		@allow_editing = no
		@is_editing = no

	@readable_name = "DocumentSegment"

	finish_loading: ->
		@load( @lines.join("\n") )

	export: ->
		return ""

	insertAfter: ->
		lit.insertAfter @

	destroy: ->
		o = new OverlayMenu { 
			'Are you sure you want to delete this segment?':  [
				{
					text: "Delete it!",
					onclick: =>
						lit.destroySegment @
				},
				{
					text: "Nevermind.",
					red: yes
				}
			]
		}
		o.show()

	load: ->
		assert false, 'Invalid call of base DocumentSegment load.'

	# When a segment is run, it will do something based upon
	# its content, but the base class has no content.
	run: ->
		yes

	my_element_string: ->
		return "literate_segment_#{@encapsulation_id}"

	my_element: ->
		$("##{@my_element_string()}")

	render: ->
		assert false, "It is illegal to try to render a generic DocumentSegment"

	edit: ->
		assert false, "It is illegal to try to edit the generic DocumentSegment"

	# This function returns a jquery object that represents the 
	# segment. It can be inserted into the document.
	encapsulate: ->
		me = @
		s = "<div class='segment' id='#{@my_element_string()}'></div>"
		@dom_element = $(s)
		@dom_element.append @.render()
		# If editing is permitted, we'll add the editing button
		# which will pop up when the user hovers the segment.
		if @allow_editing
			edit_button = $ '<div class="edit-button">EDIT</div>'
			edit_button.click -> 
				me.edit.call me
			@dom_element.append edit_button

			# Also we should allow editing via double-click:
			@dom_element.dblclick (e) ->
				me.edit.call me
				e.preventDefault()
				return false

		# Allow selecting (highlighting) the current element
		# via single-click
		@dom_element.click ->
			if $(@).is('.selected')
				$(@).removeClass 'selected'
			else 
				$('.segment').removeClass 'selected'
				$(@).addClass 'selected'

		# Insert an "insert" button.
		insert_button = $ '<div class="insert-button">INSERT AFTER...</div>'
		insert_button.click -> 
			 me.insertAfter.call me
		@dom_element.append insert_button

		# Insert a "delete" button, which destroys the object
		delete_button = $ '<div class="delete-button">DELETE<div>'
		delete_button.click -> 
			me.destroy.call me
		@dom_element.append delete_button

		return @dom_element

class window.CodeSegment extends DocumentSegment
	constructor: (@code="") -> 
		super()
		@allow_editing = yes
		yes
	 
	@identifier: /^\t/

	@readable_name = "Code"

	load: (code) ->
		code = $.trim code
		@code = code

	finish_loading: ->
		# List comprehension!
		@lines = ( line.replace(/^\t/,'') for line in @lines )
		@load @lines.join("\n")

	run: ->
		# The thing might still be higlighted red from eariler.
		@my_element().removeClass('error')
		@my_element().find('.error_message').remove()

		js_code = ""
		try  
			js_code = CoffeeScript.compile(@code, {bare: true, nowrap:true})
		catch error
			@my_element().addClass('error')
			error_message = "<b>Error</b> compiling CoffeeScript on element with error: " + error
			error_element = $("<div class='error_message'></div>").html error_message
			@my_element().children('.code').append error_element
			console.log error_message
			throw error_message
		try
			# In order to maintain a consistent scope, we need to do this.
			window.eval.call window, js_code
		catch error
			@my_element().addClass('error')
			error_message = "<b>Error</b> running compiled js on element with error: " + error
			error_element = $("<div class='error_message'></div>").html error_message
			@my_element().children('.code').append error_element
			console.log error_message
			throw error_message

	edit: ->
		me = @
		# Load up the CodeMirror.
		assert codemirror?, "CodeMirror is not loaded, for some reason."

		# Let's do some editing!
		@is_editing = yes

		codemirror.setOption 'mode', 'coffeescript'
		codemirror.setOption 'value', @code
		
		# This line widens the code editor so that it matches the current
		# screen size.
		$(".CodeMirror").width( $('body').width()-30)

		# Now let's register the save button. We'll override anything
		# else registered on that button, also.
		$('.CodeMirror').find('.save-button').unbind('click').click ->
			me.save.call me

		$('.CodeMirror').show()
		$('.codeblanket').show()
		# Clicking on codeblanket cancels the edit.
		$('.codeblanket').click ->
			if confirm "Cancel editing?"
				me.finish_editing.call me

		# This line is necessary to tell the codemirror controller
		# that it has been made visible
		codemirror.scrollIntoView()

	export: ->
		lines = @code.split /\n/
		output = ""
		for l in lines
			output += "\t#{l}\n"
		return output

	save: ->
		@code = codemirror.getValue().replace(/\r/mg,"\n")
		@reload_code()
		@finish_editing()

	reload_code: ->
		@dom_element.removeClass('error')
		@dom_element.children(".code").remove()
		@dom_element.append @render()
		lit.contentUpdated()

	finish_editing: ->
		$('.CodeMirror').hide()
		$('.codeblanket').hide()
		$(".codeblanket").unbind()
		@is_editing = no

	render: (self) ->
		element = $ "<div class='code'></div>"
		element.attr 'data-code', @code
		return element

class MarkdownSegment extends DocumentSegment
	constructor: (@content="") ->
		super()
		@allow_editing = yes
	
	@identifier: //
	@readable_name = "Markdown"

	load: (content) ->
		# Cut off excess trailing newlines, replace with a
		# single newline.
		content = $.trim content
		@content = content

	render: (self) ->
		element = $ "<div class='markdown'>#{@content}</div>"
		element.attr 'data-markdown', @content
		return element

	export: ->
		return @content+"\n"

	edit: ->
		me = @
		@is_editing = yes
		# Load up the CodeMirror.
		assert codemirror?, "CodeMirror is not loaded, for some reason."
		codemirror.setOption 'mode', 'markdown'
		codemirror.setOption 'value', @content
		# This line aligns the editor with the current element.
		
		# This line widens the code editor so that it matches the current
		# screen size.
		$(".CodeMirror").width( $('body').width()-30)

		# Now let's register the save button. We'll override anything
		# else registered on that button, also.
		$('.CodeMirror').find('.save-button').unbind('click').click ->
			me.save.call me

		# Clicking on codeblanket cancels the edit.
		$('.codeblanket').unbind('click').click ->
			if confirm "Cancel editing?"
				me.finish_editing.call me

		$('.CodeMirror').show()
		$('.codeblanket').show()
		codemirror.scrollIntoView()

	save: ->
		console.log "cleaning up markdown"
		@content = codemirror.getValue()
		@reload_markdown()
		@finish_editing()

	reload_markdown: ->
		@dom_element.children(".markdown").remove()
		@dom_element.append @render()
		lit.contentUpdated()

	finish_editing: ->
		@is_editing = no
		$('.CodeMirror').hide()
		$('.codeblanket').hide()
		$(".codeblanket").unbind()

class ConstraintSegment extends CodeSegment
	constructor: ->
		super()
		@allow_editing = yes

	@identifier: /^\t\:/
	@readable_name = "Constraint"

	finish_loading: ->
		# List comprehension!
		@lines = ( line.replace(/^\t/,'') for line in @lines )
		@load @lines.join("\n")

	reload_code: ->
		@dom_element.removeClass('error')
		@dom_element.children(".constraints").remove()
		@dom_element.append @render()
		lit.contentUpdated()

	run: ->
		# The thing might still be higlighted red from eariler.
		@my_element().removeClass('error')
		@my_element().find('.error_message').remove()

		js_code = ""
		try  
			js_code = constraintsolver.execute @code
		catch error
			@my_element().addClass('error')
			error_message = "<b>Error</b> interpreting constraints logic on element with error: " + error
			error_element = $("<div class='error_message'></div>").html error_message
			@my_element().children('.code').append error_element
			console.log error_message
			throw error_message

	load: (code) ->
		content = $.trim code
		@code = content

	render: (self) ->
		element = $ "<div class='constraints'>#{@code}</div>"
		element.attr 'data-constraints', @code
		return element

class ConsoleSegment extends DocumentSegment
	constructor: (@content="") ->	
		super()
	
	@identifier: /##CONSOLE##/
	@readable_name = "Console"

	load: (content) ->
		@content = content

	# When run, we clear everything out, and fill up the console
	# with whatever is in there right now.
	run: ->
		@my_element().children('.console').replaceWith @render()
		yes

	export: ->
		'''
		##CONSOLE##
		'''

	render: (self) ->
		content = " > " + lit.empty_print_buffer().join("\n > ")
		element = $ "<div class='console'>#{content}</div>"
		element.attr 'data-code', content
		return element

# My special overlay menu: Looks like the following
###
<h2>Choose segment to insert.</h2>
<div class="menu-button">Markdown</div>
<div class="menu-button">Console</div>
<div class="menu-button">Constraints</div>
<div class="menu-button">Code</div>
<br style="clear:both" />
<h2>Or, go back.</h2>
<div class="menu-button red">Cancel</div>
###

class window.OverlayMenu
	# You should pass in an options hash like this: {'Option group 1 text': [ { text:'Button1', onclick:callback_function, red:yes } , ... ]}
	constructor: (@options)->
		@dom_element = $ '.insert-menu'

	build: ->
		@dom_element.html ''
		for section,menu of @options
			# Insert the title
			@dom_element.append "<h2>#{section}</h2>"
			for button in menu
				button_element = $ "<div class='menu-button'>#{button.text}</div>"
				if button.red 
					button_element.addClass 'red'
				button_element.click button.onclick
				button_element.click =>
					@close()
				@dom_element.append button_element
			@dom_element.append "<br style='clear:both' />"
	
	# Show is an alias for display.
	show: ->
		@display()	

	display: ->
		# Build everything from the options.
		@build()
		# Display the overlays.
		$('.codeblanket').show()
		$('.insert-menu').show()

		$('.codeblanket').unbind('click').click =>
			@close()

	close: ->
		$('.codeblanket').hide()
		$('.insert-menu').hide()
		# Destroy the contents of the dom_element so it doesn't show up again.
		@dom_element.html ''

# My customized assert method.
window.assert = (condition, error) ->
	throw error if !condition
	yes

$ ->
	# This is the main literator object.
	window.lit = new LiterateLoader()
	window.constraintsolver = new ConstraintSolver()

	# This is necessary to stop the drag and drop from 
	# overriding the whole page, for some reason.
	$('body').on 'dragover', (e) ->
		e.preventDefault()
		e.stopPropagation()

	$('body').on 'drop', (e) ->
		e.preventDefault();e.stopPropagation()
		console.log files = e.originalEvent.dataTransfer.files
		for f in files
			console.log "Loading file #{f.name}..."
			reader = new FileReader()
			reader.onload = ->
				console.log reader.result
				# Load up the literator.
				lit.load reader.result
				lit.render()
				lit.run()
				# Hide the welcome banner.
				$('.welcome').hide()
			reader.readAsText f

	hljs.initHighlightingOnLoad();

	$('.markdown').each ->
		$(@).html marked($(@).html())

	$('.run-button').click ->
		lit.run()

	window.codemirror = CodeMirror document.body, {
		value: "this is a test",
		mode: "coffeescript",
		theme: "ambiance",
		lineNumbers: yes		
	}

	$(".CodeMirror").append("<div class='save-button'>SAVE</div>")

	$(window).keydown (e) ->
		if !( (e.which == 115 || e.which == 83 ) && e.ctrlKey) && !(e.which == 19)
			return true;
		lit.save()
		e.preventDefault()
		return false

	$('.download-button').click ->
		code = lit.export()
		pom = document.createElement('a')
		pom.setAttribute('href', 'data:text/plain;charset=utf-8;base64,' + btoa(code));
		pom.setAttribute('download', "#{window.filename}.litcoffee")
		pom.click()

	# Load up math.js
	window.math = mathjs()

	# Now, let's load the file from the current URL.
	window.filename = window.location.pathname.substring(1)
	$.get "/raw/#{window.filename}", (r) ->
		lit.load r
		lit.render()
		lit.run()