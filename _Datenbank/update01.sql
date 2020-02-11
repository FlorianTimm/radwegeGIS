DROP VIEW IF EXISTS radverkehr.v_radweg;

CREATE TABLE IF NOT EXISTS radverkehr.kt_strassenname (
	name_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	strassenschluessel varchar (10),
	bezeichnung varchar(200) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS radverkehr.kt_quelle (
	quelle_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text
);

alter table radverkehr.o_radweg rename column wegenummer to name_id;
alter table radverkehr.o_radweg alter column name_id type UUID USING name_id::uuid;
ALTER TABLE radverkehr.o_radweg ADD CONSTRAINT name_id_fk FOREIGN KEY (name_id) REFERENCES radverkehr.kt_strassenname(name_id) MATCH FULL;
alter table radverkehr.o_radweg add column quelle_id UUID REFERENCES radverkehr.kt_quelle(quelle_id);
alter table radverkehr.o_radweg add column id_in_quelle varchar(100);