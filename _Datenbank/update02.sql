
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

	
alter table radverkehr.o_radweg add column status_id uuid REFERENCES radverkehr.kt_status(status_id);
alter table radverkehr.o_radweg add column niveau_id uuid REFERENCES radverkehr.kt_niveau(niveau_id);

alter table radverkehr.o_radweg add column create_date timestamp without time zone default now();
alter table radverkehr.o_radweg add column create_user text;
alter table radverkehr.o_radweg add column update_date timestamp without time zone default now() CHECK (create_date <= update_date);
alter table radverkehr.o_radweg add column update_user text;

alter table radverkehr.o_radweg alter column breite SET DATA TYPE NUMERIC(5,3);
alter table radverkehr.o_radweg add constraint o_radweg_positive_breite check (breite > 0);

update radverkehr.o_radweg set create_user = 'import',  update_user = 'import', status_id = (SELECT status_id from radverkehr.kt_status where bezeichnung = 'Betrieb');

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

