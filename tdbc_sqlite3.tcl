# tdbc_sqlite.tcl --
#
# tdbc sqlite3 connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require tdbo::tdbc

itcl::class ::tdbo::tdbc::sqlite3 {
	inherit ::tdbo::tdbc

	constructor {} {
		if {[namespace tail [info class]] == "sqlite"} {
			return -code error "Error: Can't instantiate tdbc::sqlite3"
		}
	}

	public proc Load {} {
		chain
		package require tdbc::sqlite3
	}

	public proc open {location {initscript ""}} {
		set conn [chain]
		if {[catch {tdbc::sqlite3::connection create $conn $location} err]} {
			return -code error $err
		}

		if {$initscript != ""} {
			if {[catch {$conn prepare $initscript} stmt]} {
				return -code error $stmt
			}
			if {[catch {$stmt execute} resultset]} {
				$stmt close
				return -code error $resultset
			}
			$stmt close
		}

		return $conn
	}

	public proc close {conn} {
		chain $conn
	}

	public proc get {conn schema_name fieldslist conditionlist {format "dict"}} {
		return [chain $conn $schema_name $fieldslist $conditionlist $format]
	}

	public proc mget {conn schema_name args} {
		return [chain $conn $schema_name {*}$args]
	}

	public proc insert {conn schema_name namevaluepairs {sequence_fields ""}} {
		set sqlscript [_prepare_insert_stmt $conn $schema_name $namevaluepairs]

		if {[catch {$conn prepare $sqlscript} stmt]} {
			return -code error $stmt
		}
		if {[catch {$stmt execute} resultset]} {
			$stmt close
			return -code error $resultset
		}
		
		set status [$resultset rowcount]
		$stmt close
		
		if {$sequence_fields == ""} {
			return $status
		}

		set sequence_values [dict create]
		if {[catch {$conn prepare "select last_insert_rowid\(\)"} stmt]} {
			return -code error $stmt
		}
		if {[catch {$stmt execute} resultset]} {
			$stmt close
			return -code error $resultset
		}
		$resultset nextlist rowid
		$stmt close

		foreach fname $sequence_fields {
			dict set sequence_values $fname $rowid
		}

		return [list $status $sequence_values]
	}

	public proc update {conn schema_name namevaluepairs {conditionlist ""}} {
		return [chain $conn $schema_name $namevaluepairs $conditionlist]
	}

	public proc delete {conn schema_name {conditionlist ""}} {
		return [chain $conn $schema_name $conditionlist]
	}

	public proc begin {conn {lock deferred}} {
		set stmt [$conn prepare "begin $lock"]
		if {[catch {$stmt execute} err]} {
			$stmt close
			return -code error $err
		}
		$stmt close
	}

	public proc commit {conn} {
		chain $conn
	}

	public proc rollback {conn} {
		chain $conn
	}

}

package provide tdbo::tdbc::sqlite3 0.1.0
