class window.LiterateLoader
	constructor: () ->
		@debug 			= yes
		@print_buffer 	= []

	identify_segment: (line) ->
		# Note that the order here matters: it is possible
		# to have multiple types claim the same line, so the
		# order must specify the preference.
		segment_types = [CodeSegment, ConsoleSegment, MarkdownSegment]
		for s in segment_types
			if s.identifier.test line 
				return s
		assert false, "No identifier matched the target..."

	load: (text) ->
		@clear()
		# Split everything into lines
		lines = text.split /\n/
		block_type = null
		code = markdown = ""
		@segments = []

		# Get the first line.
		line = lines.shift()
		# Which type of segment does it correspond to?
		seg_type = @identify_segment line
		segment = new seg_type()
		# Add the current line to the segment's list
		segment.lines.push line

		for line in lines
			this_seg_type = @identify_segment line 
			if this_seg_type == seg_type
				segment.lines.push line
			else 
				seg_type = this_seg_type
				segment.finish_loading()
				@segments.push segment
				segment = new this_seg_type()
				segment.lines.push line 

		segment.finish_loading()
		@segments.push segment

		for s in @segments
			$('.literate').append s.encapsulate()

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

	run: ->
		try
			for s in @segments
				s.run()
		catch error
			console.log "Execution halted due to errors: ", error

	clear: ->
		$('.literate').html ''

	contentUpdated: ->
		$('.markdown').each ->
			$(@).html marked($(@).text())
		$('.code').each ->
			# If we can support it, we'll check for the data attribute
			# which will be simpler and less error-prone to decode.
			if $(@).attr('data-code')?
				$(@).html hljs.highlight( 'coffeescript', $(@).attr('data-code') ).value
			# Otherwise, we'll use the internal contents.
			else
				$(@).html hljs.highlight( 'coffeescript', $(@).html() ).value

class DocumentSegment
	constructor: (@encapsulation_id = false) ->
		@dom_element = null
		if !@encapsulation_id
			@encapsulation_id = "" + Math.floor( Math.random() * 1000000 )
		@lines = []

	finish_loading: ->
		@load( @lines.join("\n") )

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

	# This function returns a jquery object that represents the 
	# segment. It can be inserted into the document.
	encapsulate: ->
		s = "<div class='segment' id='#{@my_element_string()}'></div>"
		@dom_element = $(s)
		@dom_element.append @.render()
		return @dom_element

class window.CodeSegment extends DocumentSegment
	constructor: (@code="") ->
		super()
		yes
	
	@identifier: /^\t/

	load: (code) ->
		@code = code

	finish_loading: ->
		# List comprehension!
		@lines = ( line.replace(/^\t/,'') for line in @lines )
		@load @lines.join("\n")

	run: ->
		# The thing might still be higlighted red from eariler.
		@my_element().removeClass('error')

		js_code = ""
		try  
			js_code = CoffeeScript.compile @code
		catch error
			@my_element().addClass('error')
			console.log "Error compiling CoffeeScript on element with error: ", error
			throw "Error found in compiling coffeescript, finishing."
		try
			eval js_code
		catch error
			@my_element().addClass('error')
			console.log "Error compiling CoffeeScript on element with error: ", error
			throw "Error found in running compiled JS, finishing."

	render: (self) ->
		element = $ "<div class='code'></div>"
		element.attr 'data-code', @code
		return element

class MarkdownSegment extends DocumentSegment
	constructor: (@content="") ->
		super()
	
	@identifier: /^[^\t]/

	load: (content) ->
		@content = content

	render: (self) ->
		element = $ "<div class='markdown'>#{@content}</div>"
		element.attr 'data-markdown', @content
		return element

class ConsoleSegment extends DocumentSegment
	constructor: (@content="") ->
		super()
	
	@identifier: /##CONSOLE##/

	load: (content) ->
		@content = content

	# When run, we clear everything out, and fill up the console
	# with whatever is in there right now.
	run: ->
		@my_element().html('').append @render()
		yes

	render: (self) ->
		content = " > " + lit.empty_print_buffer().join("\n > ")
		element = $ "<div class='console'>#{content}</div>"
		element.attr 'data-code', content
		return element

# My customized assert method.
window.assert = (condition, error) ->
	throw error if !condition
	yes

$ ->

	window.lit = new LiterateLoader()

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
				window.lit.load reader.result
				$('.welcome').hide()
			reader.readAsText f

	hljs.initHighlightingOnLoad();

	$('.markdown').each ->
		$(@).html marked($(@).html())

	$('.run-button').click ->
		lit.run()