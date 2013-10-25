# tdbc_postgres.tcl --
#
# tdbc postgres connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require tdbo::tdbc

itcl::class ::tdbo::tdbc::postgres {
	inherit ::tdbo::tdbc

	constructor {} {
		if {[namespace tail [info class]] == "postgres"} {
			return -code error "Error: Can't instantiate tdbc::postgres"
		}
	}

	public proc Load {} {
		chain
		package require tdbc::postgres
	}

	public proc open {dbname args} {
		set conn [chain]
		if {[catch {tdbc::postgres::connection create $conn -database $dbname {*}$args} err]} {
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
		set sqlscript [_prepare_insert_stmt $conn $schema_name $namevaluepairs $sequence_fields]

		if {[catch {_execute $conn $sqlscript stmt resultset} err]} {
			return -code error $err
		}

		set status [$resultset rowcount]
	
		if {$sequence_fields == ""} {
			$stmt close
			return $status
		}

		$resultset nextdict sequence_values
		
		return [list $status $sequence_values]
	}

	public proc update {conn schema_name namevaluepairs {conditionlist ""}} {
		return [chain $conn $schema_name $namevaluepairs $conditionlist]
	}

	public proc delete {conn schema_name {conditionlist ""}} {
		return [chain $conn $schema_name $conditionlist]
	}

	public proc begin {conn {lock deferrable}} {
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

	protected proc _prepare_insert_stmt {conn schema_name namevaluepairs {sequencefields ""}} {
		set fnames [dict keys $namevaluepairs]

		dict for {fname val} $namevaluepairs {
			set nsname [_nsvar $conn $fname]
			set $nsname $val
			lappend valuelist ":$fname"
		}

		set stmt "INSERT INTO $schema_name ([join $fnames ", "]) VALUES ([join $valuelist ", "])"
		if {$sequencefields != ""} {
			set sequencefields [join $sequencefields ", "]
			append stmt " RETURNING $sequencefields"
		}

		$log($conn)::debug $stmt
		return $stmt
	}
}

package provide tdbo::tdbc::postgres 0.1.0
