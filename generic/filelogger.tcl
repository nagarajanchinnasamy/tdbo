# filelogger.tcl --
#
# Logger interface to log messages to a file. See tcllib's logger package.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::FileLogger {

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public proc open {location} {
	set access [list WRONLY CREAT APPEND]
	set perm 0600

	if { [catch { set logchan [::open $location $access $perm] } logerr] } {
		unset logchan
		return -code error "Unable to open $location.\n$logerr"
	}
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public proc init {service {level warn} {slaveinterp ""}} {
	if {[catch {::logger::servicecmd $service} log]} {
		set log [uplevel ::logger::init $service]
	}
	${log}::setlevel $level
	interp alias {} ${log}_log_to_file {} [itcl::code _log_to_file] $log
	foreach lvl [logger::levels] {
		${log}::logproc $lvl ${log}_log_to_file
		if {$slaveinterp != ""} {
			$slaveinterp alias ${log}::${lvl} ${log}::${lvl}
		}
	}

	interp alias {} ${log}_trace_to_file {} [itcl::code _trace_to_file] $log
	${log}::logproc trace ${log}_trace_to_file

	return $log
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected proc _log_to_file {log txt} {
	::puts $logchan "\[[clock format [clock seconds] -format {%H:%M:%S}]\] \[[${log}::servicename]\] \[[${log}::currentloglevel]\] $txt"
	flush $logchan
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected proc _trace_to_file {log dict} {
	::puts $logchan "\[[clock format [clock seconds] -format {%H:%M:%S}]\] \[[${log}::servicename]\] $dict"
	flush $logchan
}

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected common logchan

# ----------------------------------END---------------------------------
}

