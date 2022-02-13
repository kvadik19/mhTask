DROP TABLE IF EXISTS address;
DROP TABLE IF EXISTS nodes;
DROP INDEX IF EXISTS address_pkey;
DROP INDEX IF EXISTS address_cnt;
DROP INDEX IF EXISTS nodes_pkey;
DROP INDEX IF EXISTS nodes_name;
DROP INDEX IF EXISTS nodes_ipref;
CREATE TABLE address (
	ip inet PRIMARY KEY,
	cnt int DEFAULT 0
);
CREATE TABLE nodes (
	id serial PRIMARY KEY,
	name varchar(128),
	ipref inet ARRAY[5],
	ltime timestamp DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX address_cnt ON address (cnt);
CREATE INDEX nodes_name ON nodes (name);
CREATE INDEX nodes_ipref ON nodes (ipref);
