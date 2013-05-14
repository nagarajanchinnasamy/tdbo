# ----------------------------------------------------------------------
# class DBObject
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::DBObject {
	inherit tdbo::Object

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
constructor {db} {
	if {[namespace tail [info class]] == "DBObject"} {
		return -code error "Error: Can't create DBObject objects - abstract class."
	}
	if {$db == "" || ![$db isa tdbo::Database]} {
		return -code error "Invalid db object type"
	}
	set [itcl::scope db] $db
	if ![llength [array names fields -glob "$clsName,*"]] {
		_define_primarykey
		_define_unique
		_define_autoincrement
		_prepare_insertfields
		_prepare_updatefields
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
# int: num_changes
#
#
#
# ----------------------------------------------------------------------
public proc schema_name {}
# ----------------------------------------------------------------------
# int: num_changes
#
#
#
# ----------------------------------------------------------------------
public method add {args} {
	if {$args == ""} {
		set namevaluepairs [_make_namevaluepairs $fields($clsName,insertlist)]
	} else {
		set namevaluepairs [_make_namevaluepairs [dict keys $args]]
	}

	set result [$db insert [${clsName}::schema_name] $namevaluepairs $fields([$this info class],sqlist)]
	lassign $result status sequence

	if {$status} {
		if {$args != ""} {
			$this configure {*}$args
		}
		if {$sequence != ""} {
			$this configure {*}$sequence
		}
	}
	return $status
}
# ----------------------------------------------------------------------
# dict: objcfg
#
#
#
# ----------------------------------------------------------------------
public method get {args} {
	set objcfg [dict create]
	foreach {fname val} [$db get [${clsName}::schema_name] [_get_condition]] {
		dict set objcfg "-$fname" "$val"
	}

	if {[dict size $objcfg]} {
		$this configure {*}[dict get $objcfg]
	}

	return $objcfg
}
# ----------------------------------------------------------------------
# int: numchanges
#
#
#
# ----------------------------------------------------------------------
public method save {args} {
	if {$args == ""} {
		set namevaluepairs [_make_namevaluepairs $fields($clsName,updatelist)]
	} else {
		set namevaluepairs [_make_namevaluepairs [dict keys $args]]
	}

	set result [$db update [${clsName}::schema_name] $namevaluepairs [_get_condition]]
	if {$result} {
		$this configure {*}$args
	}
	
	return $result
}
# ----------------------------------------------------------------------
# int: numchanges
#
#
#
# ----------------------------------------------------------------------
public method delete {} {
	set result [$db delete [${clsName}::schema_name] [_get_condition]]
	if {$result} {
		clear
	}
	return $result
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected common fields; array set fields {}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected variable db ""
# ----------------------------------------------------------------------
#
# list: objcfgs
#
#
# ----------------------------------------------------------------------
protected proc _mget {objClsName db args} {
	if {![$db isa Database]} {
		return -code error "Invalid db object type"
	}

	set format dict
	if {[dict exists $args -format]} {
		set format [dict get $args -format]
		dict unset args -format
	}

	set records [$db mget [${objClsName}::schema] {*}$args]
	set result [list]
	switch $format {
		dict {
			foreach record  $records {
				set objconfig [dict create]
				foreach {fname val} $record {
					dict set objconfig "-$fname" "$val"
				}
				lappend result [dict get $objconfig]
			}
		}
		values {
			foreach record  $records {
				lappend result {*}[dict values $record]
			}
		}
	}

	return $result
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method define_primarykey {args} {
	set fields($clsName,pklist) [list {*}$args]
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method define_unique {args} {
	set fields($clsName,uqlist) [list {*}$args]
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method define_autoincrement {args} {
	set fields($clsName,sqlist) [list {*}$args]
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
protected method _get_condition {} {
	set condition [list]
	set pkcondition [_make_keyvaluepairs $fields($clsName,pklist)]
	if {$pkcondition != ""} {
		lappend condition $pkcondition
	}
	foreach uqlist $fields($clsName,uqlist) {
		set uqcondition [_make_keyvaluepairs $uqlist]
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
protected method _get_keyvaluepairs {} {
	set pairslist ""
	if [llength [set keyslist [_make_keyvaluepairs $fields($clsName,pklist)]]] {
		lappend pairslist $keyslist
	}

	foreach uqlist $fields($clsName,uqlist) {
		if [llength [set keyslist [_make_keyvaluepairs $uqlist]]] {
			lappend pairslists $keyslist
		}
	}
	return $pairslist
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _prepare_insertfields {} {
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
protected method _prepare_updatefields {} {
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
protected method _make_keyvaluepairs { fieldslist } {
	set keyslist [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$this cget -$field]] == "<undefined>"} {
				return ""
			}
			lappend keyslist $field $val
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
protected method _make_namevaluepairs { fieldslist } {
	set namevaluepairs [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$this cget -$field]] != "<undefined>"} {
				lappend namevaluepairs $field $val
			}
		}
	}

	return $namevaluepairs
}

# -------------------------------END------------------------------------
}
