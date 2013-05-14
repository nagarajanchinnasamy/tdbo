package require logger
package require sqlite3
package require Itcl
package require tdbo

namespace import -force ::tdbo::*

set dir [file dirname [info script]]
source [file join $dir "../../../../TServer/db/objects/code/classdef.tcl"]
source [file join $dir "../../../../TServer/db/transactions/ui/fetchclass.tcl"]

tdbo::FileLogger::open /tmp/test1.log
set log [tdbo::FileLogger::init test1 debug]

set db [::tdbo::SQLite #auto -location /tmp/test.db]
$db open

#~ SQLiteTable::init_table $log [$db cget -conn] classdef {
			#~ id integer primary key autoincrement,
			#~ classpath text not null unique,
			#~ classdef text not null
#~ }

ClassDef clsdef $db -classpath myclass -classdef "my def"
puts [clsdef delete]


clsdef configure -classpath myclass -classdef "my def"
puts [clsdef add]

clsdef clear
clsdef configure -classpath myclass
puts [clsdef get]
puts [clsdef cget -classdef]

clsdef configure -classdef "my new def"
puts [clsdef save]

clsdef clear
clsdef configure -classpath myclass
clsdef get
puts [clsdef cget -classdef]

FetchClass fetchclass $db -classpath myclass
puts [fetchclass execute]
