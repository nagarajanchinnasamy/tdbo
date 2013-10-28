# ---------------------------------------------------------------------
# Step 0: Setup a database named employee using the employee_schema.sql
#         found in the respective sub-folder. Create necessary user
#         account and previleges.
# ---------------------------------------------------------------------

lappend ::auto_path /usr/share/tcltk/tdbo0.1.4
lappend ::auto_path /usr/lib/tcltk/mysqltcl-3.051
lappend ::auto_path /usr/local/lib/pgtcl1.9

# ---------------------------------------------------------------------
# Step 1: Load tdbo and tdbo::record packages
# ---------------------------------------------------------------------

package require tdbo
namespace import tdbo::tdbo

package require tdbo::record
namespace import tdbo::record::record

# Setup logging facility
set log [::logger::init EmployeeApp]

# ---------------------------------------------------------------------
# Step 2: Load Database connectivity module and open a connection.
#         Un/Comment lines below as necessary
# ---------------------------------------------------------------------
#set db [tdbo load tdbc::sqlite3]
#set conn [$db open [file normalize "../sqlite/employee.db"]]
#set db [tdbo load Pgtcl]
#set conn [$db open employee -user nagu -password Welcome123]
set db [tdbo load mysqltcl]
set conn [$db open employee -user nagu -password Welcome123]

# ---------------------------------------------------------------------
# Step 3: Define tdbo Objects and Transactions
# ---------------------------------------------------------------------

set dir [file dirname [info script]]
source [file join $dir "employee.tcl"]
source [file join $dir "address.tcl"]
source [file normalize [file join $dir "../saveemployee.tcl"]]

# ---------------------------------------------------------------------
# Step 4: Instantiate address & employee
# ---------------------------------------------------------------------
Employee emp $conn -name "Employee Name1" -rollno "INBNG0001"
${log}::debug "Employee before adding: [emp cget]"

Address addr $conn \
	-addrline1 "Address Line 1" \
	-addrline2 "Address Line 2"
${log}::debug "Address before adding: [addr cget]"

# ---------------------------------------------------------------------
# Step 5: Add/Modify employee & address
# ---------------------------------------------------------------------
if {[catch {saveemployee $log $conn add emp addr} err]} {
	${log}::debug "Saving employee failed...\nError: $err"
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
${log}::debug "Reset address: [addr cget]"
addr configure -id [emp cget -address_id]
addr get
${log}::debug "Modified address: [addr cget]"

# Delete the record
emp delete
${log}::debug "Employee After deleting: [emp cget]"
addr delete
${log}::debug "Address After deleting: [addr cget]"

# ---------------------------------------------------------------------
# Step 6: Clean up and close the database connection
# ---------------------------------------------------------------------
record delete inst addr emp
record delete def Address Employee

$conn close
