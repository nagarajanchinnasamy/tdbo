package require Tcl 8.5
package require logger
package require Itcl 3.4

namespace eval ::tdbo {
	namespace export *

	variable version 0.1.3
	variable library [file dirname [info script]]
}

package provide tdbo $tdbo::version
