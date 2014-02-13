express = require('express')
fs 		= require('fs')
app = express()

port 	= process.env.PORT || 8080

app.configure ->
	app.set "view options", { layout: false, pretty: true }
	app.use express.favicon()
	app.use(express.static(__dirname + '/public'))
	app.use express.bodyParser()

app.get '/', (req, res) ->
	res.sendfile "index.html", {root: './public'}

app.get '/raw/:file', (req, res) ->
	# Here, we're trying to load up a file. So let's try and load it.
	console.log "Received request for: ", req.params.file
	# Let's try and load the actual file.
	res.sendfile req.params.file, {root: './literals'}

app.get '/:file', (req, res) ->
	res.sendfile 'literator.html', {root: './public'}

# And now, writing a file
app.post '/raw/:file', (req, res) ->
	console.log "Requesting to put file ", req.params.file
	fs.writeFile "./literals/#{req.params.file}", req.body.data, (err) ->
		if err
			throw err
		console.log "File saved successfully."

# Making a new file from scratch
app.post "/new", (req, res) ->
	# Generate a new URL for the file.
	name = ""
	encoder = "abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUWXYZ"
	for i in [1..5]
		index = Math.floor encoder.length*Math.random() 
		name += encoder[ index ]

	console.log "chose new file name: #{name}"

	fs.writeFile "./literals/#{name}", req.body.data, (err) ->
		if err
			throw err
		console.log "New file saved successfully."

	res.send name

app.listen port
console.log "Server started."