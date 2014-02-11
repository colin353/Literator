class window.LiterateLoader
	constructor: () ->
		@debug 			= yes
		@print_buffer 	= ""

	load: (text) ->
		@clear()
		# Split everything into lines
		lines = text.split /\n/
		block_type = null
		code = markdown = ""
		@segments = []
		console.log lines
		for line in lines
			# Test to see if we are looking at code
			if /^\t/.test line 
				if block_type == 'code'
					code += "\n" + line.replace(/^\t/,'')
				else 
					code = line.replace(/^\t/,'')
					@segments.push new MarkdownSegment(markdown) unless !block_type?
					block_type = 'code'
					markdown = ""
			else 
				if block_type == 'markdown'
					markdown += "\n" + line
				else 
					markdown = line
					@segments.push new CodeSegment(code) unless !block_type?
					block_type = 'markdown'
					code = ""

		# Finally, capture the last block...
		if block_type = 'markdown'
			@segments.push new MarkdownSegment(markdown)
		else 
			@segments.push new CodeSegment(code)

		for s in @segments
			$('.literate').append s.encapsulate()

		@contentUpdated()

	# This can be used to produce console output
	# in the literary mode.
	print: (text) ->
		@print_buffer += text + "\n"

	# This is called by the console segment in order
	# to display buffered output.
	empty_print_buffer: ->
		p = @print_buffer
		@print_buffer = ""
		return p

	run: ->
		try
			for s in @segments
				s.run()
		catch error
			console.log "Execution halted due to errors."

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

class CodeSegment extends DocumentSegment
	constructor: (@code="") ->
		super()
		yes

	load: (code) ->
		@code = code

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

	load: (content) ->
		@content = content

	render: (self) ->
		element = $ "<div class='markdown'>#{@content}</div>"
		element.attr 'data-markdown', @content
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