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

package require tdbo

set dir [file dirname [info script]]
source [file join $dir "employee.tcl"]
source [file join $dir "address.tcl"]
source [file join $dir "saveemployee.tcl"]

# Setup logging facility
tdbo::FileLogger::open employee.log
set log [tdbo::FileLogger::init EmployeeApp debug]
puts "log: $log"

# Open SQLite Database connection
#set db [::tdbo::SQLite #auto]
#$db open [file join $dir "sqlite/employee.db"]

# Open PostgreSQL Database connection
set db [::tdbo::PostgreSQL #auto]
$db open employee -user nagu -password Welcome123

# Create Employee and Address instances 

Employee emp $db -name "Employee Name1" -rollno "INBNG0001"
${log}::debug "Employee before adding: [emp cget]"

Address addr $db \
	-addrline1 "Address Line 1" \
	-addrline2 "Address Line 2" \
	-city "City Name" \
	-country "Country Name" \
	-postalcode "560000"
${log}::debug "Address before adding: [emp cget]"

# Add Employee and Address objects to database using a transaction
if {![saveemployee $db add emp addr]} {
	${log}::error "Saving Employee failed... Please delete any pre-existing records from the table"
	$db close
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
