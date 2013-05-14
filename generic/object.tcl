# object.tcl --
#
# Provides few enhancements over Itcl's object interface through enhanced
# configure and cget methods.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class Object
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::Object {

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
constructor {} {
	set clsName [$this info class]
	set log [tdbo::FileLogger::init $clsName debug]
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
destructor {
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method configure {{option ""} args} {
	# Usage: objName configure
	# return value: -opt {-ival val -cval val} -opt {-ival val -cval val} ...
	if {![string length $option]} {
		set result [dict create]
		foreach optcfg [_itcl_configure] {
			lassign $optcfg optname ival cval
			dict set result $optname [list -ival $ival -cval $cval]
		}
		return $result
	}

	# Usage: objName configure objName1
	# Usage (Copy constructor): className objName objName1
	# return value: ""
	if {![llength $args]} {
		if {[catch {uplevel $option isa [$this info class]} err]} {
			_itcl_configure $option {*}$args
			return
		}
		_itcl_configure {*}[uplevel $option cget]
		return
	}
	
	# Usage: objName configure -opt val -opt val ...
	# return value: ""
	_itcl_configure $option {*}$args
	return
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method cget {{option ""} args} {
	# Usage: objName cget
	# return value: -opt val -opt val ...
	if ![string length $option] {
		set config [configure]
		set result [dict create]
		foreach opt [dict keys $config] {
			dict set result $opt [dict get $config $opt -cval]
		}

		return $result
	}

	set config [configure]

	# Usage: objName cget -opt
	# return value: val
	if ![llength $args] {
		return [dict get $config $option -cval]
	}

	# Usage: objName cget -opt vName -opt vName ...
	# return value: ""
	# return value: values for opt is stored in corresponding vName
	set args [linsert $args 0 $option]
	foreach {opt vname} $args {
		upvar $vname var
		set var [dict get $config $opt -cval]
	}
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method clear {args} {
	set config [configure]
	foreach opt [dict keys $config] {
		configure $opt [dict get $config $opt -ival]
	}
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected variable clsName
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected variable log
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method _itcl_configure {{option ""} args} @itcl-builtin-configure
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method _itcl_cget {{option ""} args} @itcl-builtin-cget

# ----------------------------------END---------------------------------
}
