# ----------------------------------------------------------------------
# class Database
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::Database {
	inherit tdbo::Object
# ----------------------------------------------------------------------
# constructor:
#
#
#
# ----------------------------------------------------------------------
constructor {} {
}
# ----------------------------------------------------------------------
# destructor
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
public method open {args}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method close {}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method get {schema_name condition}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method mget {schema_name args}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method insert {schema_name namevaluepairs {sequence_fields ""}}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method delete {schema_name {condition ""}}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method initialize {schema_type schema_name schema_description}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method begin {{lock deferred}}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method commit {}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method rollback {}

# -------------------------END------------------------------------------
}
