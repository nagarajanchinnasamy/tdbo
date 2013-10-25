# tdbc_mysql.tcl --
#
# tdbc mysql connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require tdbo::tdbc

itcl::class ::tdbo::tdbc::mysql {
	inherit ::tdbo::tdbc

	constructor {} {
		if {[namespace tail [info class]] == "mysql"} {
			return -code error "Error: Can't instantiate tdbc::mysql"
		}
	}

	public proc Load {} {
		chain
		package require tdbc::mysql
	}

	public proc open {dbname args} {
		set conn [chain]
		if {[catch {tdbc::mysql::connection create $conn -database $dbname {*}$args} err]} {
			return -code error $err
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

		if {[catch {_execute $conn $sqlscript stmt resultset} err]} {
			return -code error $err
		}
		
		set status [$resultset rowcount]
		$stmt close
		
		if {$sequence_fields == ""} {
			return $status
		}

		set sequence_values [dict create]
		if {[catch {$conn prepare "select last_insert_id\(\)"} stmt]} {
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

	public proc begin {conn {isolation ""}} {
		if {$isolation != ""} {
			set stmt [$conn prepare "set transaction isolation level $isolation"]
			if {[catch {$stmt execute} err]} {
				$stmt close
				return -code error $err
			}
			$stmt close
		}

		if {[catch {$conn begintransaction} err]} {
			return -code error $err
		}
	}

	public proc commit {conn} {
		chain $conn
	}

	public proc rollback {conn} {
		chain $conn
	}
}

package provide tdbo::tdbc::mysql 0.1.0
