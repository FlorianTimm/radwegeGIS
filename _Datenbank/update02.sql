alter table radverkehr.o_radweg add column create_date timestamp without time zone not null;
alter table radverkehr.o_radweg add column archive_date timestamp without time zone;
alter table radverkehr.o_radweg add constraint radweg_create_before_archive_check CHECK (create_date < archive_date);
alter table radverkehr.o_radweg rename column radweg_id to gid;
alter table radverkehr.o_radweg add column radweg_id uuid;
alter table radverkehr.o_radweg add column last_user text;
alter table radverkehr.o_radweg add column create_user text;
alter table radverkehr.o_radweg alter column breite SET DATA TYPE NUMERIC(5,3);
alter table radverkehr.o_radweg_data add constraint o_radweg_positive_breite check (breite > 0);

alter table radverkehr.o_radweg add column status_id uuid;
alter table radverkehr.o_radweg add column niveau_id uuid;

update radverkehr.o_radweg set create_date = now();
update radverkehr.o_radweg set radweg_id = gid;
update radverkehr.o_radweg set create_user = 'import',  last_user = 'import';

CREATE INDEX index_o_radweg_id ON radverkehr.o_radweg USING btree (radweg_id);
CREATE INDEX index_o_radweg_create ON radverkehr.o_radweg USING btree (create_date); 
CREATE INDEX index_o_radweg_archive ON radverkehr.o_radweg USING btree (archive_date); 

INSERT INTO radverkehr.kt_status (bezeichnung) VALUES
	('Betrieb'),
	('Planung'),
	('Bau'),
	('stillgelegt')
	ON CONFLICT DO NOTHING;
	
INSERT INTO radverkehr.kt_niveau (bezeichnung) VALUES
	('bodengleich'),
	('Tunnel'),
	('Brücke')
	ON CONFLICT DO NOTHING;
	
ALTER TABLE radverkehr.o_radweg ADD CONSTRAINT o_radweg_niveau_id_fkey FOREIGN KEY (niveau_id) REFERENCES radverkehr.kt_niveau(niveau_id);
ALTER TABLE radverkehr.o_radweg ADD CONSTRAINT o_radweg_status_id_fkey FOREIGN KEY (status_id) REFERENCES radverkehr.kt_status(status_id);

CREATE OR REPLACE RULE o_radweg_del AS ON DELETE TO radverkehr.o_radweg
 WHERE archive_date is null
 DO INSTEAD
 UPDATE radverkehr.o_radweg SET archive_date = now(), last_user = current_user
 WHERE o_radweg.gid = old.gid AND o_radweg.archive_date IS NULL;

CREATE OR REPLACE FUNCTION radverkehr.insert_radweg() RETURNS trigger AS
$function$
	BEGIN
		IF NEW.radweg_id IS NULL THEN
			NEW.create_date := now();
			NEW.radweg_id := NEW.gid;
			NEW.last_user := current_user;
			NEW.create_user := current_user;
		END IF;
		RETURN NEW;
	END;
$function$
LANGUAGE 'plpgsql';

CREATE TRIGGER insert_radweg BEFORE INSERT ON radverkehr.o_radweg
    FOR EACH ROW EXECUTE PROCEDURE radverkehr.insert_radweg();

CREATE OR REPLACE FUNCTION radverkehr.update_radweg() RETURNS trigger AS
$function$
	BEGIN
		OLD.archive_date := now();
		OLD.gid := uuid_generate_v1();
		EXECUTE format('INSERT INTO %I.%I SELECT $1.*', TG_TABLE_SCHEMA, TG_TABLE_NAME) USING OLD;
		
		NEW.create_date := now();
		NEW.last_user := current_user;
		RETURN NEW;
	END;
$function$
LANGUAGE 'plpgsql';

CREATE TRIGGER update_radweg BEFORE UPDATE ON radverkehr.o_radweg
    FOR EACH ROW EXECUTE PROCEDURE radverkehr.update_radweg();

ALTER TABLE radverkehr.o_radweg RENAME TO o_radweg_data;

CREATE TABLE IF NOT EXISTS radverkehr.kt_niveau (
	niveau_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text
);

CREATE TABLE IF NOT EXISTS radverkehr.kt_status (
	status_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text
);


-- EditierView
CREATE OR REPLACE VIEW radverkehr.o_radweg AS
 SELECT * FROM radverkehr.o_radweg_data
 WHERE o_radweg_data.archive_date IS NULL;

CREATE OR REPLACE RULE "_DELETE" AS
 ON DELETE TO radverkehr.o_radweg DO INSTEAD
 DELETE FROM radverkehr.o_radweg_data WHERE o_radweg_data.gid = old.gid;

CREATE OR REPLACE RULE "_INSERT" AS
 ON INSERT TO radverkehr.o_radweg DO INSTEAD
 INSERT INTO radverkehr.o_radweg_data (name_id, radweg_art_id, richtung_id, oberflaeche_id, breite, status_id, niveau_id, bemerkung, quelle_id, id_in_quelle, geometrie)
 VALUES (new.name_id, new.radweg_art_id, new.richtung_id, new.oberflaeche_id, new.breite, new.status_id, new.niveau_id, new.bemerkung, new.quelle_id, new.id_in_quelle, new.geometrie);
 
CREATE OR REPLACE RULE "_UPDATE" AS
 ON UPDATE TO radverkehr.o_radweg DO INSTEAD
 UPDATE radverkehr.o_radweg_data SET 
 name_id = new.name_id,
 radweg_art_id = new.radweg_art_id,
 richtung_id = new.richtung_id,
 oberflaeche_id = new.oberflaeche_id,
 breite = new.breite,
 status_id = new.status_id,
 niveau_id = new.niveau_id,
 bemerkung = new.bemerkung,
 quelle_id = new.quelle_id,
 id_in_quelle = new.id_in_quelle,
 geometrie = new.geometrie
 WHERE o_radweg_data.gid = new.gid;
 
