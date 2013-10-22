# dbobject.tcl --
#
# Data Object Interface that needs to be inherited by
# application-specific object classes (eg., Employee, PurchaseItem etc.)
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require logger
package require Itcl

# ----------------------------------------------------------------------
# class Object
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::Itcl::Object {

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
constructor {} {
	if {[namespace tail [info class]] == "Object"} {
		return -code error "Error: Can't create Object instances - abstract class."
	}
	set clsName [$this info class]
	set log [::logger::init $clsName]
}
# ----------------------------------------------------------------------
#
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
#
# ----------------------------------------------------------------------
public method configure {{option ""} args} {
	# Usage: objName configure
	# return value: -opt {-ival val -cval val} -opt {-ival val -cval val} ...
	if {![string length $option]} {
		set result [dict create]
		foreach optcfg [_itcl_configure] {
			lassign $optcfg optname ival cval
			dict set result $optname [list -ival $ival -cval $cval]
		}
		return $result
	}

	# Usage: objName configure objName1
	# Usage (Copy constructor): className objName objName1
	# return value: ""
	if {![llength $args]} {
		if {[catch {uplevel $option isa [$this info class]} err]} {
			_itcl_configure $option {*}$args
			return
		}
		_itcl_configure {*}[uplevel $option cget]
		return
	}
	
	# Usage: objName configure -opt val -opt val ...
	# return value: ""
	_itcl_configure $option {*}$args
	return
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method cget {{option ""} args} {
	# Usage: objName cget
	# return value: -opt val -opt val ...
	if {![string length $option]} {
		set config [configure]
		set result [dict create]
		foreach opt [dict keys $config] {
			dict set result $opt [dict get $config $opt -cval]
		}

		return $result
	}

	set config [configure]

	# Usage: objName cget -opt
	# return value: val
	if {![llength $args]} {
		return [dict get $config $option -cval]
	}

	# Usage: objName cget -opt vName -opt vName ...
	# return value: ""
	# return value: values for opt is stored in corresponding vName
	set args [linsert $args 0 $option]
	foreach {opt vname} $args {
		upvar $vname var
		set var [dict get $config $opt -cval]
	}
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method clear {} {
	set config [configure]
	foreach opt [dict keys $config] {
		configure $opt [dict get $config $opt -ival]
	}
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected variable clsName
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected variable log
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method _itcl_configure {{option ""} args} @itcl-builtin-configure
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method _itcl_cget {{option ""} args} @itcl-builtin-cget

}

# ----------------------------------------------------------------------
# class DBObject
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::Itcl::DBObject {
	inherit tdbo::Itcl::Object

# ----------------------------------------------------------------------
# method - constructor - Stores the definition of primary keys, unique
#                        fields and sequence / auto-increment fields by
#                        invoking following (optional) protected methods
#                        in the derived class:
#		                     _define_primarykey
#		                     _define_unique
#		                     _define_autoincrement
#                        Also prepares list of fieldnames to be used by
#                        insert and update operations later.
#                        
# args   - conn - instance of a specific Database implementation
#               such as SQLite
#
# ----------------------------------------------------------------------
constructor {conn} {
	if {[namespace tail [info class]] == "DBObject"} {
		return -code error "Error: Can't instantiate DBObject - abstract class."
	}

	set [itcl::scope conn] $conn
	if ![llength [array names fields -glob "$clsName,*"]] {
		_define_primarykey
		_define_unique
		_define_autoincrement
		__prepare_getfields
		__prepare_insertfields
		__prepare_updatefields
	}
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
destructor {}


# ----------------------------------------------------------------------
# proc    : schema_name - method to be implemented by derived classes that
#                      returns the name of the table/view
# args    : none
#
# returns : name of the table/view the derived class represents
#
# ----------------------------------------------------------------------
public proc schema_name {}


# ----------------------------------------------------------------------
# method : add - Insert the object into database.
#
#                Upon successful completion of add The new values of
#                sequence / auto incremented fields are updated back
#                into the object.
#
# ----------------------------------------------------------------------
public method add {args} {
	if {$args == ""} {
		set namevaluepairs [__make_namevaluepairs $fields($clsName,insertlist)]
	} else {
		set namevaluepairs [__make_namevaluepairs $args]
	}

	if {[catch {$conn insert [${clsName}::schema_name] $namevaluepairs $fields($clsName,sqlist)} result]} {
		${log}::error $result
		return 0
	}
		
	lassign $result status sequencevalues

	if {$status} {
		if {$sequencevalues != ""} {
			set sequencecfg [dict create]
			dict for {fname val} $sequencevalues {
				dict set sequencecfg -${fname} $val
			}
			$this configure {*}$sequencecfg
		}
	}
	return $status
}


# ----------------------------------------------------------------------
# method : get - Retrieve a record from the database and populate
#                object's member variables with values retrieved.
#
#                By default, this method retrieves all the fields of a
#                record from the database, identifed by the public
#                member variables. However, if the argument args is
#                passed with a list of field names (corresponding to its
#                public member variables) then only those fields are
#                retrieved and populated into the object.
#
#                If the retrieval contains more than
#                one record, then this method returns an error.
#
#                Upon successful execution, in addition to populating
#                the member variables, this method returns the
#                name-value pairs retrieved from database as a dict. If
#                the retrieval does not return any record from database,
#                then the result will be an empty string. 
#
# ----------------------------------------------------------------------
public method get {args} {
	set fieldslist $fields($clsName,getlist)
	if {$args != ""} {
		set fieldslist $args
	}

	if {[catch {$conn get [${clsName}::schema_name] $fieldslist [__get_condition] dict} result]} {
		return -code error $result
	}
	if {[llength $result] > 1} {
		return -code error "Multiple records retrieved in get operation"
	}

	set objcfg [lindex $result 0]
	if {[llength $objcfg]} {
		$this configure {*}$objcfg
	}

	return $objcfg
}


# ----------------------------------------------------------------------
# method : save - save the object into database.
#
#
#                Returns the status of add operation as a numerical
#                value. Non-zero value indicates success.
# ----------------------------------------------------------------------
public method save {args} {
	if {$args == ""} {
		set namevaluepairs [__make_namevaluepairs $fields($clsName,updatelist)]
	} else {
		set namevaluepairs [__make_namevaluepairs $args]
	}

	if {[catch {$conn update [${clsName}::schema_name] $namevaluepairs [__get_condition]} result]} {
		${log}::error $result
		return 0
	}

	return $result
}


# ----------------------------------------------------------------------
# method : delete - delete the record represented by the object in
#                   database and reset the object values.
#
#                   Returns the status of delete operation as a numerical
#                   value. Non-zero value indicates success.
#
# ----------------------------------------------------------------------
public method delete {} {
	if {[catch {$conn delete [${clsName}::schema_name] [__get_condition]} result]} {
		${log}::error $result
		return 0
	}

	if {$result} {
		clear
	}

	return $result
}

# ----------------------------------------------------------------------
# method  : define_primarykey - method to be invoked by derived classes
#                               from within _define_primarykey method.
# args    : a list of fieldnames that constitute the primary key
#
# returns : none
# ----------------------------------------------------------------------
protected method define_primarykey {args} {
	set fields($clsName,pklist) $args
}


# ----------------------------------------------------------------------
# method  : define_unque - method to be invoked by derived classes
#                          from within _define_primarykey method.
# args    : a list of lists with each list containing fieldnames that
#           constitute a unique key
#
# returns : none
# ----------------------------------------------------------------------
protected method define_unique {args} {
	set fields($clsName,uqlist) $args
}


# ----------------------------------------------------------------------
# method  : define_autoincrement - method to be invoked by derived
#                                  classes from within
#                                  _define_autoincrement method.
# args    : a list containing fieldnames that are autoincrement/sequence
#           fields.
#
# returns : none
# ----------------------------------------------------------------------
protected method define_autoincrement {args} {
	set fields($clsName,sqlist) $args
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _define_primarykey {} {
	define_primarykey
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _define_unique {} {
	define_unique
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _define_autoincrement {} {
	define_autoincrement
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private common fields; array set fields {}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private variable conn


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __get_condition {} {
	set condition [list]
	set pkcondition [__make_keyvaluepairs $fields($clsName,pklist)]
	if {$pkcondition != ""} {
		lappend condition $pkcondition
	}
	foreach uqlist $fields($clsName,uqlist) {
		set uqcondition [__make_keyvaluepairs $uqlist]
		if {$uqcondition != ""} {
			lappend condition $uqcondition
		}
	}
	return $condition
}

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __prepare_getfields {} {
	if ![llength [array names fields -exact "$clsName,getlist"]] {
		set getlist ""
		foreach {opt val} [$this cget] {
			lappend getlist [string range $opt 1 end]
		}
		set fields($clsName,getlist) $getlist			
	}
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __prepare_insertfields {} {
	set sqlist $fields($clsName,sqlist)

	if ![llength [array names fields -exact "$clsName,insertlist"]] {
		set insertlist ""
		foreach {opt val} [$this cget] {
			set fname [string range $opt 1 end]
			if {[lsearch -exact $sqlist $fname] < 0} {
				lappend insertlist $fname
			}
		}
		set fields($clsName,insertlist) $insertlist			
	}
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __prepare_updatefields {} {
	set sqlist $fields($clsName,sqlist)
	set pklist $fields($clsName,pklist)

	if ![llength [array names fields -exact "$clsName,updatelist"]] {
		set updatelist ""
		foreach {opt val} [$this cget] {
			set fname [string range $opt 1 end]
			if {[lsearch -exact $pklist $fname] < 0 && [lsearch -exact $sqlist $fname] < 0} {
				lappend updatelist $fname
			}
		}
		set fields($clsName,updatelist) $updatelist			
	}
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __make_keyvaluepairs { fieldslist } {
	set keyslist [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$this cget -$field]] == "<undefined>"} {
				return ""
			}
			if {$val == "<null>"} {
				lappend keyslist $field "IS NULL"
			} else {
				lappend keyslist $field $val
			}
		}
	}

	return $keyslist
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __make_namevaluepairs { fieldslist } {
	set namevaluepairs [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$this cget -$field]] != "<undefined>"} {
				if {$val == "<null>"} {
					lappend namevaluepairs $field NULL
				} else {
					lappend namevaluepairs $field $val
				}
			}
		}
	}

	return $namevaluepairs
}

}

package provide tdbo::Itcl 0.1.0

