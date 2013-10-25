package require tdbc
package require tdbc::postgres
package require tdbc::mysql
package require tdbc::sqlite3

proc _execute {conn ns sqlscript stmtvarname resultsetvarname} {
	upvar $stmtvarname stmt
	upvar $resultsetvarname resultset

	if {[catch {$conn prepare $sqlscript} stmt]} {
		return -code error $stmt
	}
	if {[catch {namespace eval $ns [list $stmt execute]} resultset]} {
		$stmt close
		return -code error $resultset
	}
}

namespace eval ns {}
set conn [tdbc::postgres::connection create myconn -database employee -user nagu -password Welcome123]
#set conn [tdbc::mysql::connection create myconn -database employee -user nagu -password Welcome123]
#set conn [tdbc::sqlite3::connection create myconn sqlite/employee.db]
set ns::addrline1 "Address Line1"
set ns::addrline2 "Address Line2"
set ns::city "City 1"
set ns::postalcode "98989888"
set ns::country "India"
_execute $conn ::ns {insert into address(addrline1, addrline2, city, postalcode, country) values (:addrline1, :addrline2, :city, :postalcode, :country) returning id} stmt result
puts [$result rowcount]
$stmt close


set ns::name "test2"
set ns::address_id 14
set ns::rollno "test2"
_execute $conn ::ns {INSERT INTO employee(name, address_id, rollno) VALUES (:name, :address_id, :rollno) RETURNING id} stmt result
puts [$resultset rowcount]
$stmt close
$conn close 
