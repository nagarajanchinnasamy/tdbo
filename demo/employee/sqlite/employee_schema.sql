drop table if exists address;
create table address(
	id integer primary key autoincrement,
	addrline1 text not null,
	addrline2 text not null,
	city text not null,
	postalcode text not null,
	country text not null);
drop table if exists employee;
create table employee(
	id integer primary key autoincrement,
	name text not null,
	rollno text not null,
	address_id integer not null,
	unique(rollno),
	foreign key(address_id) references address(id));
