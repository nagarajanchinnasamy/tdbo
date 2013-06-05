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
		return
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
	catch {$conn close}
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
	set sequence_values [dict create]
	set result [_insert $schema_name $namevaluepairs]
	if {$result} {
		set rowid [_last_insert_rowid]
		foreach fname $sequence_fields {
			dict set sequence_values -${fname} $rowid
		}
	}

	if {$sequence_fields == ""} {
		return $result
	}
	
	return [list $result $sequence_values]
}


# ----------------------------------------------------------------------
#
# as defined by tdbo::Database::update method
#
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}} {
	set setlist ""
	foreach {name val} $namevaluepairs {
		lappend setlist "$name='$val'"
	}
	set setlist [join $setlist ", "]

	set sqlscript "UPDATE $schema_name SET $setlist"
	if [string length $condition] {
		append sqlscript " WHERE [_prepare_condition $condition]"
	}

	${log}::debug $sqlscript

	if {[catch {$conn eval $sqlscript} err]} {
		return 0
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
	set sqlscript "DELETE FROM $schema_name"
	if {[string length $condition]} {
		append sqlscript " WHERE [_prepare_condition $condition]"
	}

	${log}::debug $sqlscript

	if {[catch {$conn eval $sqlscript} err]} {
		return 0
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
private method _select {table_name args} {
	set fields "*"
	set condition ""
	set groupby ""
	set orderby ""
	foreach {opt val} $args {
		switch $opt {
			-fields {
				set fields $val
			}
			-condition {
				set condition $val
			}
			-groupby {
				set groupby $val
			}
			-orderby {
				set orderby $val
			}
			default {
				return -code error "Unknown option: $opt"
			}
		}
	}
	set sqlscript "SELECT $fields FROM $table_name"
	if [string length $condition] {
		append sqlscript " WHERE $condition"
	}
	if [string length $groupby] {
		append sqlscript " GROUP BY $groupby"
	}
	if [string length $orderby] {
		append sqlscript " ORDER BY $orderby"
	}

	${log}::debug $sqlscript
	
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
private method _insert {schema_name namevaluepairs} {
	set fnamelist [join [dict keys $namevaluepairs] ", "]
	set valuelist [list]
	foreach value [dict values $namevaluepairs] {
		lappend valuelist '$value'
	} 
	set valuelist [join $valuelist ", "]

	set sqlscript "INSERT INTO $schema_name ($fnamelist) VALUES ($valuelist)"
	${log}::debug $sqlscript
	
	if {[catch {$conn eval $sqlscript} err]} {
		return 0
	}

	return [$conn changes]
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


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method _prepare_condition {conditionlist} {
	set sqlcondition [list]
	foreach condition $conditionlist {
		set complist [list]
		foreach {fname val} $condition {
			lappend complist "$fname='$val'"
		}
		if {$complist != ""} {
			lappend sqlcondition "([join $complist " and "])"
		}
	}

	if {$sqlcondition == ""} {
		return
	}

	set sqlcondition [join $sqlcondition " or "]
	return "($sqlcondition)"
}

# ------------------------------END-------------------------------------
}
