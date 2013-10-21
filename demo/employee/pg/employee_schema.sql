-- Table: address

-- DROP TABLE address;

CREATE TABLE address
(
  id serial NOT NULL,
  addrline1 text NOT NULL,
  addrline2 text,
  city text NOT NULL,
  postalcode text NOT NULL,
  country text NOT NULL,
  CONSTRAINT pkey PRIMARY KEY (id )
)
WITH (
  OIDS=FALSE
);

-- Table: employee

-- DROP TABLE employee;

CREATE TABLE employee
(
  id serial NOT NULL,
  name text NOT NULL,
  rollno text NOT NULL,
  address_id integer,
  CONSTRAINT emp_pkey PRIMARY KEY (id ),
  CONSTRAINT addr FOREIGN KEY (address_id)
      REFERENCES address (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT uqroll UNIQUE (rollno )
)
WITH (
  OIDS=FALSE
);

-- Sequence: address_id_seq

-- DROP SEQUENCE address_id_seq;

CREATE SEQUENCE address_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;

-- Sequence: employee_id_seq

-- DROP SEQUENCE employee_id_seq;

CREATE SEQUENCE employee_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
