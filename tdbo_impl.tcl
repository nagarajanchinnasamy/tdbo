# tdbo_impl.tcl --
#
# TDBO - Central Controller Implementation
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::tdbo {

	variable commands
	set commands [list load]

	variable driver_commands
	set driver_commands [list open]

	variable drivers
	set drivers [dict create]
}

proc ::tdbo::tdbo {cmd args} {
    variable commands

	if {[lsearch $commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $commands ,]"
	}

    set cmd [string totitle "$cmd"]
    return [uplevel 1 ::tdbo::${cmd} $args]
}

proc ::tdbo::Load {driver {version ""}} {
	variable drivers

	if {[dict exists $drivers $driver]} {
		return [dict get $dbms $driver -cmd]
	}

	if {[catch {package require tdbo::${driver} {*}$version} err]} {
		return -code error "Unable to load tdbo driver $driver.\nError: $err"
	}
	
	if {[catch {::tdbo::${driver}::Load} err]} {
		return -code error "Unable to load tdbo driver $driver.\nError: $err"
	}

	set driver_cmd [format "%s%s%s" [namespace current] "_" $driver]
    uplevel #0 [list interp alias {} $driver_cmd {} [namespace current]::DriverCmd $driver]

	dict set drivers $driver -cmd $driver_cmd 

    return $driver_cmd
}

proc ::tdbo::DriverCmd {driver cmd args} {
	variable drivers
	variable driver_commands

	if {![dict exists $drivers $driver]} {
		return -code error "tdbo driver $driver not loaded"
	}

	if {[lsearch $driver_commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $driver_commands ,]"
	}

	return [uplevel 1 [namespace current]::driver::${cmd} $driver $args]
}

namespace eval ::tdbo::driver {
	variable connections
	set connections [dict create -count 0]

	variable connection_commands
	set connection_commands [list insert get mget update delete begin commit rollback close]
}

proc ::tdbo::driver::open {driver args} {
	variable connections

	if {[catch {uplevel 1 ::tdbo::${driver}::open $args} result]} {
		return -code error $result
	}
	set conn $result

	dict incr connections -count
	set conn_cmd [format "%s%s%s" [namespace current] "::conncmd" [dict get $connections -count]]

    uplevel #0 [list interp alias {} $conn_cmd {} [namespace current]::ConnCmd $conn_cmd]

    dict set connections $conn_cmd -driver $driver
    dict set connections $conn_cmd -conn $conn

    return $conn_cmd
}

proc ::tdbo::driver::ConnCmd {conn_cmd cmd args} {
	variable connections
	variable connection_commands

	if {![dict exists $connections $conn_cmd]} {
		return -code error "Connection $conn_cmd does not exist"
	}

	if {[lsearch $connection_commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $conn_commands ,]"
	}

	set driver [dict get $connections $conn_cmd -driver]
	set conn [dict get $connections $conn_cmd -conn]

	if {$cmd == "close"} {
		return [uplevel 1 [namespace current]::${cmd} $conn_cmd $driver $conn $args]
	}

	return [uplevel 1 tdbo::${driver}::${cmd} $conn $args]
}

proc ::tdbo::driver::close {conn_cmd driver conn} {
	variable connections

	if {[catch {uplevel 1 ::tdbo::${driver}::close $conn} err]} {
		return -code error $err
	}

	if {[dict exists $connections $conn_cmd]} {
		dict unset connections $conn_cmd
	}
}

namespace eval ::tdbo {
    namespace export tdbo
}
