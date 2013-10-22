package require tdbo::Itcl

itcl::class Address {
	inherit tdbo::Itcl::DBObject

	constructor {db args} {tdbo::Itcl::DBObject::constructor $db} {
		configure {*}$args
	}
	destructor {
	}
	public {
		proc schema_name {} {
			return "address"
		}
		variable id
		variable addrline1
		variable addrline2
		variable city
		variable postalcode
		variable country
	}
	protected {
		method _define_primarykey {} {
			define_primarykey id
		}
		method _define_autoincrement {} {
			define_autoincrement id
		}
	}
}
