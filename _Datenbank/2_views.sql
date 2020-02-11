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

--Dienst
create or replace view radverkehr.v_radweg as
select 
	radweg_id, 
	f.bezeichnung strassenname, 
	b.bezeichnung radweg_art, 
	c.bezeichnung richtung, 
	d.bezeichnung oberflaeche,
	s.bezeichnung status,
	n.bezeichnung niveau,
	e.bezeichnung quelle,
	id_in_quelle,
	breite, 
	geometrie,
	create_date
from radverkehr.o_radweg a
left join radverkehr.kt_radweg_art b on a.radweg_art_id = b.radweg_art_id
left join radverkehr.kt_richtung c on a.richtung_id = c.richtung_id
left join radverkehr.kt_oberflaeche d on a.oberflaeche_id = d.oberflaeche_id
left join radverkehr.kt_status s on a.status_id = s.status_id
left join radverkehr.kt_niveau n on a.niveau_id = n.niveau_id
left join radverkehr.kt_quelle e on a.quelle_id = e.quelle_id
left join radverkehr.kt_strassenname f on a.name_id = f.name_id;