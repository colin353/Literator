# Ruby

Ruby is the name of the game

	class Rubathon
		def name_of_game
			print "My name IS the game"
		end
	end

The next example will actually test the shared scope problem.

And now let's print it out:

	r = Rubathon.new

	print r.name_of_game

##CONSOLE##

Did it work?