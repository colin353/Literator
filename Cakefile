# Note: this Cakefile was generated using the tutorial
# on GitHub: https://github.com/jashkenas/coffee-script/wiki/%5BHowTo%5D-Compiling-and-Setting-Up-Build-Tools

{exec} = require 'child_process'

task 'build', 'Build project coffeescript files.', ->
	exec 'coffee -cm app.coffee', (err, stdout, stderr) ->
		throw err if err
		console.log stdout + stderr
	exec 'coffee -cm public/', (err, stdout, stderr) ->
		throw err if err
		console.log stdout + stderr

task 'watch', 'Execute a build that watches!', ->
	exec 'coffee -wcm app.coffee', (err, stdout, stderr) ->
		throw err if err
		console.log stdout + stderr
	exec 'coffee -wcm public/', (err, stdout, stderr) ->
		throw err if err
		console.log stdout + stderr