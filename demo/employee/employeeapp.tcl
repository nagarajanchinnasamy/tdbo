package require logger
package require sqlite3
package require Itcl
package require tdbo

set dir [file dirname [info script]]
source [file join $dir "employee.tcl"]
source [file join $dir "address.tcl"]
source [file join $dir "saveemployee.tcl"]

tdbo::FileLogger::open /tmp/test1.log

set db [::tdbo::SQLite #auto -location /tmp/test.db]
$db open

Employee emp $db -name "Employee Name1" -rollno "INBNG0001"

Address addr $db \
	-addrline1 "Address Line 1" \
	-addrline2 "Address Line 2" \
	-city "City Name" \
	-country "Country Name" \
	-postalcode "560000"

saveemployee $db add emp addr

addr clear
emp clear

emp configure -rollno "INBNG0001"
puts [emp get]

addr configure -id [emp cget -address_id]
puts [addr get]
