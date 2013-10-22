# dbc.tcl --
#
# Database Connectivity module
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::tdbo {}

namespace eval ::tdbo::dbc {
	variable commands
	set commands [list load]

	variable driver_commands
	set driver_commands [list open]

	variable conn_commands
	set conn_commands [list insert get mget update delete begin commit rollback close]

	variable drivers
	set drivers [dict create]

	variable connections
	set connections [dict create -count 0]

	namespace export dbc
}

proc ::tdbo::dbc::dbc {cmd args} {
    variable commands

	if {[lsearch $commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $commands ,]"
	}

    set cmd [string totitle "$cmd"]
    return [uplevel 1 ::tdbo::dbc::${cmd} $args]
}

proc ::tdbo::dbc::Load {driver {version ""}} {
	variable drivers

	if {[dict exists $drivers $driver]} {
		return [dict get $dbms $driver -cmd]
	}

	if {[catch {package require tdbo::dbc::${driver} {*}$version} err]} {
		return -code error "Unable to load dbc driver $driver.\nError: $err"
	}
	
	if {[catch {[namespace current]::${driver}::Load} err]} {
		return -code error "Unable to load dbc driver $driver.\nError: $err"
	}

	set driver_cmd [format "%s%s%s" [namespace current] "___" $driver]
    uplevel #0 [list interp alias {} $driver_cmd {} [namespace current]::DriverCmd $driver]

	dict set drivers $driver -cmd $driver_cmd 

    return $driver_cmd
}

proc ::tdbo::dbc::DriverCmd {driver cmd args} {
	variable driver_commands

	if {[lsearch $driver_commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $driver_commands ,]"
	}

	return [uplevel 1 [namespace current]::${cmd} $driver $args]
}

proc ::tdbo::dbc::open {driver args} {
	variable drivers
	variable connections

	if {![dict exists $drivers $driver]} {
		return -code error "DBC driver $driver not loaded"
	}


	dict incr connections -count
	set conn_cmd [format "%s%s" "::tdbo::dbc::conncmd" [dict get $connections -count]]


	if {[catch {uplevel 1 [namespace current]::${driver}::open $args} result]} {
		return -code error $result
	}
	set conn $result

    uplevel #0 [list interp alias {} $conn_cmd {} [namespace current]::ConnCmd $conn_cmd]

    dict set connections $conn_cmd -driver $driver
    dict set connections $conn_cmd -conn $conn

    return $conn_cmd
}

proc ::tdbo::dbc::ConnCmd {conn_cmd cmd args} {
	variable connections
	variable conn_commands

	if {![dict exists $connections $conn_cmd]} {
		return -code error "Connection $conn_cmd does not exist"
	}

	if {[lsearch $conn_commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $conn_commands ,]"
	}

	set driver [dict get $connections $conn_cmd -driver]
	set conn [dict get $connections $conn_cmd -conn]

	if {$cmd == "close"} {
		return [uplevel 1 [namespace current]::${cmd} $conn_cmd $driver $conn $args]
	}

	return [uplevel 1 [namespace current]::${cmd} $driver $conn $args]	
}

proc ::tdbo::dbc::close {conn_cmd driver conn} {
	variable connections

	if {[catch {uplevel 1 [namespace current]::${driver}::close $conn} err]} {
		return -code error $err
	}

	if {[dict exists $connections $conn_cmd]} {
		dict unset connections $conn_cmd
	}
}

proc ::tdbo::dbc::get {driver conn schema_name fieldslist conditionlist {format "dict"}} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::get $conn $schema_name $fieldslist $conditionlist $format]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::dbc::mget {driver conn schema_name args} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::mget $conn $schema_name $args]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::dbc::insert {driver conn schema_name namevaluepairs {sequence_fields ""}} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::insert $conn $schema_name $namevaluepairs $sequence_fields]} result]} {
		return -code error $result
	}

	return $result		
}

proc ::tdbo::dbc::update {driver conn schema_name namevaluepairs {conditionlist ""}} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::update $conn $schema_name $namevaluepairs $conditionlist]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::dbc::delete {driver conn schema_name {conditionlist ""}} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::delete $conn $schema_name $conditionlist]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::dbc::begin {driver conn args} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::begin $conn {*}$args]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::dbc::commit {driver conn args} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::commit $conn {*}$args]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::dbc::rollback {driver conn args} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::rollback $conn {*}$args]} result]} {
		return -code error $result
	}

	return $result
}

namespace eval ::tdbo {
    # Get 'dbc::dbc' into the general structure namespace.
    namespace import -force dbc::dbc
    namespace export dbc
}

package provide tdbo::dbc 0.1.2
