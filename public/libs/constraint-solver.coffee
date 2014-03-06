# The ConstraintSolver will look at all of the constraints
# and optimizations and try to find the best value of all 
# registered variables.

# This is an optimized Math.sign function that we need to use
# on several occasions. It was taken from StackOverflow.
`
Math.sign = function(x) {
    return typeof x === 'number' ? x ? x < 0 ? -1 : 1 : x === x ? 0 : NaN : NaN;
}
`

class window.ConstraintSolver
	constructor: ->
		@constraints 	= []
		@optimizations 	= []
		@variables		= {}

		@iterations 	= 500
		@gradient_step 	= .01
		@maximum_step	= 0.2

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

	normalizeConstraintErrors: ->
		constraint_errors = ( 0 for i in [1..@constraints.length] )

		# Reset any pre-existing constraint normalization
		for c in @constraints 
			c.error_normalization = 1

		monte_carlo_iterations = 1000
		for i in [1..monte_carlo_iterations]
			# Start by randomly surveying the variables within
			# their expected ranges.
			for n,v of @variables
				v.assign Math.random()
			# Now, evaluate the constraint errors.
			for j in [0..(@constraints.length-1)]
				error = Math.abs @constraints[j].error()
				if error > 1e10 || isNaN error
					error = 1e10
				constraint_errors[j] += error

		for j in [0..(@constraints.length-1)]
			# Handle the case where there are no errors. In that case,
			# don't actually do any normalization.
			if constraint_errors[j] == 0 || isNaN(constraint_errors[j])
				constraint_errors[j] = monte_carlo_iterations
			console.log "Constraint error for #{j} is #{constraint_errors[j]}"
			# Tell the constraints to self-normalize with this factor.
			@constraints[j].error_normalization = monte_carlo_iterations / constraint_errors[j]

	debug: (message) ->
		if @debug_mode
			console.log message

	execute: (code) ->
		@compiler.execute code

	solve: ->
		# First, solve for the constraints, then solve
		# for the optimizations. 
		@debug "Beginning constraint solver under #{@constraints.length} constraints and #{Object.keys(@variables).length} variables."
		# Start by performing constraint normalization, 
		# which ensures that all constraints are equally weighted.
		@normalizeConstraintErrors()
		# Now iterate through everything.
		for i in [1..@iterations]
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
					#console.log "The error on #{@variables[k].callsign} found was: #{this_error}"
			# Now that we have developed all of the gradients
			# we'll simply apply them and take another step.
			for k,v of @variables
				# Ostensibly the step will be in the direction of the gradient:
				step = variable_gradients[k] * @gradient_step
				# We need to limit the maximum value of the variable gradients to prevent huge jumps. 
				if Math.abs(step) > @maximum_step
					console.log "Limiting max step!"
					step = @maximum_step * Math.sign(step)
				v.assign(v.seed + step)

		console.log @variables

		# Check to see if all constraints passed.
		met_constraints = yes
		for c in @constraints
			if !c.evaluate() 
				met_constraints = no
				break

		console.log "Completed optimization with error = #{@error()}"

		if met_constraints
			console.log "All constraints successfully met."
		else 
			console.warn "Not all constraints were met."

		return @variables

# A variable is something that will be optimized over.  
class window.GenericVariable
	constructor: () ->
		# Assign the value using the generator. Use conditional
		# assignment operator to prevent accidentally overriding children.
		@value 		?= @assign Math.random()
		@callsign 	?= "_dump"
		@parent 	?= null
		@error_gradient_step ?= 0.5

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
		@error_normalization = 1
		
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
		return @error_normalization * Math.pow(LHS - RHS, 2)

	validate: ->
		# Let's try to evaluate the actual constraint
		# to make sure the code is not invalid.
		try 
			eval @left_hand_expression
			eval @right_hand_expression 
		catch error
			throw "Invalid constraint expression: #{error}"

class window.EqualityConstraint extends Constraint
	@identify: (expression) ->
		components = expression.split /\=/
		if components.length == 2
			return yes

	constructor: (expression) ->
		components = expression.split /\=/
		super components[0], components[1]

class window.InequalityConstraint extends Constraint

	@identify: (expression) ->
		components = expression.split /[><]/
		if components.length == 2
			return yes

	constructor: (expression) ->
		components = expression.split /[><]/
		if expression.match(/([><])/)[0] == "<"
			super components[0], components[1]
		else 
			super components[1], components[0]

	evaluate: ->
		LHS = eval @left_hand_expression
		RHS = eval @right_hand_expression
		if LHS < RHS
			return yes
		else return no

	error: ->
		LHS = eval @left_hand_expression
		RHS = eval @right_hand_expression
		if LHS < RHS 
			return 0
		else 
			return Math.pow(LHS - RHS,2)

# This class compiles text commands (code) into modifications
# to its parent ConstraintSolver object.
class window.ConstraintCompiler
	constructor: (@parent) ->
		@constraint_types = [EqualityConstraint, InequalityConstraint]

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
					recognized_constraint = no
					for c in @constraint_types
						if c.identify remaining_string
							@parent.registerConstraint new c(remaining_string)
							recognized_constraint = yes
							break
					assert recognized_constraint, "Unrecognized constraint: '#{remaining_string}'"
				when ":solve"
					assert words.length == 1, "Invalid 'solve' statement, unexpected extra clause"
					@parent.solve()
				else 
					throw "Unrecognized command #{words[0]}."


		