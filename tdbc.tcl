# tdbc.tcl --
#
# tdbc connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require logger
package require Itcl

itcl::class ::tdbo::tdbc {

	constructor {} {
		if {[namespace tail [info class]] == "tdbc"} {
			return -code error "Error: Can't instantiate tdbc - abstract class."
		}
	}

	protected common count 0
	protected common ns
	array set ns {}
	protected common log
	array set log {}

	protected proc Load {} {
		package require tdbc
	}

	protected proc open {} {
		incr count
		set conn [format "%s%s%s" [namespace current] "_conn" $count]

		set _ns [format "%s%s%s" [namespace current] "::ns" $count]
		set ns($conn) ${_ns}
		namespace eval ${_ns} {}

		set log($conn) [logger::init ${_ns}]
		return $conn
	}

	protected proc close {conn} {
		catch {$conn close}
		catch {namespace delete $ns($conn)}
		array unset ns $conn
		array unset log $conn
	}

	protected proc get {conn schema_name fieldslist conditionlist {format "dict"}} {
		return [
			_select \
				$conn \
				$schema_name \
				-fields $fieldslist \
				-format $format \
				-condition [_prepare_condition $conn $conditionlist] \
		]
	}

	protected proc mget {conn schema_name args} {
		return [_select $conn $schema_name {*}$args]
	}

	protected proc insert {conn schema_name namevaluepairs {sequence_fields ""}}

	protected proc update {conn schema_name namevaluepairs {conditionlist ""}} {
		set sqlscript [_prepare_update_stmt $conn $schema_name $namevaluepairs $conditionlist]
		if {[catch {_execute $conn $sqlscript stmt resultset} err]} {
			return -code error $err
		}
		
		set status [$resultset rowcount]
		$stmt close

		return $status
	}

	protected proc delete {conn schema_name {conditionlist ""}} {
		set sqlscript [_prepare_delete_stmt $conn $schema_name $conditionlist]
		if {[catch {_execute $conn $sqlscript stmt resultset} err]} {
			return -code error $err
		}
		
		set status [$resultset rowcount]
		$stmt close

		return $status
	}

	protected proc begin {conn args}

	protected proc commit {conn} {
		$conn commit
	}

	protected proc rollback {conn} {
		$conn rollback
	}

	# ----------------------------------------------------------------------
	# method  : 
	# args    : 
	# 
	# returns :
	#
	# ----------------------------------------------------------------------
	protected proc _execute {conn sqlscript stmtvarname resultsetvarname} {
		variable ns
		upvar $stmtvarname stmt
		upvar $resultsetvarname resultset

		if {[catch {$conn prepare $sqlscript} stmt]} {
			return -code error $stmt
		}
		if {[catch {namespace eval $ns($conn) [list $stmt execute]} resultset]} {
			$stmt close
			return -code error $resultset
		}
	}
	# ----------------------------------------------------------------------
	# method  : 
	# args    : 
	# 
	# returns :
	#
	# ----------------------------------------------------------------------
	protected proc _nsvar {conn varname} {
		variable ns
		return [format "%s%s%s" $ns($conn) "::" $varname]
	}

	# ----------------------------------------------------------------------
	#
	#
	#
	#
	# ----------------------------------------------------------------------
	protected proc _prepare_condition {conn conditionlist} {
		set sqlcondition [list]
		foreach condition $conditionlist {
			set complist [list]
			foreach {fname val} $condition {
				if {$val == "IS NULL"} {
					lappend complist "$fname IS NULL"
				} else {
					set nsname [_nsvar $conn $fname]
					set $nsname $val
					lappend complist "$fname=:$fname"
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
	protected proc _prepare_insert_stmt {conn schema_name namevaluepairs} {
		set fnames [dict keys $namevaluepairs]

		dict for {fname val} $namevaluepairs {
			set nsname [_nsvar $conn $fname]
			set $nsname $val
			lappend valuelist ":$fname"
		}

		set stmt "INSERT INTO $schema_name ([join $fnames ", "]) VALUES ([join $valuelist ", "])"
		$log($conn)::debug $stmt
		return $stmt
	}

	# ----------------------------------------------------------------------
	# method  : 
	# args    : 
	# 
	# returns :
	#
	# ----------------------------------------------------------------------
	protected proc _prepare_update_stmt {conn schema_name namevaluepairs {conditionlist ""}} {

		dict for {fname val} $namevaluepairs {
			set nsname [_nsvar $conn $fname] 
			set $nsname $val
			lappend setlist "$fname=:$fname"
		}

		set setlist [join $setlist ", "]

		set stmt "UPDATE $schema_name SET $setlist"
		if [llength $conditionlist] {
			append stmt " WHERE [_prepare_condition $conn $conditionlist]"
		}

		$log($conn)::debug $stmt
		return $stmt
	}


	# ----------------------------------------------------------------------
	# method  : 
	# args    : 
	# 
	# returns :
	#
	# ----------------------------------------------------------------------
	protected proc _prepare_delete_stmt {conn schema_name {conditionlist ""}} {

		set stmt "DELETE FROM $schema_name"
		if {[llength $conditionlist]} {
			append stmt " WHERE [_prepare_condition $conn $conditionlist]"
		}

		$log($conn)::debug $stmt
		return $stmt
	}

	# ----------------------------------------------------------------------
	# method  : 
	# args    : 
	# 
	# returns :
	#
	# ----------------------------------------------------------------------
	protected proc _prepare_select_stmt {conn schema_name args} {
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

		$log($conn)::debug $stmt
		return $stmt
	}

	# ----------------------------------------------------------------------
	#
	# format: one of "dict", "llist", "list" 
	#
	# ----------------------------------------------------------------------
	protected proc _select {conn schema_name args} {
		set format "dict"
		if {[dict exists $args -format]} {
			set format [dict get $args -format]
			dict unset args -format
		}

		set sqlscript [_prepare_select_stmt $conn $schema_name {*}$args]
		if {[catch {_execute $conn $sqlscript stmt resultset} err]} {
			return -code error $err
		}

		set recordslist ""
		switch -- $format {
			dict {
				$resultset foreach -as dicts record {
					set reccfg [dict create]
					dict for {f v} $record {
						dict set reccfg "-$f" "$v"
					}
					lappend recordslist $reccfg
				}
			}
			llist {
				set recordslist [$resultset allrows -as lists]
			}
			list {
				$resultset foreach -as lists record { 
					lappend recordslist {*}$record
				}  
			}
		}

		return $recordslist
	}

}

package provide tdbo::tdbc 0.1.0
