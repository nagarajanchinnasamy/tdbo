tdbo - Tcl DataBase Object
==========================

The tdbo package provides an object oriented mechanism to access data in data stores. A tdbo object instance provides add, get, save and delete methods to manipulate data in the data store. In addition, they provide configure and cget methods to access data members of an instance in a standard tcl-ish style.

tdbo objects can be defined in various ways:

   1. Through tdbo::record package, TDBO provides a way for applications to define and use tdbo objects with Tcllib's struct::record like structure.
   2. By inheriting Itcl based tdbo::Itcl::DBObject class.
   3. 3. Others to follow ....

A data-store-driver is the one that implements necessary connectivity mechanism and procedures to access the data store. tdbo::load method is used to load a specific data-store-driver instance. Using open method of a data-store-driver instance, an application obtains one or many connection handles to the data store. During the instantiation of a tdbo object, a connection handle is passed on to it to make use of the connection handle to perform add, get, save and delete methods on the data store.

Using the connection handle, an application can also invoke 1) mget 2) begin, commit and rollback and 3) close methods to 1) retrieve multiple data records based on filtering, sorting and grouping criteria 2) perform atomic and concurrent transactions and 3) close the connection respectively.

Currently, tdbo supports sqlite3, mysqltcl, Pgtcl, tdbc::sqlite3, tdbc::mysql and tdbc::postgres drivers. Note that sqlite3, mysqltcl and Pgtcl drivers are functional in Tcl 8.5 and later releases while tdbc::<driver>s are available only from Tcl 8.6 onwards.

For example applications using tdbo::record and tdbo::Itcl packages please look into the demo folder of this package.

For detailed documentation, please refer to tdbo.html. For license information, please refer to license.terms file.


--------
Copyright © 2013, Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
