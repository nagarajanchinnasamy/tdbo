package require tdbc
package require tdbc::postgres
package require tdbc::mysql
package require tdbc::sqlite3

namespace eval ns {}
set conn [tdbc::postgres::connection create myconn -database employee -user nagu -password Welcome123]
#set conn [tdbc::mysql::connection create myconn -database employee -user nagu -password Welcome123]
#set conn [tdbc::sqlite3::connection create myconn sqlite/employee.db]
set stmt [$conn prepare "insert into address(addrline1, addrline2, city, postalcode, country) values (:::ns::addrline1, :::ns::addrline2, :::ns::city, :::ns::postalcode, :::ns::country)"]

set ::ns::addrline1 "Address Line1"
set ::ns::addrline2 "Address Line2"
set ::ns::city "City 1"
set ::ns::postalcode "98989888"
set ::ns::country "India"

set resultset [$stmt execute]

puts [$resultset rowcount]

$stmt close
$conn close 
