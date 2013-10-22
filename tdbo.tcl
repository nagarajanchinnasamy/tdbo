package require logger

package require tdbo::dbc      0.1.2

namespace eval ::tdbo {
	namespace export *

	variable version 0.1.4
	variable library [file dirname [info script]]
}

package provide tdbo $::tdbo::version
