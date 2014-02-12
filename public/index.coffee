$ ->
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
				$.post '/new', { data: reader.result }, (r) ->
					window.location.href = "/#{r}"
				
			reader.readAsText f