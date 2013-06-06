# postgres.tcl --
#
# PostgreSQL implementation module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class tdbo::PostgreSQL
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::PostgreSQL {
	inherit tdbo::Database
# ----------------------------------------------------------------------
# constructor:
#
#
#
# ----------------------------------------------------------------------
constructor {} {
	package require Pgtcl
}


# ----------------------------------------------------------------------
# destructor
#
#
#
# ----------------------------------------------------------------------
destructor {
}


# ----------------------------------------------------------------------
# method - open - Open a database connection. It returns an error if
#                 the connection is already open or if the location of
#                 the database file is not defined. Upon successful
#                 opening of the database connection, if an initscript
#                 is defined, it evaluates the initscript containing
#                 sqlite SQL commands.
#
#                 Returns the sqlite connection interface command.
#
# ----------------------------------------------------------------------
public method open {dbname args} {
	if {[info exists conn] && $conn != ""} {
		return -code error "An opened connection already exists."
	}

	if {[catch {pg_connect $dbname {*}$args} result]} {
		return -code error $result
	}

	set conn $result
	return $conn
}


# ----------------------------------------------------------------------
# method - close - Close the database connection.
#
#
#
# ----------------------------------------------------------------------
public method close {} {
	catch {pg_disconnect $conn}
	unset conn
}


# ----------------------------------------------------------------------
# method  - get - retrieve a single record from the table/view indicated
#                 by schema_name by performing a select query.
#
# args    - schema_name - table/view on which the select query is to be
#                         performed.
#           condition   - list of dictionaries. Every dictionary contains
#                         name-value pairs that will be joined with an
#                         AND operator. The list elements are joined
#                         with an OR operator. For e.g., the list:
#
#                          {{f1 val1 f2 val2} {f1 val3 f2 val4}}
#
#                         is translated into:
#
#                          ((f1='val1' AND f2='val2') OR
#                                (f1='val3' AND f2='va	l4'))
#           fieldslist  - list of field names to be retrieved using
#                         select query
#
# ----------------------------------------------------------------------
public method get {schema_name condition {fieldslist ""}} {
	if {$fieldslist == ""} {
		return [_select $schema_name -condition [_prepare_condition $condition]]
	} else {
		return [_select $schema_name -condition [_prepare_condition $condition] -fields $fieldslist]
	}
}

# ----------------------------------------------------------------------
# method  - mget - retrieve multiple records from the table/view
#                  by performing a select query.
#
# args    - schema_name - table/view on which the select query is to be
#                         performed.
#           args        - dictionary of option-value pairs. options
#                         supported are:
#
#             -fields     : list of fields to be retrieved. default
#                           value: * (for all fields)
#             -condition  : string in SQL to be used in WHERE clause of
#                           the select query.
#             -groupby    : string in SQL to be used in GROUP BY clause
#                           of the select query.
#             -orderby    : string in SQL to be used in ORDER BY clause
#                           of the select query.
#
# ----------------------------------------------------------------------
public method mget {schema_name args} {
	return [_select $schema_name {*}$args]
}


# ----------------------------------------------------------------------
# as defined by tdbo::Database::insert method
#
#
#
# ----------------------------------------------------------------------
public method insert {schema_name namevaluepairs {sequence_fields ""}} {
	set sqlscript [_prepare_insert_stmt $schema_name $namevaluepairs]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set status [pg_result $result -status]
${log}::debug "insert status: $status"

	if {$status != "PGRES_COMMAND_OK" && $status != "PGRES_TUPLES_OK"} {
		set error [pg_result $result -error]
		pg_result $result -clear
		return -code error $error
	}

	set numrows [pg_result $result -numTuples]
${log}::debug "insert numrows: $numrows"
	if {$numrows} {
		set sequencedict [pg_result $result -dict]		
${log}::debug "insert sequencedict: $sequencedict"
		pg_result $result -clear
		return [list $numrows [dict get $sequencedict 0]]
	}

	pg_result $result -clear
	return 1
}


# ----------------------------------------------------------------------
#
# as defined by tdbo::Database::update method
#
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}} {
	set sqlscript [_prepare_update_stmt $schema_name $namevaluepairs $condition]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set changes [pg_result $result -cmdTuples]
	pg_result $result -clear
	return $changes
}


# ----------------------------------------------------------------------
#
# as defined by tdbo::Database::delete method
#
#
# ----------------------------------------------------------------------
public method delete {schema_name {condition ""}} {
	set sqlscript [_prepare_delete_stmt $schema_name $condition]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set changes [pg_result $result -cmdTuples]
	pg_result $result -clear
	return $changes
}


# ----------------------------------------------------------------------
# method - begin a database transaction.
#
# args   - lock - type of lock. default value deferred. 
#
#
#
# ----------------------------------------------------------------------
public method begin {{lock deferrable}} {
	if {[catch {pg_exec $conn "begin $lock"} result]} {
		return -code error $result
	}
	pg_result $result -clear
}


# ----------------------------------------------------------------------
# method - commit the database transaction.
#
# args   - none. 
#
# ----------------------------------------------------------------------
public method commit {} {
	if {[catch {pg_exec $conn commit} result]} {
		return -code error $result
	}
	pg_result $result -clear
}


# ----------------------------------------------------------------------
# method - rollback the database transaction.
#
# args   - none. 
#
# ----------------------------------------------------------------------
public method rollback {} {
	if {[catch {pg_exec $conn rollback} result]} {
		return -code error $result
	}
	pg_result $result -clear
}


# ----------------------------------------------------------------------
# variable conn: Variable to hold sqlite database connection interface
#                returned by sqlite's open command.
#
#
#
# ----------------------------------------------------------------------
protected variable conn


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method _select {schema_name args} {
	set sqlscript [_prepare_select_stmt $schema_name {*}$args]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}
	set recordslist [dict values [pg_result $result -dict]]
	pg_result $result -clear

	return $recordslist
}


# ------------------------------END-------------------------------------
}
