# mariadb.tcl --
#
# MariaDB/MySQL connecitivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require logger

namespace eval ::tdbo::mariadb {
	variable log [::logger::init [namespace current]]
}

proc ::tdbo::mariadb::Load {{_use_tdbc 0}} {
	package require mysqltcl
}

proc ::tdbo::mariadb::open {dbname args} {
	
	if {[catch {mysql::connect {*}$args} result]} {
		return -code error $result
	}

	set conn $result
	if {[catch {mysql::use $conn $dbname} result]} {
		catch {mysql::close $conn}
		return -code error $result
	}

	return $conn
}

proc ::tdbo::mariadb::close {conn} {
	catch {mysql::close $conn}
}

proc ::tdbo::mariadb::get {conn schema_name fieldslist conditionlist {format "dict"}} {
	return [
		_select \
			$conn \
			$schema_name \
			-fields $fieldslist \
			-format $format \
			-condition [_prepare_condition $conn $conditionlist] \
	]
}

proc ::tdbo::mariadb::mget {conn schema_name args} {
	return [_select $conn $schema_name {*}$args]
}

proc ::tdbo::mariadb::insert {conn schema_name namevaluepairs {sequence_fields ""}} {
	set sqlscript [_prepare_insert_stmt $conn $schema_name $namevaluepairs]

	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set status 1
	if {$sequence_fields == ""} {
		return $status
	}

	set sequence_values [dict create]
	set rowid [mysql::insertid $conn]
	foreach fname $sequence_fields {
		dict set sequence_values $fname $rowid
	}

	return [list $status $sequence_values]
}

proc ::tdbo::mariadb::update {conn schema_name namevaluepairs {conditionlist ""}} {
	set sqlscript [_prepare_update_stmt $conn $schema_name $namevaluepairs $conditionlist]
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::mariadb::delete {conn schema_name {conditionlist ""}} {
	set sqlscript [_prepare_delete_stmt $conn $schema_name $conditionlist]
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::mariadb::begin {conn {isolation "repeatable read"}} {
	set sqlscript "set transaction isolation level $isolation"
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}
	set sqlscript "start transaction"
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}
}

proc ::tdbo::mariadb::commit {conn} {
	set sqlscript "commit;\n"
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}
}

proc ::tdbo::mariadb::rollback {conn} {
	set sqlscript "rollback;\n"
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}
}

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
proc ::tdbo::mariadb::_prepare_condition {conn conditionlist} {
	set sqlcondition [list]
	foreach condition $conditionlist {
		set complist [list]
		foreach {fname val} $condition {
			if {$val == "IS NULL"} {
				lappend complist "$fname IS NULL"
			} else {
				lappend complist "$fname=[mysql::escape $conn $val]"
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
proc ::tdbo::mariadb::_prepare_insert_stmt {conn schema_name namevaluepairs} {
	variable log

	set fnamelist [join [dict keys $namevaluepairs] ", "]
	set valuelist [list]
	foreach value [dict values $namevaluepairs] {
		lappend valuelist [mysql::escape $conn $value]
	} 
	set valuelist [join $valuelist ", "]

	set stmt "INSERT INTO $schema_name ($fnamelist) VALUES ($valuelist)"

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
proc ::tdbo::mariadb::_prepare_update_stmt {conn schema_name namevaluepairs {conditionlist ""}} {
	variable log

	dict for {fname val} $namevaluepairs {
		lappend setlist "$fname=[mysql::escape $conn $val]"
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
proc ::tdbo::mariadb::_prepare_delete_stmt {conn schema_name {conditionlist ""}} {
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
proc ::tdbo::mariadb::_prepare_select_stmt {schema_name args} {
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
proc ::tdbo::mariadb::_select {conn schema_name args} {
	set format "dict"
	if {[dict exists $args -format]} {
		set format [dict get $args -format]
		dict unset args -format
	}

	set sqlscript [_prepare_select_stmt $schema_name {*}$args]
	if {[catch {mysql::sel $conn $sqlscript -list} result]} {
		return -code error $result
	}

	set recordslist ""
	switch -- $format {
		dict {
			foreach row $result {
				set record ""
				foreach field $fieldslist val $row {
					lappend record $field $val
				}
				lappend recordslist $record
			}
		}
		llist {
			set recordslist $result
		}
		list {
			set recordslist [join $result]
		}
	}
	return $recordslist
}

package provide tdbo::mariadb 0.1.1
