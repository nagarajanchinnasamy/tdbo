itcl::class SaveEmployee {
	inherit tdbo::Transaction

	constructor {db args} {tdbo::Transaction::constructor $db} {
		configure {*}$args
	}
	
	destructor {}

	public {
		variable employee
		variable address
		variable op

		method execute {}
	}
}

proc saveemployee {db op employee address} {
	set trans [uplevel SaveEmployee #auto $db  -op $op -employee $employee -address $address]
	uplevel	$trans execute
}

itcl::body SaveEmployee::execute {} {
	begin
		switch $op {
			add {
				if {[$address add] <= 0} {
					rollback
					${log}::error "Add Address failed. Address: [$address cget]"
					return 0
				}

				$employee configure -address_id [$address cget -id]
				if {[$employee add] <= 0} {
					rollback
					${log}::error "Add Employee failed. Employee: [$employee cget]"
					return 0
				}
			}
			update {
				if {[$address save] <= 0} {
					rollback
					${log}::error "Save Address failed. Address: [$address cget]"
					return 0
				}
				if {[$employee save] <= 0} {
					rollback
					${log}::error "Save Employee failed. Employee: [$employee cget]"
					return 0
				}					
			}
		}
	commit

	return 1
}
