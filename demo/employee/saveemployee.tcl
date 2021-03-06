proc saveemployee {log conn op employee address} {
	$conn begin
		switch $op {
			add {
				if {[$address add] <= 0} {
					$conn rollback
					${log}::error "Add Address failed. Address: [$address cget]"
					return 0
				}

				$employee configure -address_id [$address cget -id]
				if {[$employee add] <= 0} {
					$conn rollback
					${log}::error "Add Employee failed. Employee: [$employee cget]"
					return 0
				}
			}
			update {
				if {[$address save] <= 0} {
					$conn rollback
					${log}::error "Save Address failed. Address: [$address cget]"
					return 0
				}
				if {[$employee save] <= 0} {
					$conn rollback
					${log}::error "Save Employee failed. Employee: [$employee cget]"
					return 0
				}					
			}
		}
	$conn commit

	return 1
}
