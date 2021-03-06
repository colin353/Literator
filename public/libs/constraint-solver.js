// Generated by CoffeeScript 1.6.3
(function() {
  
Math.sign = function(x) {
    return typeof x === 'number' ? x ? x < 0 ? -1 : 1 : x === x ? 0 : NaN : NaN;
}
;
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  window.ConstraintSolver = (function() {
    function ConstraintSolver() {
      this.constraints = [];
      this.optimizations = [];
      this.variables = {};
      this.iterations = 500;
      this.gradient_step = .01;
      this.maximum_step = 0.2;
      this.debug_mode = true;
      this.compiler = new ConstraintCompiler(this);
    }

    ConstraintSolver.prototype.registerVariable = function(variable) {
      return this.variables[variable.callsign] = variable;
    };

    ConstraintSolver.prototype.registerConstraint = function(constraint) {
      return this.constraints.push(constraint);
    };

    ConstraintSolver.prototype.error = function() {
      var c, error, _i, _len, _ref;
      error = 0;
      _ref = this.constraints;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        error += c.error();
      }
      return error;
    };

    ConstraintSolver.prototype.normalizeConstraintErrors = function() {
      var c, constraint_errors, error, i, j, monte_carlo_iterations, n, v, _i, _j, _k, _l, _len, _ref, _ref1, _ref2, _ref3, _results;
      constraint_errors = (function() {
        var _i, _ref, _results;
        _results = [];
        for (i = _i = 1, _ref = this.constraints.length; 1 <= _ref ? _i <= _ref : _i >= _ref; i = 1 <= _ref ? ++_i : --_i) {
          _results.push(0);
        }
        return _results;
      }).call(this);
      _ref = this.constraints;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        c.error_normalization = 1;
      }
      monte_carlo_iterations = 1000;
      for (i = _j = 1; 1 <= monte_carlo_iterations ? _j <= monte_carlo_iterations : _j >= monte_carlo_iterations; i = 1 <= monte_carlo_iterations ? ++_j : --_j) {
        _ref1 = this.variables;
        for (n in _ref1) {
          v = _ref1[n];
          v.assign(Math.random());
        }
        for (j = _k = 0, _ref2 = this.constraints.length - 1; 0 <= _ref2 ? _k <= _ref2 : _k >= _ref2; j = 0 <= _ref2 ? ++_k : --_k) {
          error = Math.abs(this.constraints[j].error());
          if (error > 1e10 || isNaN(error)) {
            error = 1e10;
          }
          constraint_errors[j] += error;
        }
      }
      _results = [];
      for (j = _l = 0, _ref3 = this.constraints.length - 1; 0 <= _ref3 ? _l <= _ref3 : _l >= _ref3; j = 0 <= _ref3 ? ++_l : --_l) {
        if (constraint_errors[j] === 0 || isNaN(constraint_errors[j])) {
          constraint_errors[j] = monte_carlo_iterations;
        }
        console.log("Constraint error for " + j + " is " + constraint_errors[j]);
        _results.push(this.constraints[j].error_normalization = monte_carlo_iterations / constraint_errors[j]);
      }
      return _results;
    };

    ConstraintSolver.prototype.debug = function(message) {
      if (this.debug_mode) {
        return console.log(message);
      }
    };

    ConstraintSolver.prototype.execute = function(code) {
      return this.compiler.execute(code);
    };

    ConstraintSolver.prototype.solve = function() {
      var c, i, k, met_constraints, step, this_error, v, variable_gradients, _i, _j, _k, _len, _len1, _ref, _ref1, _ref2, _ref3, _ref4;
      this.debug("Beginning constraint solver under " + this.constraints.length + " constraints and " + (Object.keys(this.variables).length) + " variables.");
      this.normalizeConstraintErrors();
      for (i = _i = 1, _ref = this.iterations; 1 <= _ref ? _i <= _ref : _i >= _ref; i = 1 <= _ref ? ++_i : --_i) {
        variable_gradients = {};
        _ref1 = this.variables;
        for (k in _ref1) {
          v = _ref1[k];
          variable_gradients[k] = 0;
        }
        _ref2 = this.constraints;
        for (_j = 0, _len = _ref2.length; _j < _len; _j++) {
          c = _ref2[_j];
          for (k in variable_gradients) {
            v = variable_gradients[k];
            this_error = this.variables[k].determineErrorGradientWithRespectToConstraint.call(this.variables[k], c);
            variable_gradients[k] += this_error;
          }
        }
        _ref3 = this.variables;
        for (k in _ref3) {
          v = _ref3[k];
          step = variable_gradients[k] * this.gradient_step;
          if (Math.abs(step) > this.maximum_step) {
            console.log("Limiting max step!");
            step = this.maximum_step * Math.sign(step);
          }
          v.assign(v.seed + step);
        }
      }
      console.log(this.variables);
      met_constraints = true;
      _ref4 = this.constraints;
      for (_k = 0, _len1 = _ref4.length; _k < _len1; _k++) {
        c = _ref4[_k];
        if (!c.evaluate()) {
          met_constraints = false;
          break;
        }
      }
      console.log("Completed optimization with error = " + (this.error()));
      if (met_constraints) {
        console.log("All constraints successfully met.");
      } else {
        console.warn("Not all constraints were met.");
      }
      return this.variables;
    };

    return ConstraintSolver;

  })();

  window.GenericVariable = (function() {
    function GenericVariable() {
      if (this.value == null) {
        this.value = this.assign(Math.random());
      }
      if (this.callsign == null) {
        this.callsign = "_dump";
      }
      if (this.parent == null) {
        this.parent = null;
      }
      if (this.error_gradient_step == null) {
        this.error_gradient_step = 0.5;
      }
    }

    GenericVariable.prototype.generator = function(seed) {
      throw "Can't generate with a GenericVariable";
    };

    GenericVariable.prototype.assign = function(seed) {
      this.seed = seed;
      this.value = this.generator(this.seed);
      return window[this.callsign] = this.value;
    };

    GenericVariable.prototype.registerWithParent = function(parent) {
      this.parent = parent;
      return true;
    };

    GenericVariable.prototype.determineErrorGradientWithRespectToConstraint = function(constraint) {
      var left_error, right_error;
      window[this.callsign] = this.generator(this.seed - 0.5 * this.error_gradient_step);
      left_error = constraint.error();
      window[this.callsign] = this.generator(this.seed + 0.5 * this.error_gradient_step);
      right_error = constraint.error();
      window[this.callsign] = this.value;
      return -1.0 * (right_error - left_error) / this.error_gradient_step;
    };

    return GenericVariable;

  })();

  window.UniformRangeVariable = (function(_super) {
    __extends(UniformRangeVariable, _super);

    function UniformRangeVariable(callsign, lower_limit, upper_limit) {
      var _ref;
      this.callsign = callsign;
      this.lower_limit = lower_limit;
      this.upper_limit = upper_limit;
      if (this.lower_limit > this.upper_limit) {
        _ref = [this.upper_limit, this.lower_limit], this.lower_limit = _ref[0], this.upper_limit = _ref[1];
      }
      UniformRangeVariable.__super__.constructor.call(this);
    }

    UniformRangeVariable.prototype.generator = function(seed) {
      if (seed > 1) {
        seed = 1;
      } else if (seed < 0) {
        seed = 0;
      }
      return this.lower_limit + (this.upper_limit - this.lower_limit) * seed;
    };

    return UniformRangeVariable;

  })(GenericVariable);

  window.Constraint = (function() {
    function Constraint(left_hand_expression, right_hand_expression, tolerance) {
      this.left_hand_expression = left_hand_expression;
      this.right_hand_expression = right_hand_expression;
      this.tolerance = tolerance != null ? tolerance : 0.01;
      this.validate();
      this.error_normalization = 1;
    }

    Constraint.prototype.evaluate = function() {
      var LHS, RHS;
      LHS = eval(this.left_hand_expression);
      RHS = eval(this.right_hand_expression);
      if (Math.abs(LHS - RHS) < this.tolerance) {
        return true;
      } else {
        return false;
      }
    };

    Constraint.prototype.error = function() {
      var LHS, RHS;
      LHS = eval(this.left_hand_expression);
      RHS = eval(this.right_hand_expression);
      return this.error_normalization * Math.pow(LHS - RHS, 2);
    };

    Constraint.prototype.validate = function() {
      var error;
      try {
        eval(this.left_hand_expression);
        return eval(this.right_hand_expression);
      } catch (_error) {
        error = _error;
        throw "Invalid constraint expression: " + error;
      }
    };

    return Constraint;

  })();

  window.EqualityConstraint = (function(_super) {
    __extends(EqualityConstraint, _super);

    EqualityConstraint.identify = function(expression) {
      var components;
      components = expression.split(/\=/);
      if (components.length === 2) {
        return true;
      }
    };

    function EqualityConstraint(expression) {
      var components;
      components = expression.split(/\=/);
      EqualityConstraint.__super__.constructor.call(this, components[0], components[1]);
    }

    return EqualityConstraint;

  })(Constraint);

  window.InequalityConstraint = (function(_super) {
    __extends(InequalityConstraint, _super);

    InequalityConstraint.identify = function(expression) {
      var components;
      components = expression.split(/[><]/);
      if (components.length === 2) {
        return true;
      }
    };

    function InequalityConstraint(expression) {
      var components;
      components = expression.split(/[><]/);
      if (expression.match(/([><])/)[0] === "<") {
        InequalityConstraint.__super__.constructor.call(this, components[0], components[1]);
      } else {
        InequalityConstraint.__super__.constructor.call(this, components[1], components[0]);
      }
    }

    InequalityConstraint.prototype.evaluate = function() {
      var LHS, RHS;
      LHS = eval(this.left_hand_expression);
      RHS = eval(this.right_hand_expression);
      if (LHS < RHS) {
        return true;
      } else {
        return false;
      }
    };

    InequalityConstraint.prototype.error = function() {
      var LHS, RHS;
      LHS = eval(this.left_hand_expression);
      RHS = eval(this.right_hand_expression);
      if (LHS < RHS) {
        return 0;
      } else {
        return Math.pow(LHS - RHS, 2);
      }
    };

    return InequalityConstraint;

  })(Constraint);

  window.ConstraintCompiler = (function() {
    function ConstraintCompiler(parent) {
      this.parent = parent;
      this.constraint_types = [EqualityConstraint, InequalityConstraint];
    }

    ConstraintCompiler.prototype.execute = function(code) {
      var c, line, lines, lower_bound, recognized_constraint, remaining_string, upper_bound, words, _i, _j, _len, _len1, _ref, _results;
      code = code.replace(/[\r]/gm, "");
      lines = code.split(/\n/);
      _results = [];
      for (_i = 0, _len = lines.length; _i < _len; _i++) {
        line = lines[_i];
        words = line.split(/\s+/);
        switch (words[0]) {
          case ":variable":
            assert(words[2] === "between", ":variable statement must include 'between' clause");
            assert(words[4] === "and", ":variable statement must include 'and' subclause in 'between' clause");
            assert(words.length === 6, "Invalid number of arguments for :variable, expected 4");
            lower_bound = parseFloat(words[3]);
            upper_bound = parseFloat(words[5]);
            _results.push(this.parent.registerVariable(new UniformRangeVariable(words[1], lower_bound, upper_bound)));
            break;
          case ":constraint":
            remaining_string = words.slice(1).join(' ');
            recognized_constraint = false;
            _ref = this.constraint_types;
            for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
              c = _ref[_j];
              if (c.identify(remaining_string)) {
                this.parent.registerConstraint(new c(remaining_string));
                recognized_constraint = true;
                break;
              }
            }
            _results.push(assert(recognized_constraint, "Unrecognized constraint: '" + remaining_string + "'"));
            break;
          case ":solve":
            assert(words.length === 1, "Invalid 'solve' statement, unexpected extra clause");
            _results.push(this.parent.solve());
            break;
          default:
            throw "Unrecognized command " + words[0] + ".";
        }
      }
      return _results;
    };

    return ConstraintCompiler;

  })();

}).call(this);

/*
//@ sourceMappingURL=constraint-solver.map
*/
