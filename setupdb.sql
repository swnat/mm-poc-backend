CREATE DATABASE database_pro;
CREATE USER dbuser WITH PASSWORD 'foobar';
GRANT ALL ON DATABASE database_pro TO dbuser;
\connect database_pro
CREATE EXTENSION HSTORE;