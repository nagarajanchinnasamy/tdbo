# sqlitedb.tcl --
#
# sqlite3 implementation module. Takes care of translating object methods
# to corresponding sql queries and executes them.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class SQLite
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::SQLite {
	inherit tdbo::Database
# ----------------------------------------------------------------------
# constructor:
#
#
#
# ----------------------------------------------------------------------
constructor {} {
	package require sqlite3
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
public method open {location {initscript ""}} {
	if {[info exists conn] && $conn != ""} {
		return -code error "An opened connection already exists."
	}

	incr conncount
	set conn sqlite_$conncount
	if {[catch {sqlite3 $conn $location} err]} {
		unset conn
		return -code error $err
	}

	if {$initscript != ""} {
		$conn eval $initscript
	}

	return $conn
}


# ----------------------------------------------------------------------
# method - close - Close the database connection.
#
#
#
# ----------------------------------------------------------------------
public method close {} {
	if {![info exists conn]} {
		return
	}

	catch {
		$conn close
	}
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
	if {[catch {$conn eval $sqlscript} result]} {
		return -code error $result
	}

	set status [$conn changes]
	if {$sequence_fields == ""} {
		return $status
	}

	set sequence_values [dict create]
	set rowid [_last_insert_rowid]
	foreach fname $sequence_fields {
		dict set sequence_values $fname $rowid
	}

	return [list $status $sequence_values]
}


# ----------------------------------------------------------------------
#
# as defined by tdbo::Database::update method
#
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}} {
	set sqlscript [_prepare_update_stmt $schema_name $namevaluepairs $condition]
	if {[catch {$conn eval $sqlscript} err]} {
		return -code error $err
	}

	return [$conn changes]
}


# ----------------------------------------------------------------------
#
# as defined by tdbo::Database::delete method
#
#
# ----------------------------------------------------------------------
public method delete {schema_name {condition ""}} {
	set sqlscript [_prepare_delete_stmt $schema_name $condition]
	if {[catch {$conn eval $sqlscript} err]} {
		return -code error $err
	}

	return [$conn changes]
}


# ----------------------------------------------------------------------
# method - begin a database transaction.
#
# args   - lock - type of lock. default value deferred. 
#
#
#
# ----------------------------------------------------------------------
public method begin {{lock deferred}} {
	$conn eval begin $lock
}


# ----------------------------------------------------------------------
# method - commit the database transaction.
#
# args   - none. 
#
# ----------------------------------------------------------------------
public method commit {} {
	$conn eval commit
}


# ----------------------------------------------------------------------
# method - rollback the database transaction.
#
# args   - none. 
#
# ----------------------------------------------------------------------
public method rollback {} {
	$conn eval rollback
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
	set sqlscript [_prepare_select_stmt $schema_name {*}$args
	set recordslist ""
	if {[catch {
		$conn eval $sqlscript record {
			array unset record "\\*"
			lappend recordslist [array get record]
		}} err]} {
		${log}::notice "Error: $err"
		return
	}

	return $recordslist
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method _last_insert_rowid {} {
	return [$conn last_insert_rowid]
}


# ------------------------------END-------------------------------------
}
