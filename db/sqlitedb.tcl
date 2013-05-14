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
constructor {args} {
	configure {*}$args
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
# variable conn:
#
#
#
# ----------------------------------------------------------------------
public variable conn
# ----------------------------------------------------------------------
# variable location:
#
#
#
# ----------------------------------------------------------------------
public variable location {} {
	if {[info exists conn] && $conn != ""} {
		return -code error "Cannot set location when conn is non-empty"
	}
}
# ----------------------------------------------------------------------
# variable initscript:
#
#
#
# ----------------------------------------------------------------------
public variable initscript "" {
	if {$conn != ""} {
		return -code error "Cannot set initscript when conn is non-empty"
	}
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method open {args} {
	configure {*}$args
	if {[info exists conn] && $conn != ""} {
		return -code error "Cannot invoke open when conn is non-empty"
	}
	if {$location == ""} {
		return -code error "Cannot invoke open without setting location"
	}

	incr conncount
	set conn sqlite_$conncount
	uplevel #0 sqlite3 $conn $location

	if {$initscript != ""} {
		$conn eval $initscript
	}
	return $conn
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method close {} {
	if {$conn != ""} {
		catch {$conn close}
		set conn ""
	}
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method get {schema_name condition} {
	return [lindex [_select $schema_name -condition $condition] 0]
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method mget {schema_name args} {
	return [_select $schema_name {*}$args]
}
# ----------------------------------------------------------------------
#
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
#
#
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}} {
	return [_update $schema_name $namevaluepairs $condition]	
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method delete {schema_name {condition ""}} {
	return [_delete $schema_name $condition]
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method begin {{lock deferred}} {
	$conn eval begin $lock
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method commit {} {
	$conn eval commit
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method rollback {} {
	$conn eval rollback
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _select {table_name args} {
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
		append sqlscript " WHERE [_prepare_condition $condition]"
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
protected method _insert {table_name namevaluepairs} {
	set fnamelist [join [dict keys $namevaluepairs] ", "]
	set valuelist [list]
	foreach value [dict values $namevaluepairs] {
		lappend valuelist '$value'
	} 
	set valuelist [join $valuelist ", "]

	set sqlscript "INSERT INTO $table_name ($fnamelist) VALUES ($valuelist)"
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
protected method _last_insert_rowid {} {
	return [$conn last_insert_rowid]
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _update {table_name namevaluepairs {update_condition ""}} {
	set setlist ""
	foreach {name val} $namevaluepairs {
		lappend setlist "$name='$val'"
	}
	set setlist [join $setlist ", "]

	set sqlscript "UPDATE $table_name SET $setlist"
	if [string length $update_condition] {
		append sqlscript " WHERE [_prepare_condition $update_condition]"
	}

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
protected method _delete {table_name {delete_condition ""}} {
	set sqlscript "DELETE FROM $table_name"
	if [string length $delete_condition] {
		append sqlscript " WHERE [_prepare_condition $delete_condition]"
	}

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
protected proc _prepare_condition {conditionlist} {
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
