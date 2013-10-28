
itcl::class Employee {
	inherit tdbo::Itcl::DBObject

	constructor {db args} {tdbo::Itcl::DBObject::constructor $db} {
		configure {*}$args
	}
	destructor {
	}
	public {
		proc schema_name {} {
			return "employee"
		}
		variable id
		variable name
		variable rollno
		variable address_id
	}
	protected {
		method _define_primarykey {} {
			define_primarykey id
		}
		method _define_autoincrement {} {
			define_autoincrement id
		}
		method _define_unique {} {
			define_unique {rollno}
		}
	}
}
