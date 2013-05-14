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
#
#
#
# ----------------------------------------------------------------------
constructor {db} {
	if {[namespace tail [info class]] == "Transaction"} {
		return -code error "Error: Can't create Transaction objects - abstract class."
	}
	if {$db == "" || ![$db isa tdbo::Database]} {
		return -code error "Invalid db object type"
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
#
#
#
# ----------------------------------------------------------------------
public method execute {}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected variable db
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method begin {{lock deferred}} {
	$db begin $lock
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method commit {} {
	$db commit
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method rollback {} {
	$db rollback
}

# ---------------------------------END----------------------------------
}
