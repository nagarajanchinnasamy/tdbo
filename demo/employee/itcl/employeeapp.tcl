# ----------------------------------------------------------------------
# Please see README file in this folder for details on how to use this
# demo application.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# ----------------------------------------------------------------------

lappend ::auto_path /usr/share/tcltk/tdbo0.1.4
lappend ::auto_path /usr/lib/tcltk/mysqltcl-3.051
lappend ::auto_path /usr/local/lib/pgtcl1.9

package require tdbo
namespace import tdbo::tdbo

package require tdbo::Itcl

set dir [file dirname [info script]]
source [file join $dir "employee.tcl"]
source [file join $dir "address.tcl"]
source [file normalize [file join $dir "../saveemployee.tcl"]]

# Setup logging facility
set log [::logger::init EmployeeApp]

# Open SQLite Database connection
set db [tdbo load sqlite3]
set conn [$db open [file normalize "../sqlite/employee.db"]]

# Open PostgreSQL Database connection
#set db [tdbo load Pgtcl]
#set conn [$db open employee -user nagu -password Welcome123]

# Open MariaDB/MySQL Database connection
#set db [tdbo load mysqltcl]
#set conn [$db open employee -user nagu -password Welcome123]

# Create Employee and Address instances 

Address addr $conn \
	-addrline1 "Address Line 1" \
	-addrline2 "Address Line 2" \
	-city "City Name" \
	-country "Country Name" \
	-postalcode "560000"
${log}::debug "Address before adding: [addr cget]"

Employee emp $conn -name "Employee Name1" -rollno "INBNG0001"
${log}::debug "Employee before adding: [emp cget]"

# Add Employee and Address objects to database using a transaction
if {![saveemployee $log $conn add emp addr]} {
	${log}::error "Saving Employee failed... Please delete any pre-existing records from the table"
	$conn close
	exit
}

${log}::debug "Employee after adding: [emp cget]"
${log}::debug "Address after adding: [addr cget]"

# Modify and save Address object.
addr configure \
	-addrline1 "Updated Address Line 1" \
	-addrline2 "Updated Address Line 2" \
	-city "Updated City Name" \
	-country "Updated Country Name" \
	-postalcode "Updated Postal Code"
addr save

# Check if the changes are reflected by retrieving it from database
addr clear
addr configure -id [emp cget -address_id]
addr get
${log}::debug "Modified address: [addr cget]"

# Delete the record
emp delete
${log}::debug "Employee After deleting: [emp cget]"
addr delete
${log}::debug "Address After deleting: [addr cget]"

# Close the db connection
$conn close
