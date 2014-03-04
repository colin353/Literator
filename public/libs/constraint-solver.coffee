# The ConstraintSolver will look at all of the constraints
# and optimizations and try to find the best value of all 
# registered variables.
class window.ConstraintSolver
	constructor: ->
		@constraints 	= []
		@optimizations 	= []
		@variables		= {}

		@iterations 	= 500
		@gradient_step 	= 0.00005

		@debug_mode 	= yes

		@compiler 		= new ConstraintCompiler(@)

	registerVariable: (variable) ->
		@variables[variable.callsign] = variable

	registerConstraint: (constraint) ->
		@constraints.push constraint

	# Determine the current error value for the solver.
	error: ->
		error = 0
		for c in @constraints 
			error += c.error()
		return error

	debug: (message) ->
		if @debug_mode
			console.log message

	execute: (code) ->
		@compiler.execute code

	solve: ->
		# First, solve for the constraints, then solve
		# for the optimizations. 
		@debug "Beginning constraint solver under #{@constraints.length} constraints and #{@variables.length} variables."
		for i in [1..@iterations]
			error = @error()
			@debug "Beginning iteration #{i}, current error value = #{error}"
			# Initialize the gradient. This will contain the
			# error gradients summed over all constraints.
			variable_gradients = {}
			for k,v of @variables
				variable_gradients[k] = 0
			# For each constraint, determine the error gradient
			# for each variable.
			for c in @constraints 
				for k,v of variable_gradients
					this_error = @variables[k].determineErrorGradientWithRespectToConstraint.call @variables[k], c
					variable_gradients[k] += this_error
					console.log "The error on #{@variables[k].callsign} found was: #{this_error}"
			# Now that we have developed all of the gradients
			# we'll simply apply them and take another step.
			for k,v of @variables
				debug_string = "Increment #{v.callsign} from #{v.value} ->"
				v.assign(v.seed + variable_gradients[k] * @gradient_step)
				console.log debug_string, "#{v.value}"

		return @variables

# A variable is something that will be optimized over.  
class window.GenericVariable
	constructor: () ->
		# Assign the value using the generator. Use conditional
		# assignment operator to prevent accidentally overriding children.
		@value 		?= @assign Math.random()
		@callsign 	?= "_dump"
		@parent 	?= null
		@error_gradient_step ?= 0.001

	# The seed function takes a floating number between zero and one
	# and generates a value for the variable to take on.
	generator: (seed) ->
		throw "Can't generate with a GenericVariable"

	assign: (seed) ->
		@seed = seed
		# Generate the output value based upon the seed
		@value = @generator @seed
		# Run out the assignment onto the callsign variable
		window[@callsign] = @value

	registerWithParent: (@parent) ->
		yes

	determineErrorGradientWithRespectToConstraint: (constraint) ->
		window[@callsign] = @generator(@seed - 0.5 * @error_gradient_step)
		left_error = constraint.error()
		window[@callsign] = @generator(@seed + 0.5 * @error_gradient_step)
		right_error = constraint.error()
		# Restore the callsign's expected value.
		window[@callsign] = @value
		return -1.0 * ( right_error - left_error ) / @error_gradient_step

class window.UniformRangeVariable extends GenericVariable
	constructor: (@callsign, @lower_limit, @upper_limit) ->
		# If necessary, swap the limits to make sure higher > lower.
		if @lower_limit > @upper_limit
			[@lower_limit, @upper_limit] = [ @upper_limit, @lower_limit ]
		super()

	generator: (seed) ->
		# Normalize the value of the seed.
		if seed > 1
			seed = 1
		else if seed < 0
			seed = 0
		# And return the right value.
		@lower_limit + (@upper_limit - @lower_limit) * seed

class window.Constraint
	constructor: (@left_hand_expression, @right_hand_expression, @tolerance = 0.01) ->
		@validate()
		
	# Returns true or false based upon whether the condition is met.
	# The condition is considered met with respect to the tolerance.
	evaluate: ->
		LHS = eval @left_hand_expression
		RHS = eval @right_hand_expression
		if Math.abs(LHS - RHS) < @tolerance
			return yes
		else 
			return no

	# This might take some thinking on how to scale it...
	# but it returns the error associated with the condition.
	error: ->
		LHS = eval @left_hand_expression
		RHS = eval @right_hand_expression
		return Math.pow Math.abs(LHS - RHS), 2

	validate: ->
		# Let's try to evaluate the actual constraint
		# to make sure the code is not invalid.
		try 
			eval @left_hand_expression
			eval @right_hand_expression 
		catch error
			throw "Invalid constraint expression: #{error}"

# This class compiles text commands (code) into modifications
# to its parent ConstraintSolver object.
class window.ConstraintCompiler
	constructor: (@parent) ->
		yes

	execute: (code) ->
		code 	= code.replace /[\r]/gm,""
		lines 	= code.split /\n/
		for line in lines 
			# Split into individual words
			words = line.split /\s+/
			switch words[0]
				when ":variable"
					assert words[2] == "between", ":variable statement must include 'between' clause"
					assert words[4] == "and", ":variable statement must include 'and' subclause in 'between' clause"
					assert words.length == 6, "Invalid number of arguments for :variable, expected 4"
					lower_bound = parseFloat words[3]
					upper_bound = parseFloat words[5]
					@parent.registerVariable new UniformRangeVariable(words[1], lower_bound, upper_bound)
				when ":constraint"
					remaining_string = words[1..].join(' ')
					components = remaining_string.split /\=/
					assert components.length == 2, "Invalid constraint statement."
					left_side = components[0]
					right_side = components[1]
					@parent.registerConstraint new Constraint(left_side, right_side)
				when ":solve"
					assert words.length == 1, "Invalid 'solve' statement, unexpected extra clause"
					@parent.solve()
				else 
					throw "Unrecognized command #{words[0]}."


		