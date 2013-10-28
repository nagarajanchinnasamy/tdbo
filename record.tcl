package require struct::record

namespace eval ::tdbo {}

namespace eval ::tdbo::record {
	variable undefined "<undefined>"
	variable commands
	set commands [list define delete exists show]

	variable instcommands
	set instcommands [list configure cget clear add get save delete]

    variable schemadefn
	set schemadefn [dict create]

	variable instances
	set instances [dict create]

	variable schema_name
	variable flist
	variable sqlist
	variable pklist
	variable uqlist
	variable insertlist
	variable updatelist
	variable recordinst
}

proc ::tdbo::record::record {cmd args} {
    variable commands

	if {[lsearch $commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $commands ,]"
	}

    set cmd [string totitle "$cmd"]
    return [uplevel 1 ::tdbo::record::${cmd} $args]
}

proc ::tdbo::record::Define {schdefn_cmd schema_name fieldslist args} {
	variable schemadefn
	variable undefined
	set options [dict create {*}$args]

	set schdefn_cmd [_qualify $schdefn_cmd]
	if {[dict exists $schemadefn $schdefn_cmd]} {
		return -code error "Definition command $schdefn_cmd already exists"
	}

	set flist [list]
	set sqlist [list]
	set pklist [list]
	set uqlist [list]

	set recfields [dict create]
	foreach f $fieldslist {
		lassign $f n v
		lappend flist $n
		switch -- [llength $f] {
			1 {
				dict set recfields $n [list $n $undefined]
			}
			2 {
				dict set recfields $n $f
			}
			default {
				return -code error "Unsupported nested definition found in $schdefn_cmd."
			}
		}
	}

	if {[dict exists $options -inherits]} {
		foreach d [dict get $options -inherits] {
			_inherit recfields [_qualify $d]
		}
		dict unset options -inherits
	}
	
	set recdefn_cmd [format "%s%s" $schdefn_cmd "_record"]
	if {[catch {uplevel 1 [list struct::record define $recdefn_cmd [dict values $recfields]]} result]} {
		return -code error $result
	}
	set recdefn_cmd $result

	foreach {opt val} $options {
		switch -- $opt {
			-autoincrement {
				set sqlist $val
			}
			-primarykey {
				set pklist $val
			}
			-unique {
				set uqlist $val
			}
			default {
				return -code error "Invalid option $opt"
			}
		}
	}

	set insertlist [list]
	foreach fname $flist {
		if {[lsearch -exact $sqlist $fname] < 0} {
			lappend insertlist $fname
		}
	}

	set updatelist ""
	foreach fname $flist {
		if {[lsearch -exact $pklist $fname] < 0 && [lsearch -exact $sqlist $fname] < 0} {
			lappend updatelist $fname
		}
	}

	dict set schemadefn $schdefn_cmd -count 0
	dict set schemadefn $schdefn_cmd -schema_name $schema_name
	dict set schemadefn $schdefn_cmd -recdefn_cmd $recdefn_cmd
	dict set schemadefn $schdefn_cmd -flist $flist
	dict set schemadefn $schdefn_cmd -sqlist $sqlist
	dict set schemadefn $schdefn_cmd -pklist $pklist
	dict set schemadefn $schdefn_cmd -uqlist $uqlist
	dict set schemadefn $schdefn_cmd -insertlist $insertlist
	dict set schemadefn $schdefn_cmd -updatelist $updatelist	

    uplevel #0 [list interp alias {} $schdefn_cmd {} ::tdbo::record::Create $schdefn_cmd]

    return $schdefn_cmd
}

proc ::tdbo::record::Create {schdefn_cmd inst conn args} {
	variable schemadefn
	variable instances
	
	set inst [_qualify $inst]
    if {[dict exists $instances $inst]} {
        return -code error "Instance $inst already exists"
    }

	if {[string match "[_qualify #auto]" "$inst"]} {
		set c [dict get $schemadefn $schdefn_cmd -count]
        set inst [format "%s%s" $schdefn_cmd $c]
        dict set schemadefn $schdefn_cmd -count [incr c]
    }

	set recdefn_cmd [dict get $schemadefn $schdefn_cmd -recdefn_cmd]
	if {[catch {uplevel 1 $recdefn_cmd #auto $args} recordinst]} {
		return -code error $recordinst
	}

	dict lappend instances $schdefn_cmd $inst
    dict set instances $inst -schdefn_cmd $schdefn_cmd
    dict set instances $inst -schema_name [dict get $schemadefn $schdefn_cmd -schema_name]
	dict set instances $inst -recordinst $recordinst

    uplevel #0 [list interp alias {} ${inst} {} ::tdbo::record::Cmd $inst $conn]

    return $inst	
}

proc ::tdbo::record::Delete {sub args} {
	variable schemadefn
	variable instances

	switch -- $sub {
		definition -
		definitions -
		def {
			foreach item $args {
				set item [_qualify $item]
				if {![dict exists $schemadefn $item]} {
					return -code error "Definition $item does not exist"
				}

				# delete any existing instances
				if {[dict exists $instances $item]} {
					foreach inst [dict get $instances $item] {
						Delete instance $inst
					}
				}

				# delete corresponding record definition
				set recdefn_cmd [dict get $schemadefn $item -recdefn_cmd]
				if {[catch {uplevel 1 struct::record delete record $recdefn_cmd} result]} {
					return -code error $result
				}

				# delete the definition
				dict unset schemadefn $item

				# remove command alias
				catch {uplevel #0 [list interp alias {} $item {}]}
			}
		}
		instance -
		instances -
		inst {
			foreach item $args {
				set item [_qualify $item]
				if {![dict exists $instances $item]} {
					return -code error "DAO instance $item does not exist"
				}

				# delete corresponding record inst
				set recordinst [dict get $instances $item -recordinst]
				if {[catch {uplevel 1 struct::record delete instance $recordinst} result]} {
					return -code error $result
				}

				# delete from list of instances of the definition
				set schdefn_cmd [dict get $instances $item -schdefn_cmd]
				set insts [dict get $instances $schdefn_cmd]
				set i [lsearch $insts $item]
				if {$i >= 0} {
					dict set instances $schdefn_cmd [lreplace $insts $i $i]
				}

				# delete it from instances
				dict unset instances $item

				# remove command alias
				catch {uplevel #0 [list interp alias {} $item {}]}
			}
		}
	}
}

proc ::tdbo::record::Exists {sub item} {
	variable schemadefn
	variable instances

	switch -- $sub {
		definition {
			return [dict exists $schemadefn $item]
		}
		instance {
			return [dict exists $instances $item]
		}
	}
}

proc ::tdbo::record::Show {what {of ""}} {
	variable schemadefn
	variable instances

	switch -- $what {
		definitions {
			return [dict keys $schemadefn]
		}
		instances {
			set of [_qualify $of]
			if {![dict exists $schemadefn $of]} {
				return -code error "Unknown definition $of"
			}
			if {![dict exists $instances $of]} {
				return
			}
			return [dict get $instances $of]
		}
		fields {
			set of [_qualify $of]
			if {![dict exists $schemadefn $of]} {
				return -code error "Unknown definition $of"
			}
			return [struct::record show members [dict get $schemadefn $of -recdefn_cmd]]
		}
		values {
			set of [_qualify $of]
			if {![dict exists $instances $of]} {
				return -code error "Unknown DAO instance $of"
			}
			return [struct::record show values [dict get $instances $of -recordinst]]
		}
	}
}

proc ::tdbo::record::Cmd {inst conn cmd args} {
	variable schemadefn
	variable instances
    variable instcommands

	variable schema_name
	variable flist
	variable sqlist
	variable pklist
	variable uqlist
	variable insertlist
	variable updatelist
	variable recordinst

    if {![dict exists $instances $inst]} {
        return -code error "Instance $inst does not exist"
    }

	if {[lsearch $instcommands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $instcommands ,]"
	}

	set schdefn_cmd [dict get $instances $inst -schdefn_cmd]
	set schdefn [dict get $schemadefn $schdefn_cmd]

	dict update schdefn \
		-schema_name schema_name \
		-flist flist \
		-sqlist sqlist \
		-pklist pklist \
		-uqlist uqlist \
		-insertlist insertlist \
		-updatelist updatelist {
	}

	set recordinst [dict get $instances $inst -recordinst]

	switch -- $cmd {
		configure -
		cget -
		clear {
			return [uplevel 1 ::tdbo::record::${cmd} $inst $args]
		}
		default {
			return [uplevel 1 ::tdbo::record::${cmd} $inst $conn $args]
		}
	}
}

proc ::tdbo::record::configure {inst args} {
	variable recordinst

	if {[catch {uplevel 1 $recordinst configure $args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::record::cget {inst args} {
	variable recordinst

	set fmt [lindex $args 0] 
	if {$fmt == "dict"} {
		if {[catch {uplevel 1 $recordinst cget} result]} {
			return -code error $result
		}

		set args [lrange $args 1 end]
		set result [dict create {*}$result]
		set result [dict filter $result script {n v} {
			if {[lsearch $args $n] < 0} {
				continue
			}
			expr 1
		}]
		return $result
	}

	if {[catch {uplevel 1 $recordinst cget $args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::record::clear {inst args} {
	variable instances
	variable schemadefn
	variable recordinst
	
	set schdefn_cmd [dict get $instances $inst -schdefn_cmd]
	set recdefn_cmd [dict get $schemadefn $schdefn_cmd -recdefn_cmd]

	set config [list]
	foreach m [struct::record show members $recdefn_cmd] {
		lassign $m n v
		lappend config -$n $v
	}

	uplevel 1 $recordinst configure $config
}


proc ::tdbo::record::add {inst conn args} {
	variable insertlist
	variable schema_name
	variable sqlist
	variable recordinst

	if {$args == ""} {
		set namevaluepairs [_make_namevaluepairs $insertlist]
	} else {
		set namevaluepairs [_make_namevaluepairs $args]
	}

	if {[catch {$conn insert $schema_name $namevaluepairs $sqlist} result]} {
		return -code error $result
	}
		
	lassign $result status sequencevalues

	if {$status} {
		if {$sequencevalues != ""} {
			set sequencecfg [dict create]
			dict for {fname val} $sequencevalues {
				dict set sequencecfg -${fname} $val
			}
			$recordinst configure {*}$sequencecfg
		}
	}
	return $status
}

proc ::tdbo::record::get {inst conn args} {
	variable flist
	variable schema_name
	variable recordinst

	if {$args != ""} {
		set flist $args
	}

	if {[catch {$conn get $schema_name $flist [_get_condition] dict} result]} {
		return -code error $result
	}
	if {[llength $result] > 1} {
		return -code error "Multiple records retrieved in get operation"
	}

	set objcfg [lindex $result 0]
		
	if {[dict size $objcfg]} {
		$recordinst configure {*}[dict get $objcfg]
	}

	return $objcfg
}


proc ::tdbo::record::save {inst conn args} {
	variable updatelist
	variable schema_name

	if {$args != ""} {
		set updatelist $args
	}
	
	if {[catch {$conn update $schema_name [_make_namevaluepairs $updatelist] [_get_condition]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdbo::record::delete {inst conn args} {
	variable schema_name
	variable recordinst

	if {[catch {$conn delete $schema_name [_get_condition]} result]} {
		return -code error $result
	}

	if {$result} {
		clear $inst
	}

	return $result
}

proc ::tdbo::record::_get_condition {} {
	variable pklist
	variable uqlist

	set condition [list]
	set pkcondition [_make_keyvaluepairs $pklist]
	if {$pkcondition != ""} {
		lappend condition $pkcondition
	}
	foreach uq $uqlist {
		set uqcondition [_make_keyvaluepairs $uq]
		if {$uqcondition != ""} {
			lappend condition $uqcondition
		}
	}
	return $condition
}

proc ::tdbo::record::_make_keyvaluepairs {fieldslist} {
	variable recordinst
	variable undefined

	set keyslist [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$recordinst cget -$field]] == $undefined} {
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

proc ::tdbo::record::_make_namevaluepairs {fieldslist} {
	variable recordinst
	variable undefined

	set namevaluepairs [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$recordinst cget -$field]] != "<undefined>"} {
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

proc ::tdbo::record::_inherit {recfieldsvar schdefn_cmd} {
	variable schemadefn
	variable flist
	upvar $recfieldsvar recfields

	set recdefn_cmd [dict get $schemadefn $schdefn_cmd -recdefn_cmd]
	foreach f [struct::record show members $recdefn_cmd] {
		lassign $f n v
		if {[dict exists $recfields $n]} {
			continue
		}
		
		lappend flist $n
		dict set recfields $n $f
	}
}

proc ::tdbo::record::_qualify {item {level 2}} {

    if {![string match "::*" "$item"]} {
        set ns [uplevel $level [list namespace current]]

        if {![string match "::" "$ns"]} {
            append ns "::"
        }
     
        set item "$ns${item}"
    }

    return "$item"

}

namespace eval ::tdbo::record {
    namespace export record
}

package provide tdbo::record 0.1.1
