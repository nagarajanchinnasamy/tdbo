# sqlitedb.tcl --
#
# sqlite3 connectivity module.
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
	if {[info exists conn] && $conn != ""} {
		catch {$conn close}
	}
}


# ----------------------------------------------------------------------
# method - open - Open a database connection.
#
#
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

	namespace eval ${clsName}::${conn} {}

${log}::debug "${clsName}::${conn}"

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

	catch {$conn close}
	unset conn
}


# ----------------------------------------------------------------------
# method - close - Close the database connection.
#
#
#
# ----------------------------------------------------------------------
public method quote {value} {
	return -code error "Method quote is not supported by $clsName"
}

# ----------------------------------------------------------------------
#
# method - get - get a record from table/view
#
# format: one of "dict", "list"
# ----------------------------------------------------------------------
public method get {schema_name fieldslist conditionlist {format "dict"}} {
	return [_select $schema_name -fields $fieldslist -format $format -condition [_prepare_condition $conditionlist]]
}


# ----------------------------------------------------------------------
#
# method - mget - get multiple records from table/view
#
# format: one of "dict", "llist", "list" 
# ----------------------------------------------------------------------
public method mget {schema_name args} {
	return [_select $schema_name {*}$args]
}


# ----------------------------------------------------------------------
#
# method - insert - insert a record into table/view
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
	set rowid [$conn last_insert_rowid]
	foreach fname $sequence_fields {
		dict set sequence_values $fname $rowid
	}

	return [list $status $sequence_values]
}


# ----------------------------------------------------------------------
#
# method - update - update record(s) of a table/view
#
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {conditionlist ""}} {
	set sqlscript [_prepare_update_stmt $schema_name $namevaluepairs $conditionlist]
	if {[catch {$conn eval $sqlscript} err]} {
		return -code error $err
	}

	return [$conn changes]
}


# ----------------------------------------------------------------------
#
# method - delete - delete record(s) from a table/view
#
#
# ----------------------------------------------------------------------
public method delete {schema_name {conditionlist ""}} {
	set sqlscript [_prepare_delete_stmt $schema_name $conditionlist]
	if {[catch {$conn eval $sqlscript} err]} {
		return -code error $err
	}

	return [$conn changes]
}


# ----------------------------------------------------------------------
#
# method - begin a database transaction.
#
#
# ----------------------------------------------------------------------
public method begin {{lock deferred}} {
	$conn eval begin $lock
}


# ----------------------------------------------------------------------
#
# method - commit the database transaction.
#
# ----------------------------------------------------------------------
public method commit {} {
	$conn eval commit
}


# ----------------------------------------------------------------------
#
# method - rollback the database transaction.
#
#
# ----------------------------------------------------------------------
public method rollback {} {
	$conn eval rollback
}


# ----------------------------------------------------------------------
# variable conn: Variable to hold database connection.
#
#
#
# ----------------------------------------------------------------------
protected variable conn
protected common conncount 0


# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
protected method _nsvar {varname} {
	return "${clsName}::${conn}::${varname}"
}

# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
protected method _prepare_insert_stmt {schema_name namevaluepairs} {
	set fnames [dict keys $namevaluepairs]

${log}::debug "$schema_name  $namevaluepairs"

	dict for {fname val} $namevaluepairs {
		set nsname [_nsvar $fname]
		set $nsname $val
		lappend valuelist ":$nsname"
	}

	set stmt "INSERT INTO $schema_name ([join $fnames ", "]) VALUES ([join $valuelist ", "])"
	${log}::debug $stmt
	return $stmt
}


# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
protected method _prepare_select_stmt {schema_name args} {
	set fieldslist "*"

	set condition ""
	set groupby ""
	set orderby ""
	foreach {opt val} $args {
		switch $opt {
			-condition {
				set condition $val
			}
			-groupby {
				set groupby $val
			}
			-orderby {
				set orderby $val
			}
			-fields {
				set fieldslist [join $val ", "]
			}
			default {
				return -code error "Unknown option: $opt"
			}
		}
	}

	set stmt "SELECT $fieldslist FROM $schema_name"
	if [string length $condition] {
		append stmt " WHERE $condition"
	}
	if [string length $groupby] {
		append stmt " GROUP BY $groupby"
	}
	if [string length $orderby] {
		append stmt " ORDER BY $orderby"
	}

	${log}::debug $stmt
	return $stmt
}


# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
protected method _prepare_update_stmt {schema_name namevaluepairs {conditionlist ""}} {
	${log}::debug "$schema_name $namevaluepairs $conditionlist"

	dict for {fname val} $namevaluepairs {
		set nsname [_nsvar $fname] 
		set $nsname $val
		lappend setlist "$fname=:$nsname"
	}

	${log}::debug "$setlist"

	set setlist [join $setlist ", "]

	set stmt "UPDATE $schema_name SET $setlist"
	if [llength $conditionlist] {
		append stmt " WHERE [_prepare_condition $conditionlist]"
	}

	${log}::debug $stmt
	return $stmt
}


# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
protected method _prepare_delete_stmt {schema_name {conditionlist ""}} {
	set stmt "DELETE FROM $schema_name"
	if {[llength $conditionlist]} {
		append stmt " WHERE [_prepare_condition $conditionlist]"
	}

	${log}::debug $stmt
	return $stmt
}

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _prepare_condition {conditionlist} {
	set sqlcondition [list]
	foreach condition $conditionlist {
		set complist [list]
		foreach {fname val} $condition {
			if {$val == "IS NULL"} {
				lappend complist "$fname IS NULL"
			} else {
				set nsname [_nsvar $fname]
				set $nsname $val
				lappend complist "$fname=:$nsname"
			}
		}
		if {$complist != ""} {
			lappend sqlcondition "([join $complist " AND "])"
		}
	}

	if {$sqlcondition == ""} {
		return
	}

	set sqlcondition [join $sqlcondition " OR "]
	return "($sqlcondition)"
}

# ----------------------------------------------------------------------
#
# format: one of "dict", "llist", "list" 
#
# ----------------------------------------------------------------------
private method _select {schema_name args} {
	set format "dict"
	if {[dict exists $args -format]} {
		set format [dict get $args -format]
		dict unset args -format
	}

	set sqlscript [_prepare_select_stmt $schema_name {*}$args]

	set recordslist ""
	switch -- $format {
		dict {
			if {[catch {
				$conn eval $sqlscript record {
					array unset record "\\*"
					set reccfg [dict create]
					dict for {f v} [array get record] {
						dict set reccfg "-$f" "$v"
					}
					lappend recordslist [dict get $reccfg]
				}} err]} {
				return -code error $err
			}
		}
		llist {
			if {[catch {
				$conn eval $sqlscript record {
					array unset record "\\*"
					lappend recordslist [dict values [array get record]]
				}} err]} {
				return -code error $err
			}
		}
		list {
			if {[catch {$conn eval $sqlscript} result]} {
				return -code error $result
			}
			set recordslist $result 
		}
	}

	return $recordslist
}


# ------------------------------END-------------------------------------
}
