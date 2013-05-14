tdbo - Tcl DataBase Object
==========================

Tcl DataBase Object (tdbo) provides a simple object oriented interface to database layer of an application. It is written based on incrTcl extension of Tcl. Currently it supports sqlite3 database. However, tdbo package is written in a generic way to plugin support for other databases. We will add support for other databases such as MySQL, Oracle etc., in future releases.

Simple steps to use this package are:

1. Load tdbo package using:
	package require tdbo

2. Define your application object by inheriting tdbo::DBObject

		# Employee Definition

		itcl::class Employee {
			inherit tdbo::DBObject

			# db argument is an instance of tdbo::SQLite class
			constructor {db args} {tdbo::DBObject::constructor $db} {
				configure {*}$args
			}

			# Implementing this proc is mandatory to return
			# name of the table/view.
			proc schema_name {} {
				return "employeeTable"
			}

			# public variables correspond to fields in the database table
			public variable id
			public variable name
			public variable rollno

			# define primary key, unique and sequence/autoincrement fields
			protected method _define_primarykey {} {
				define_primarykey id  
			}

			protected method _define_autoincrement {} {
				define_autoincrement id
			}
			protected method _define_unique {} {
				define_unique {rollno}
			}
		}

3. Now in your main application, create a database implementation interface:

		set db [tdbo::SQLite #auto -location mytest/test.db]
		$db open

4. Create instances of Employee and start using it transparently:

		Employee emp $db -name "new employee" -rollno "MK12345" 
	
		# insert the record. After addition the id is automatically populated.
		emp1 add
	
		# modify the record
		emp1 configure -name "new updated employee"
		emp1 save
	
		# delete the record
		emp1 delete	
	
		# query about another employee with rollno "MK67890"
		emp clear
		emp configure -rollno "MK67890"
		emp get
		puts [emp cget]


For more details please visit: http://nagarajanchinnasamy.blogspot.in/
