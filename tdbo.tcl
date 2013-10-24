# tdbo.tcl --
#
# Tcl Database Object -- Layer
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require logger

namespace eval ::tdbo {
	variable version 0.1.4
	variable library [file dirname [info script]]
	source [file normalize ${library}/tdbo_impl.tcl]
}

package provide tdbo $::tdbo::version
