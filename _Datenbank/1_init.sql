-- Erweiterung zur Erzeugung von UUIDs 
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Ggf. alte Loeschen
DROP TABLE IF EXISTS radverkehr.v_radweg_route;

DROP TABLE IF EXISTS radverkehr.o_radroute;
DROP TABLE IF EXISTS radverkehr.o_ausstattung;
DROP TABLE IF EXISTS radverkehr.o_radweg;

DROP TABLE IF EXISTS radverkehr.kt_routenklasse;
DROP TABLE IF EXISTS radverkehr.kt_ausstattungsart;
DROP TABLE IF EXISTS radverkehr.kt_radweg_art;
DROP TABLE IF EXISTS radverkehr.kt_richtung;
DROP TABLE IF EXISTS radverkehr.kt_oberflaeche;

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

CREATE TABLE IF NOT EXISTS radverkehr.kt_oberflaeche (
	oberflaeche_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text
);


-- Objekte

CREATE TABLE IF NOT EXISTS radverkehr.o_radweg (
	radweg_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	wegenummer varchar (6),
	laenge float,
	radweg_art_id UUID REFERENCES radverkehr.kt_radweg_art(radweg_art_id),
	richtung_id UUID REFERENCES radverkehr.kt_richtung(richtung_id),
	oberflaeche_id UUID REFERENCES radverkehr.kt_oberflaeche(oberflaeche_id),
	breite integer,
	geometrie geometry(LINESTRING,25832) NOT NULL
);

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
	radweg_id UUID REFERENCES radverkehr.o_radweg(radweg_id),
	bezeichnung varchar(200),
	ausstattungsart_id UUID NOT NULL REFERENCES radverkehr.kt_ausstattungsart(ausstattungsart_id),
	betreiber text,
	kontakt text
);

CREATE TABLE IF NOT EXISTS radverkehr.v_radweg_route (
	weg_route_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	radweg_id UUID NOT NULL REFERENCES radverkehr.o_radweg(radweg_id),
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