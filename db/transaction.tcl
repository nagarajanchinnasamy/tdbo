# transaction.tcl --
#
# Generic Transaction interface that needs to be implemented by
# application-specific transaction classes (eg., SaveGoodsReceivedNote)
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class Transaction
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::Transaction {
	inherit tdbo::Object

# ----------------------------------------------------------------------
# method - constructor
#                        
# args   - db - instance of a specific Database implementation
#               such as SQLite
#
# ----------------------------------------------------------------------
constructor {db} {
	if {[namespace tail [info class]] == "Transaction"} {
		return -code error \
			"Error: Can't create Transaction objects - abstract class."
	}
	if {$db == "" || ![$db isa tdbo::Database]} {
		return -code error "db is not a tdbo::Database"
	}
	set [itcl::scope db] $db
}


# ----------------------------------------------------------------------
#
#
#
# ----------------------------------------------------------------------
destructor {
}


# ----------------------------------------------------------------------
# method - execute - To be implemented by the derived classes.
#                    Implementation of this method is expected to make
#                    use of begin and commit/rollback methods to execute
#                    a transaction.
#                        
# args   - none
#
# ----------------------------------------------------------------------
public method execute {}


# ----------------------------------------------------------------------
#
# db - instance of a specific Database implementation such as SQLite.
#
#
# ----------------------------------------------------------------------
protected variable db


# ----------------------------------------------------------------------
# method - begin a database transaction
#
# args   - as defined by a specific database implementation such as
#          SQLite
#
#
#
# ----------------------------------------------------------------------
protected method begin {args} {
	$db begin {*}$args
}


# ----------------------------------------------------------------------
# method - commit - commit the database transaction that is currently
#                   active.
#
# args   - as defined by a specific database implementation such as
#          SQLite
#
#
#
# ----------------------------------------------------------------------
protected method commit {args} {
	$db commit {*}$args
}


# ----------------------------------------------------------------------
# method - rollback - rollback the database transaction that is
#                     currently active.
#
# args   - as defined by a specific database implementation such as
#          SQLite
#
# ----------------------------------------------------------------------
protected method rollback {args} {
	$db rollback {*}$args
}


# ---------------------------------END----------------------------------
}
