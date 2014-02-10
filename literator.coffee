$ ->
	$('.drop_zone').on 'dragover', (e) ->
		e.preventDefault()
		e.stopPropagation()

	$('.drop_zone').on 'drop', (e) ->
		e.preventDefault()
		e.stopPropagation()
		console.log "Dropped!"
		console.log files = e.originalEvent.dataTransfer.files
		for f in files
			console.log "Loading file #{f.name}..."
			reader = new FileReader()
			reader.onload = (file) ->
				console.log file
			console.log reader.readAsText f


	$('.drop_zone').on 'dragenter', (e) ->
		e.preventDefault()
		e.stopPropagation()
		console.log "Entered!"