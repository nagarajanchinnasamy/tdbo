# postgres.tcl --
#
# PostgreSQL connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require logger

namespace eval ::tdbo::postgres {
	variable log [::logger::init [namespace current]]
}

proc ::tdbo::postgres::Load {{_use_tdbc 0}} {
	package require Pgtcl
}

proc ::tdbo::postgres::open {dbname args} {
	if {[catch {pg_connect $dbname {*}$args} result]} {
		return -code error $result
	}

	set conn $result
	return $conn
}


proc ::tdbo::postgres::close {conn} {
	catch {pg_disconnect $conn}
}

proc ::tdbo::postgres::get {conn schema_name fieldslist conditionlist {format "dict"}} {
	return [
		_select \
			$conn \
			$schema_name \
			-fields $fieldslist \
			-format $format \
			-condition [_prepare_condition $conn $conditionlist] \
	]
}

proc ::tdbo::postgres::mget {conn schema_name args} {
	return [_select $conn $schema_name {*}$args]
}

proc ::tdbo::postgres::insert {conn schema_name namevaluepairs {sequence_fields ""}} {
	set sqlscript [_prepare_insert_stmt $conn $schema_name $namevaluepairs $sequence_fields]

	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set status [pg_result $result -status]

	if {$status != "PGRES_COMMAND_OK" && $status != "PGRES_TUPLES_OK"} {
		set error [pg_result $result -error]
		pg_result $result -clear
		return -code error $error
	}

	set numrows [pg_result $result -numTuples]
	if {$numrows} {
		set sequencedict [pg_result $result -dict]		
		pg_result $result -clear
		return [list $numrows [dict get $sequencedict 0]]
	}

	pg_result $result -clear
	return 1
}

proc ::tdbo::postgres::update {conn schema_name namevaluepairs {conditionlist ""}} {
	set sqlscript [_prepare_update_stmt $conn $schema_name $namevaluepairs $conditionlist]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set changes [pg_result $result -cmdTuples]
	pg_result $result -clear
	return $changes
}

proc ::tdbo::postgres::delete {conn schema_name {conditionlist ""}} {
	set sqlscript [_prepare_delete_stmt $conn $schema_name $conditionlist]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set changes [pg_result $result -cmdTuples]
	pg_result $result -clear

	if {[string is integer -strict $changes]} {
		return $changes
	}

	return 0
}

proc ::tdbo::postgres::begin {conn {lock deferrable}} {
	if {[catch {pg_exec $conn "begin $lock"} result]} {
		return -code error $result
	}
	pg_result $result -clear
}

proc ::tdbo::postgres::commit {conn} {
	if {[catch {pg_exec $conn commit} result]} {
		return -code error $result
	}
	pg_result $result -clear
}

proc ::tdbo::postgres::rollback {conn} {
	if {[catch {pg_exec $conn rollback} result]} {
		return -code error $result
	}
	pg_result $result -clear
}

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
proc ::tdbo::postgres::_prepare_condition {conn conditionlist} {
	set sqlcondition [list]
	foreach condition $conditionlist {
		set complist [list]
		foreach {fname val} $condition {
			if {$val == "IS NULL"} {
				lappend complist "$fname IS NULL"
			} else {
				lappend complist "$fname=[pg_quote $val]"
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
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
proc ::tdbo::postgres::_prepare_insert_stmt {conn schema_name namevaluepairs {sequencefields ""}} {
	variable log

	set fnamelist [join [dict keys $namevaluepairs] ", "]
	set valuelist [list]
	foreach value [dict values $namevaluepairs] {
		lappend valuelist [pg_quote $value]
	} 
	set valuelist [join $valuelist ", "]

	set stmt "INSERT INTO $schema_name ($fnamelist) VALUES ($valuelist)"
	if {$sequencefields != ""} {
		set sequencefields [join $sequencefields ", "]
		append stmt " RETURNING $sequencefields"
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
proc ::tdbo::postgres::_prepare_update_stmt {conn schema_name namevaluepairs {conditionlist ""}} {
	variable log

	dict for {fname val} $namevaluepairs {
		lappend setlist "$fname=[pg_quote $val]"
	}

	set setlist [join $setlist ", "]

	set stmt "UPDATE $schema_name SET $setlist"
	if {[llength $conditionlist]} {
		append stmt " WHERE [_prepare_condition $conn $conditionlist]"
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
proc ::tdbo::postgres::_prepare_delete_stmt {conn schema_name {conditionlist ""}} {
	variable log

	set stmt "DELETE FROM $schema_name"
	if {[llength $conditionlist]} {
		append stmt " WHERE [_prepare_condition $conn $conditionlist]"
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
proc ::tdbo::postgres::_prepare_select_stmt {schema_name args} {
	variable log

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
#
# format: one of "dict", "llist", "list" 
#
# ----------------------------------------------------------------------
proc ::tdbo::postgres::_select {conn schema_name args} {
	variable log

	set format "dict"
	if {[dict exists $args -format]} {
		set format [dict get $args -format]
		dict unset args -format
	}

	set sqlscript [_prepare_select_stmt $schema_name {*}$args]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set recordslist ""
	switch -- $format {
		dict {
			foreach row [dict values [pg_result $result -dict]] {
				set record ""
				foreach {field val} $row {
					lappend record "-$field" $val
				}
				lappend recordslist $record
			}
		}
		list -
		llist {
			set recordslist [dict values [pg_result $result -$format]]
		}
	}

	pg_result $result -clear
	return $recordslist
}

package provide tdbo::postgres 0.1.1
