# sqlite.tcl --
#
# sqlite3 connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require logger

namespace eval ::tdbo::dbc::sqlite {
	variable log [::logger::init [namespace current]]
	variable count 0
	variable use_tdbc 0
	variable ns
	array set ns {}
}

proc ::tdbo::dbc::sqlite::Load {{_use_tdbc 0}} {
	variable use_tdbc

	switch -- $_use_tdbc {
		yes - 1 - true - on {
		}
		no - 0 - false - off {
			package require sqlite3
		}
	}
}

proc ::tdbo::dbc::sqlite::open {location {initscript ""}} {
	variable count
	variable use_tdbc
	variable ns
	
	incr count
	set conn [format "%s%s%s" [namespace current] "___conn" $count]

	switch -- $use_tdbc {
		yes - 1 - true - on {
		}
		no - 0 - false - off {
			if {[catch {sqlite3 $conn $location} err]} {
				return -code error $err
			}
			if {$initscript != ""} {
				uplevel 1 $conn eval $initscript
			}
		}
	}

	set _ns [format "%s%s%s" [namespace current] "::___ns" $count]
	set ns($conn) ${_ns}
	namespace eval ${_ns} {}

	return $conn
}

proc ::tdbo::dbc::sqlite::close {conn} {
	variable use_tdbc
	variable ns

	switch -- $use_tdbc {
		yes - 1 - true - on {
		}
		no - 0 - false - off {
			catch {$conn close}
			catch {namespace delete $ns($conn)}
			array unset ns $conn
		}
	}
}

proc ::tdbo::dbc::sqlite::get {conn schema_name fieldslist conditionlist {format "dict"}} {
	return [
		_select \
			$conn \
			$schema_name \
			-fields $fieldslist \
			-format $format \
			-condition [_prepare_condition $conn $conditionlist] \
	]
}

proc ::tdbo::dbc::sqlite::mget {conn schema_name args} {
	return [_select $conn $schema_name {*}$args]
}

proc ::tdbo::dbc::sqlite::insert {conn schema_name namevaluepairs {sequence_fields ""}} {
	set sqlscript [_prepare_insert_stmt $conn $schema_name $namevaluepairs]
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

proc ::tdbo::dbc::sqlite::update {conn schema_name namevaluepairs {conditionlist ""}} {
	set sqlscript [_prepare_update_stmt $conn $schema_name $namevaluepairs $conditionlist]
	if {[catch {$conn eval $sqlscript} err]} {
		return -code error $err
	}

	return [$conn changes]
}

proc ::tdbo::dbc::sqlite::delete {conn schema_name {conditionlist ""}} {
	set sqlscript [_prepare_delete_stmt $conn $schema_name $conditionlist]
	if {[catch {$conn eval $sqlscript} err]} {
		return -code error $err
	}

	return [$conn changes]
}

proc ::tdbo::dbc::sqlite::begin {conn {lock deferred}} {
	$conn eval begin $lock
}

proc ::tdbo::dbc::sqlite::commit {conn} {
	$conn eval commit
}

proc ::tdbo::dbc::sqlite::rollback {conn} {
	$conn eval rollback
}

# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
proc ::tdbo::dbc::sqlite::_nsvar {conn varname} {
	variable ns
	return [format "%s%s%s" $ns($conn) "::" $varname]
}

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
proc ::tdbo::dbc::sqlite::_prepare_condition {conn conditionlist} {
	set sqlcondition [list]
	foreach condition $conditionlist {
		set complist [list]
		foreach {fname val} $condition {
			if {$val == "IS NULL"} {
				lappend complist "$fname IS NULL"
			} else {
				set nsname [_nsvar $conn $fname]
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
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
proc ::tdbo::dbc::sqlite::_prepare_insert_stmt {conn schema_name namevaluepairs} {
	variable log

	set fnames [dict keys $namevaluepairs]

	dict for {fname val} $namevaluepairs {
		set nsname [_nsvar $conn $fname]
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
proc ::tdbo::dbc::sqlite::_prepare_update_stmt {conn schema_name namevaluepairs {conditionlist ""}} {
	variable log

	dict for {fname val} $namevaluepairs {
		set nsname [_nsvar $conn $fname] 
		set $nsname $val
		lappend setlist "$fname=:$nsname"
	}

	set setlist [join $setlist ", "]

	set stmt "UPDATE $schema_name SET $setlist"
	if [llength $conditionlist] {
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
proc ::tdbo::dbc::sqlite::_prepare_delete_stmt {conn schema_name {conditionlist ""}} {
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
proc ::tdbo::dbc::sqlite::_prepare_select_stmt {schema_name args} {
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
proc ::tdbo::dbc::sqlite::_select {conn schema_name args} {
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

package provide tdbo::dbc::sqlite 0.1.1
