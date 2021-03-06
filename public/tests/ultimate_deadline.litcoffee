# Phase II Schedule Validator

This file is designed to help validate that everything will be proceeding on schedule, before the **ultimate deadline**.

	ultimate_deadline = moment "April 15, 2014"

Now we have to list all of the dependencies. There are three phases of dependencies 
which need to be met independently. 

	dependencies = []

## Lab Preparation

The main items in laboratory preparation are:

1. Physical support mechanism
2. Electrical systems
3. Cooling systems 
4. Vacuum systems
5. Electronics rack mounting systems

### Physical support, electrical and cooling

These dates were given in an email.

	dependencies.push = { 
		name: "Physical support mechanism, electrical and cooling",
		date: moment("February 13 2014").add 'weeks', 7
	}

### Vacuum

According to the manufacturers, the average lead time is 6-8 weeks.

	vacuum = {
		purchase_date: moment "February 24, 2014",
		lead_time:	  8  # weeks.
	}

	dependencies.push = { 
		name: "Vacuum systems"
		date: vacuum.purchase_date.add 'weeks', vacuum.lead_time
	}

## Validation

Here, we validate the dates. Check the code below for errors.

	for d in dependencies
		assert ultimate_deadline.diff(d.date) > 0, "Date invalid for #{d.name}, reporting completion on #{d.date.toString()}"