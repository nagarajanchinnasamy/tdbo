# database.tcl --
#
# Generic Database interface that needs to be implemented by
# database-specific modules (eg., sqlite, mysql, oracle etc.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class Database
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::Database {
	inherit tdbo::Object
# ----------------------------------------------------------------------
# constructor:
#
#
#
# ----------------------------------------------------------------------
constructor {} {
	if {[namespace tail [info class]] == "Database"} {
		return -code error "Error: Can't create Database objects - abstract class."
	}
}
# ----------------------------------------------------------------------
# destructor
#
#
#
# ----------------------------------------------------------------------
destructor {
}
# ----------------------------------------------------------------------
# method  : open - First method to be invoked on a Database object to
#           establish connection.
# args    : variable no. of arguments, defined by the underlying
#           database implementation such as SQLite.
# returns : connection object command that will be used to invoke data
#           access commands such as get, add, save and delete.
# ----------------------------------------------------------------------
public method open {args}


# ----------------------------------------------------------------------
# method  : close - To close the database connection.
# args    : none
# returns : none
#
# ----------------------------------------------------------------------
public method close {}


# ----------------------------------------------------------------------
# method  : get - Retrieve a single record from a table/view          
# args    : schema_name - name of the table/view
#           condition - a dict of name-value pairs
#           fieldslist - optional list of fields to be retrieved
# returns : a record as a dict with fieldname-value pairs
#
# ----------------------------------------------------------------------
public method get {schema_name condition {fieldslist ""}}


# ----------------------------------------------------------------------
# method  : mget        - Retrieve multiple records from a table/view           
# args    : schema_name - name of the table/view
#           args        - variable no. of arguments as defined by
#                         specific database implementation.
# returns : list of lists with each list having a fieldname-value pair
#           that can be constructed into a dict
#
# ----------------------------------------------------------------------
public method mget {schema_name args}


# ----------------------------------------------------------------------
# method  : insert         - insert a record into table/view           
# args    : schema_name    - name of the table/view
#           namevaluepairs - a dict containing fieldname-value pairs
#           sequence_fields- optional list of fieldnames that are
#                            auto-incremented by insert operation.
# returns : list containing two elements. First element is the status of
#           insert operation and the second a dict of
#           sequence_fieldname-value pairs.
#
# ----------------------------------------------------------------------
public method insert {schema_name namevaluepairs {sequence_fields ""}}


# ----------------------------------------------------------------------
# method  : update         - update one or more records in a table/view           
# args    : schema_name    - name of the table/view
#           namevaluepairs - a dict containing fieldname-value pairs
#           condition      - optional dict of name-value pairs
# returns : status of the update operation.
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}}


# ----------------------------------------------------------------------
# method  : delete         - delete one or more records from a table/view           
# args    : schema_name    - name of the table/view
#           condition      - optional dict of name-value pairs
# returns : status of delete operation.
#
# ----------------------------------------------------------------------
public method delete {schema_name {condition ""}}


# ----------------------------------------------------------------------
# method  : begin  - begin a database transaction
# args    : args   - variable no. of arguments as defined by a specific
#                    database implementation
# returns : status of begin operation
#
# ----------------------------------------------------------------------
public method begin {args}


# ----------------------------------------------------------------------
# method  : commit - commit current database transaction
# args    : args   - variable no. of arguments as defined by a specific
#                    database implementation
# returns : status of commit operation
#
# ----------------------------------------------------------------------
public method commit {args}


# ----------------------------------------------------------------------
# method  : rollback - roll back current transaction without commiting 
# args    : args     - variable no. of arguments as defined by a specific
#                      database implementation
# returns : status of rollback operation
#
# ----------------------------------------------------------------------
public method rollback {args}


# -------------------------END------------------------------------------
}
