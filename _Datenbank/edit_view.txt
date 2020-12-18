 alter table radverkehr.o_radweg alter column zweirichtung set default false;
 select * from 
 
 CREATE OR REPLACE VIEW radverkehr.o_radweg_edit
    AS
     SELECT o_radweg.name_id, 
    o_radweg.radweg_art_id,
    o_radweg.oberflaeche_id,
    o_radweg.breite,
    o_radweg.bemerkung,
    o_radweg.quelle_id,
    o_radweg.id_in_quelle,
    o_radweg.geometrie,
    o_radweg.status_id,
    o_radweg.niveau_id,
    o_radweg.create_date,
    o_radweg.create_user,
    o_radweg.update_date,
    o_radweg.update_user,
    o_radweg.hindernis_id,
    o_radweg.zweirichtung,
    o_radweg.radweg_id
   FROM radverkehr.o_radweg
  WHERE st_intersects(o_radweg.geometrie, ( SELECT st_union(bearbeitung.geom) AS st_union
           FROM radverkehr.bearbeitung
          WHERE ((bearbeitung.bearbeiter = (USER)::text) AND (bearbeitung.fertig = false))));
		  
CREATE OR REPLACE RULE _INSERT AS ON INSERT TO radverkehr.o_radweg_edit
    DO INSTEAD
    INSERT INTO radverkehr.o_radweg VALUES (
    	new.name_id,
		new.radweg_art_id,
		new.oberflaeche_id,
		new.breite,
		new.bemerkung,
		new.quelle_id,
		new.id_in_quelle,
		new.geometrie,
		new.status_id,
		new.niveau_id,
		new.create_date,
		new.create_user,
		new.update_date,
		new.update_user,
		new.hindernis_id,
		new.zweirichtung)
	RETURNING 
		o_radweg.name_id, 
		o_radweg.radweg_art_id,
		o_radweg.oberflaeche_id,
		o_radweg.breite,
		o_radweg.bemerkung,
		o_radweg.quelle_id,
		o_radweg.id_in_quelle,
		o_radweg.geometrie,
		o_radweg.status_id,
		o_radweg.niveau_id,
		o_radweg.create_date,
		o_radweg.create_user,
		o_radweg.update_date,
		o_radweg.update_user,
		o_radweg.hindernis_id,
		o_radweg.zweirichtung,
		o_radweg.radweg_id;

CREATE OR REPLACE RULE _UPDATE AS ON UPDATE TO radverkehr.o_radweg_edit
    DO INSTEAD
    UPDATE radverkehr.o_radweg
       SET 
		name_id = new.name_id,
		radweg_art_id = new.radweg_art_id,
		oberflaeche_id = new.oberflaeche_id,
		breite = new.breite,
		bemerkung = new.bemerkung,
		quelle_id = new.quelle_id,
		id_in_quelle = new.id_in_quelle,
		geometrie = new.geometrie,
		status_id = new.status_id,
		niveau_id = new.niveau_id,
		create_date = new.create_date,
		create_user = new.create_user,
		update_date = new.update_date,
		update_user = new.update_user,
		hindernis_id = new.hindernis_id,
		zweirichtung = new.zweirichtung,
		radweg_id = new.radweg_id
     WHERE radweg_id = OLD.radweg_id;

CREATE OR REPLACE RULE _DELETE AS ON DELETE TO radverkehr.o_radweg_edit
    DO INSTEAD
    DELETE FROM radverkehr.o_radweg
     WHERE radweg_id = OLD.radweg_id;