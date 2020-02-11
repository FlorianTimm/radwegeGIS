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

CREATE TABLE IF NOT EXISTS radverkehr.o_radweg (
	radweg_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	name_id UUID REFERENCES radverkehr.kt_strassenname(name_id),
	radweg_art_id UUID REFERENCES radverkehr.kt_radweg_art(radweg_art_id),
	richtung_id UUID REFERENCES radverkehr.kt_richtung(richtung_id),
	oberflaeche_id UUID REFERENCES radverkehr.kt_oberflaeche(oberflaeche_id),
	breite NUMERIC(5,3) check (breite > 0),
	status_id UUID REFERENCES radverkehr.kt_status(status_id),
	niveau_id UUID REFERENCES radverkehr.kt_niveau(niveau_id),
	bemerkung text,
	quelle_id UUID REFERENCES radverkehr.kt_quelle(quelle_id),
	id_in_quelle varchar(100),
	geometrie geometry(LINESTRING,25832) NOT NULL,
	create_date timestamp without time zone not null,
	update_date timestamp without time zone CHECK (create_date < archive_date),
	create_user text,
	update_user text
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
	
-- Historische Tabelle
CREATE TABLE IF NOT EXISTS radverkehr.o_radweg_history (
	id uuid PRIMARY KEY default uuid_generate_v1(),
    operation char(1) NOT NULL,
    stamp timestamp without time zone NOT NULL,
    userid text NOT NULL,
	radweg_id UUID NOT NULL,
	name_id UUID REFERENCES radverkehr.kt_strassenname(name_id),
	radweg_art_id UUID REFERENCES radverkehr.kt_radweg_art(radweg_art_id),
	richtung_id UUID REFERENCES radverkehr.kt_richtung(richtung_id),
	oberflaeche_id UUID REFERENCES radverkehr.kt_oberflaeche(oberflaeche_id),
	breite NUMERIC(5,3) check (breite > 0),
	bemerkung text,
	quelle_id UUID REFERENCES radverkehr.kt_quelle(quelle_id),
	id_in_quelle varchar(100),
	geometrie geometry(LINESTRING,25832) NOT NULL,
	status_id UUID REFERENCES radverkehr.kt_status(status_id),
	niveau_id UUID REFERENCES radverkehr.kt_niveau(niveau_id),
	create_date timestamp without time zone not null,
	create_user text,
	update_date timestamp without time zone CHECK (create_date <= update_date),
	update_user text
);

-- Trigger
CREATE OR REPLACE FUNCTION radverkehr.history() RETURNS TRIGGER AS 
$func$
    BEGIN
        IF (TG_OP = 'DELETE') THEN
            INSERT INTO radverkehr.o_radweg_history SELECT uuid_generate_v1(), 'D', now(), current_user, OLD.*;
			RETURN OLD;
        ELSIF (TG_OP = 'UPDATE') THEN
            INSERT INTO radverkehr.o_radweg_history SELECT uuid_generate_v1(), 'U', now(), current_user, OLD.*;
			NEW.update_date = now();
			NEW.update_user = current_user;
        ELSIF (TG_OP = 'INSERT') THEN
			NEW.create_date = now();
			NEW.create_user = current_user;
            NEW.update_date = now();
			NEW.update_user = current_user;
        END IF;
        RETURN NEW;
    END;
$func$ 
LANGUAGE plpgsql;

CREATE TRIGGER o_radweg_history
BEFORE INSERT OR UPDATE OR DELETE ON radverkehr.o_radweg
    FOR EACH ROW EXECUTE PROCEDURE radverkehr.history();

