-- Erweiterung zur Erzeugung von UUIDs 
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Ggf. alte Loeschen
--DROP TABLE IF EXISTS radverkehr.v_radweg_route;

--DROP TABLE IF EXISTS radverkehr.o_radroute;
--DROP TABLE IF EXISTS radverkehr.o_ausstattung;
--DROP TABLE IF EXISTS radverkehr.o_radweg_data;

--DROP TABLE IF EXISTS radverkehr.kt_routenklasse;
--DROP TABLE IF EXISTS radverkehr.kt_ausstattungsart;
--DROP TABLE IF EXISTS radverkehr.kt_radweg_art;
--DROP TABLE IF EXISTS radverkehr.kt_richtung;
--DROP TABLE IF EXISTS radverkehr.kt_oberflaeche;

-- Klartexte
CREATE TABLE IF NOT EXISTS radverkehr.kt_routenklasse (
	klasse_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text,
	zustaendigkeit text
);

CREATE TABLE IF NOT EXISTS radverkehr.kt_ausstattungsart (
	ausstattungsart_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text,
	zustaendigkeit text
);

CREATE TABLE IF NOT EXISTS radverkehr.kt_radweg_art (
	radweg_art_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text
);

CREATE TABLE IF NOT EXISTS radverkehr.kt_richtung (
	richtung_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text
);

CREATE TABLE IF NOT EXISTS radverkehr.kt_strassenname (
	name_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	strassenschluessel varchar (10)
);

CREATE TABLE IF NOT EXISTS radverkehr.kt_oberflaeche (
	oberflaeche_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text
);

CREATE TABLE IF NOT EXISTS radverkehr.kt_quelle (
	quelle_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text
);

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


-- Objekte

CREATE TABLE IF NOT EXISTS radverkehr.o_radweg_data (
	gid UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	radweg_id UUID NOT NULL,
	name_id UUID REFERENCES radverkehr.kt_strassenname(name_id),
	laenge float,
	radweg_art_id UUID REFERENCES radverkehr.kt_radweg_art(radweg_art_id),
	richtung_id UUID REFERENCES radverkehr.kt_richtung(richtung_id),
	oberflaeche_id UUID REFERENCES radverkehr.kt_oberflaeche(oberflaeche_id),
	quelle_id UUID REFERENCES radverkehr.kt_quelle(quelle_id),
	id_in_quelle varchar(100),
	breite NUMERIC(5,3) check (breite > 0),
	status_id UUID REFERENCES radverkehr.kt_status(status_id),
	niveau_id UUID REFERENCES radverkehr.kt_niveau(niveau_id),
	bemerkung text,
	geometrie geometry(LINESTRING,25832) NOT NULL,
	create_date timestamp without time zone not null,
	archive_date timestamp without time zone CHECK (create_date < archive_date),
	create_user text,
	last_user text
);

CREATE INDEX IF NOT EXISTS index_o_radweg_id ON radverkehr.o_radweg USING btree (radweg_id);
CREATE INDEX IF NOT EXISTS index_o_radweg_create ON radverkehr.o_radweg USING btree (create_date); 
CREATE INDEX IF NOT EXISTS index_o_radweg_archive ON radverkehr.o_radweg USING btree (archive_date); 

CREATE TABLE IF NOT EXISTS radverkehr.o_radroute (
	radroute_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL,
	beschreibung text,
	hyperlink varchar(200),
	klasse_id UUID REFERENCES radverkehr.kt_routenklasse (klasse_id),
	von_km float,
	bis_km float
);

CREATE TABLE IF NOT EXISTS radverkehr.o_ausstattung (
	radroute_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	radweg_id UUID REFERENCES radverkehr.o_radweg_data(radweg_id),
	bezeichnung varchar(200),
	ausstattungsart_id UUID NOT NULL REFERENCES radverkehr.kt_ausstattungsart(ausstattungsart_id),
	betreiber text,
	kontakt text
);

CREATE TABLE IF NOT EXISTS radverkehr.v_radweg_route (
	weg_route_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	radweg_id UUID NOT NULL REFERENCES radverkehr.o_radweg_data(radweg_id),
	radroute_id UUID NOT NULL REFERENCES radverkehr.o_radroute(radroute_id),
	CONSTRAINT v_radweg_route_unique UNIQUE (radweg_id, radroute_id)
);

-- Klartexte fuellen
INSERT INTO radverkehr.kt_routenklasse (bezeichnung, beschreibung, zustaendigkeit) VALUES
	('Veloroute', 'Fahrradrouten für den Alltags-Radverkehr', 'BWVI'),
	('Freizeitroute', 'Fahrradrouten für den Freizeit-Radverkehr', NULL)
	ON CONFLICT DO NOTHING;
	
INSERT INTO radverkehr.kt_ausstattungsart (bezeichnung, beschreibung) VALUES
	('Fahrrad-Luftstation', 'Öffentliche Luftpumpe'),
	('Rastplatz', 'Öffentliche Bänke und Tische'),
	('Bank', 'Öffentliche Bänke') ON CONFLICT DO NOTHING;
	
INSERT INTO radverkehr.kt_radweg_art (bezeichnung, beschreibung) VALUES
	('Gemeinsamer Rad-/Fußweg', NULL),
	('Getrennter Rad-/Fußweg', NULL),
	('Radweg', NULL),
	('Allgemeiner Weg', 'Weg ohne Beschilderung')
	ON CONFLICT DO NOTHING;
	
INSERT INTO radverkehr.kt_richtung (bezeichnung) VALUES
	('in Geometrie-Richtung'),
	('gegen Geometrie-Richtung'),
	('in beide Richtungen')
	ON CONFLICT DO NOTHING;
	
INSERT INTO radverkehr.kt_oberflaeche (bezeichnung) VALUES
	('Bituminöse Decke'),
	('Betonplatten'),
	('Betonstein-Plaster'),
	('Naturstein-Pflaster'),
	('Wassergebundene Decke'),
	('Unbefestigt')
	ON CONFLICT DO NOTHING;

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
	
-- Trigger und Funktionen

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

CREATE OR REPLACE TRIGGER update_radweg BEFORE UPDATE ON radverkehr.o_radweg_data
    FOR EACH ROW EXECUTE PROCEDURE radverkehr.update_radweg();