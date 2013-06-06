package require Tcl 8.5
package require logger
package require Itcl 3.4

namespace eval ::tdbo {
	namespace export *

	variable version 0.1.1
	variable library [file dirname [info script]]
}

lappend auto_path $tdbo::library \
	[file join $tdbo::library generic] \
	[file join $tdbo::library db]
package provide tdbo $tdbo::version
