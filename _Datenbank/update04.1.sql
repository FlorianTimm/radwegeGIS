ALTER TABLE radverkehr.o_radweg DISABLE TRIGGER o_radweg_history;

alter table radverkehr.o_radweg add column zweirichtung boolean default false;
alter table radverkehr.o_radweg add column gid serial;
alter table radverkehr.o_radweg add column source integer default null;
alter table radverkehr.o_radweg add column target integer default null;
create unique index o_radweg_radweg_id on radverkehr.o_radweg(gid);
create index o_radweg_source on radverkehr.o_radweg(source);
create index o_radweg_target on radverkehr.o_radweg(target);

update radverkehr.o_radweg set zweirichtung = CASE WHEN richtung_id = 'c1f220bf-7def-11e9-a7aa-02004c4f4f50' THEN true
WHEN richtung_id = 'c1efbe7e-7def-11e9-a7a8-02004c4f4f50' THEN false
ELSE null END;

alter table radverkehr.o_radweg drop column richtung_id;

alter table radverkehr.v_radweg_route add column radweg_gid integer references radverkehr.o_radweg(gid);
update radverkehr.v_radweg_route set radweg_gid = (select gid from radverkehr.o_radweg where o_radweg.radweg_id = v_radweg_route.radweg_id)
alter table radverkehr.v_radweg_route drop column radweg_id;

alter table radverkehr.o_ausstattung add column radweg_gid integer references radverkehr.o_radweg(gid);
update radverkehr.o_ausstattung set radweg_gid = (select gid from radverkehr.o_radweg where o_radweg.radweg_id = o_ausstattung.radweg_id);
alter table radverkehr.o_ausstattung drop column radweg_id;

drop view timm.radverkehr_harburg;
drop view harburg;
DROP VIEW radverkehr.view_fuer_dienst;
DROP VIEW radverkehr.v_radweg;

drop index radverkehr.index_o_radweg_gid;
alter table radverkehr.o_radweg drop constraint o_radweg_pkey;
alter table radverkehr.o_radweg drop column radweg_id;
alter table radverkehr.o_radweg rename column gid to radweg_id;

alter table radverkehr.o_radweg add constraint o_radweg_pkey primary key (radweg_id);


CREATE OR REPLACE VIEW radverkehr.v_radweg
    AS
     SELECT a.radweg_id, 
    s.bezeichnung AS status,
    f.bezeichnung AS strassenname,
    b.bezeichnung AS radweg_art,
        CASE
            WHEN a.zweirichtung THEN 'in beide Richtungen'::text
            ELSE 'in Geometrie-Richtung'::text
        END AS richtung,
    d.bezeichnung AS oberflaeche,
    a.breite,
    g.bezeichnung AS hindernis,
    n.bezeichnung AS niveau,
    e.bezeichnung AS quelle,
    a.id_in_quelle,
    a.bemerkung,
    a.create_date,
    a.zweirichtung,
    a.radweg_art_id::character varying AS radweg_art_id,
	a.source,
	a.target,
	a.geometrie
   FROM (((((((radverkehr.o_radweg a
     LEFT JOIN radverkehr.kt_radweg_art b ON ((a.radweg_art_id = b.radweg_art_id)))
     LEFT JOIN radverkehr.kt_oberflaeche d ON ((a.oberflaeche_id = d.oberflaeche_id)))
     LEFT JOIN radverkehr.kt_status s ON ((a.status_id = s.status_id)))
     LEFT JOIN radverkehr.kt_niveau n ON ((a.niveau_id = n.niveau_id)))
     LEFT JOIN radverkehr.kt_quelle e ON ((a.quelle_id = e.quelle_id)))
     LEFT JOIN radverkehr.kt_strassenname f ON ((a.name_id = f.name_id)))
     LEFT JOIN radverkehr.kt_hindernis g ON ((a.hindernis_id = g.hindernis_id)));
	 
CREATE OR REPLACE VIEW radverkehr.view_fuer_dienst
    AS
     SELECT a.radweg_id,
    a.status,
    a.strassenname,
    a.radweg_art, 
    a.richtung,
    a.oberflaeche,
    a.breite,
    a.hindernis,
    a.niveau,
    a.zweirichtung,
    a.radweg_art_id::character varying AS radweg_art_id,
	a.source,
	a.target,
	a.geometrie
   FROM radverkehr.v_radweg a
  WHERE (st_intersects(a.geometrie, ( SELECT st_union(in_bearbeitung.geom) AS st_union
           FROM radverkehr.in_bearbeitung
          WHERE (in_bearbeitung.fertig AND in_bearbeitung.geprueft))) OR st_intersects(a.geometrie, ( SELECT st_union(stadtteil_status_geo.geom) AS st_union
           FROM radverkehr.stadtteil_status_geo
          WHERE (stadtteil_status_geo.status = 100))));
		  
		  
alter table radverkehr.o_radweg_history add column zweirichtung boolean default false;
alter table radverkehr.o_radweg_history add column gid serial;
alter table radverkehr.o_radweg_history add column source integer default null;
alter table radverkehr.o_radweg_history add column target integer default null;
alter table radverkehr.o_radweg_history drop column richtung_id;
alter table radverkehr.o_radweg_history drop constraint o_radweg_history_pkey;
alter table radverkehr.o_radweg_history drop column radweg_id;
alter table radverkehr.o_radweg_history rename column gid to radweg_id;

alter table radverkehr.o_radweg_history add constraint o_radweg_history_pkey primary key (radweg_id);
		  
drop table radverkehr.kt_richtung;

CREATE INDEX IF NOT EXISTS index_o_radweg_gist ON radverkehr.o_radweg USING gist (geometrie);


select pgr_createTopology('radverkehr.o_radweg', 0.1,'geometrie' , 'radweg_id' ,'source' ,'target', 'true', true);
select pgr_analyzeGraph('radverkehr.o_radweg', 0.1,'geometrie' , 'radweg_id' ,'source' ,'target', 'true');
select pgr_analyzeOneway('radverkehr.o_radweg',
	ARRAY['true'],
	ARRAY['false', 'true'],
	ARRAY['false', 'true'],
	ARRAY['true'],
	oneway:='zweirichtung');
	
delete from radverkehr.v_radweg_route where radweg_gid in (select radweg_id from radverkehr.o_radweg where geometrie is null);
delete from radverkehr.o_radweg where geometrie is null;

alter table radverkehr.o_radweg_vertices_pgr add column status boolean not null default false;

update radverkehr.o_radweg_vertices_pgr set status = true  where
(cnt = 1 or eout = 0 or ein = 0) and id in (select v.id id from radverkehr.o_radweg_vertices_pgr v,
radverkehr.sackgassen s where
st_dwithin(v.the_geom, s.the_geom, 0.1));



ALTER TABLE radverkehr.o_radweg ADD COLUMN len_out float default -1;
ALTER TABLE radverkehr.o_radweg ADD COLUMN len_in float default -1;
ALTER TABLE radverkehr.o_radweg ADD COLUMN sicherheit_in float default -1;
ALTER TABLE radverkehr.o_radweg ADD COLUMN sicherheit_out float default -1;
ALTER TABLE radverkehr.o_radweg ADD COLUMN zeit_in float default -1;
ALTER TABLE radverkehr.o_radweg ADD COLUMN zeit_out float default -1;

update radverkehr.o_radweg set 
len_in = s.len_in,
sicherheit_in = s.sicherheit_in,
zeit_in = s.zeit_in
from
(SELECT radweg_id,
ST_length(geometrie) len_in,
(ST_length(geometrie) * COALESCE(a.sicherheit, 1) * COALESCE(o.sicherheit, 1)) sicherheit_in, 
	CASE WHEN COALESCE(o.geschwindigkeit,15) > COALESCE(a.max_geschwindigkeit,30) 
		THEN ST_length(geometrie) / COALESCE(a.max_geschwindigkeit,30) 
		ELSE ST_length(geometrie) / COALESCE(o.geschwindigkeit,15) END zeit_in
	from  radverkehr.o_radweg w 
		left join radverkehr.kt_oberflaeche o on w.oberflaeche_id = o.oberflaeche_id
		left join radverkehr.kt_radweg_art a on w.radweg_art_id = a.radweg_art_id) s
where s.radweg_id = o_radweg.radweg_id;

update radverkehr.o_radweg set 
len_out = len_in,
sicherheit_out = sicherheit_in,
zeit_out = zeit_in
where zweirichtung;

ALTER TABLE radverkehr.o_radweg_history ADD COLUMN len_out float default -1;
ALTER TABLE radverkehr.o_radweg_history ADD COLUMN len_in float default -1;
ALTER TABLE radverkehr.o_radweg_history ADD COLUMN sicherheit_in float default -1;
ALTER TABLE radverkehr.o_radweg_history ADD COLUMN sicherheit_out float default -1;
ALTER TABLE radverkehr.o_radweg_history ADD COLUMN zeit_in float default -1;
ALTER TABLE radverkehr.o_radweg_history ADD COLUMN zeit_out float default -1;




CREATE OR REPLACE FUNCTION radverkehr.history()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    VOLATILE
    COST 100
AS $BODY$
DECLARE 
	target_id integer; 
	source_id integer;
	o_sicherheit float;
	o_geschwindigkeit float;
	a_sicherheit float;
	a_max_geschwindigkeit float;
BEGIN
		IF (TG_OP = 'DELETE' OR TG_OP = 'UPDATE') THEN
			UPDATE radverkehr.o_radweg_vertices_pgr set cnt = cnt -1, eout = eout - 1,
			ein = CASE WHEN OLD.zweirichtung THEN ein - 1 ELSE ein END, status = false where id = OLD.source;
			UPDATE radverkehr.o_radweg_vertices_pgr set cnt = cnt -1, ein = ein - 1,
			eout = CASE WHEN OLD.zweirichtung THEN eout - 1 ELSE eout END, status = false where id = OLD.target;
			
			update radverkehr.o_radweg_vertices_pgr set chk = 0 where st_dwithin(old.geometrie, o_radweg_vertices_pgr.the_geom, 0.5);

			update radverkehr.o_radweg_vertices_pgr set chk = 1 where id in (
			select distinct v.id from radverkehr.o_radweg w, radverkehr.o_radweg_vertices_pgr v 
			where st_dwithin(w.geometrie,v.the_geom,0.1) and v.id != w.source and v.id != w.target and st_dwithin(old.geometrie, v.the_geom, 1));
		END IF;
		
        IF (TG_OP = 'DELETE') THEN
			DELETE FROM radverkehr.v_radweg_route WHERE v_radweg_route.radweg_gid = OLD.radweg_id;
            INSERT INTO radverkehr.o_radweg_history SELECT uuid_generate_v1(), 'D', now(), current_user, OLD.*;
			DELETE FROM radverkehr.o_radweg_vertices_pgr where cnt = 0;
			RETURN OLD;
		ELSIF (TG_OP = 'UPDATE') THEN
            INSERT INTO radverkehr.o_radweg_history SELECT uuid_generate_v1(), 'U', now(), current_user, OLD.*;
        ELSIF (TG_OP = 'INSERT') THEN
			IF (NEW.name_id IS NULL) THEN 
				NEW.name_id = (select k.name_id from (
					select strassenname from (
						select strassenname, ST_Length(ST_Intersection(s.geom, NEW.geometrie))/ST_Length(NEW.geometrie) len from 
						radverkehr.strassenname_area s where ST_Intersects(s.geom, NEW.geometrie)
					) i group by strassenname having sum(len) > 0.5
				) r inner join radverkehr.kt_strassenname k on r.strassenname = k.bezeichnung);
			END IF;
			NEW.create_date = now();
			NEW.create_user = current_user;
        END IF;
		
		
		
		NEW.geometrie = ST_SimplifyPreserveTopology(NEW.geometrie, 0.1);
		NEW.update_date = now();
		NEW.update_user = current_user;
		
		target_id := null;
		source_id := null;
		
		source_id := (SELECT id FROM radverkehr.o_radweg_vertices_pgr where ST_DWithin(the_geom, ST_StartPoint(NEW.geometrie),0.1) ORDER BY ST_DISTANCE(the_geom, ST_StartPoint(NEW.geometrie)) ASC LIMIT 1);
		target_id := (SELECT id FROM radverkehr.o_radweg_vertices_pgr where ST_DWithin(the_geom, ST_EndPoint(NEW.geometrie),0.1) ORDER BY ST_DISTANCE(the_geom, ST_EndPoint(NEW.geometrie)) ASC LIMIT 1);
		
		IF (source_id is null) THEN
			INSERT INTO radverkehr.o_radweg_vertices_pgr (the_geom, cnt, chk, ein, eout) 
			values (ST_StartPoint(NEW.geometrie),0,0, 0, 0) RETURNING id into source_id;
		END IF;
		IF (target_id is null) THEN
			INSERT INTO radverkehr.o_radweg_vertices_pgr (the_geom, cnt, chk, ein, eout) 
			values (ST_EndPoint(NEW.geometrie),0,0, 0, 0) RETURNING id into target_id;
		END IF;
		
		new.source = source_id;
		new.target = target_id;
		
		UPDATE radverkehr.o_radweg_vertices_pgr set cnt = cnt +1, eout = eout + 1,
		ein = CASE WHEN NEW.zweirichtung THEN ein + 1 ELSE ein END, status = false where id = source_id;
		UPDATE radverkehr.o_radweg_vertices_pgr set cnt = cnt +1, ein = ein + 1,
		eout = CASE WHEN NEW.zweirichtung THEN eout + 1 ELSE eout END, status = false where id = target_id;
		
		update radverkehr.o_radweg_vertices_pgr set chk = 0 where st_dwithin(new.geometrie, o_radweg_vertices_pgr.the_geom, 0.5);

		update radverkehr.o_radweg_vertices_pgr set chk = 1 where id in (
		select distinct v.id from radverkehr.o_radweg w, radverkehr.o_radweg_vertices_pgr v 
		where st_dwithin(w.geometrie,v.the_geom,0.1) and v.id != w.source and v.id != w.target and st_dwithin(new.geometrie, v.the_geom, 1));

		DELETE FROM radverkehr.o_radweg_vertices_pgr where cnt = 0;
		
		NEW.len_out = -1;
		NEW.sicherheit_out = -1;
		NEW.zeit_out = -1;
		
		IF (NEW.oberflaeche_id is not null) THEN
			SELECT sicherheit FROM radverkehr.kt_oberflaeche WHERE NEW.oberflaeche_id = oberflaeche_ID into o_sicherheit;
			SELECT geschwindigkeit FROM radverkehr.kt_oberflaeche WHERE NEW.oberflaeche_id = oberflaeche_ID into o_geschwindigkeit;
		END IF;
		
		IF (NEW.radweg_art_id is not null) THEN
			SELECT sicherheit FROM radverkehr.kt_radweg_art WHERE NEW.radweg_art_id = radweg_art_id into a_sicherheit;
			SELECT max_geschwindigkeit FROM radverkehr.kt_radweg_art WHERE NEW.radweg_art_id = radweg_art_id into a_max_geschwindigkeit;
		END IF;		
		
		NEW.len_in = ST_length(new.geometrie);
		NEW.sicherheit_in = (NEW.len_in * COALESCE(a_sicherheit, 1) * COALESCE(o_sicherheit, 1));
		NEW.zeit_in = (CASE WHEN COALESCE(o_geschwindigkeit,15) > COALESCE(a_max_geschwindigkeit,30) THEN NEW.len_in / COALESCE(a_max_geschwindigkeit,30) ELSE NEW.len_in / COALESCE(o_geschwindigkeit,15) END);
		
		IF NEW.zweirichtung THEN 
			NEW.len_out = NEW.len_in;
			NEW.sicherheit_out = NEW.sicherheit_in;
			NEW.zeit_out = NEW.zeit_in;
		END IF;
		
        RETURN NEW;
    END;
$BODY$;

ALTER TABLE radverkehr.o_radweg ENABLE TRIGGER o_radweg_history;


select g.id, g.bearbeiter, count(f.*) from radverkehr.bearbeitung g, radverkehr.o_radweg_vertices_pgr f 
where (((f.cnt <= 1 or f.ein = 0 or f.eout = 0) and not f.status) or chk = 1) and g.geprueft and st_within(f.the_geom,g.geom) group by g.id,g.bearbeiter;


CREATE OR REPLACE VIEW radverkehr.in_bearbeitung
    AS
     SELECT b.id, 
    b.geom,
    b.bearbeiter,
    b.datum,
	((USER)::text = b.bearbeiter) AS selbst,
    b.fertig,
    b.geprueft,
	--count(v.*) 
	0::bigint verbindungsfehler
   FROM radverkehr.bearbeitung b --left join radverkehr.o_radweg_vertices_pgr v
 -- on (((v.cnt = 1 or v.ein = 0 or v.eout = 0) and not status) or v.chk != 0) and ST_Within(v.the_geom,b.geom)
   --GROUP BY b.id, 
   -- b.geom,
   -- b.bearbeiter,
   -- b.datum,
   -- b.fertig,
   -- b.geprueft
UNION
 SELECT (- st_dump.path[1]) AS id,
    (st_dump.geom)::geometry(Polygon,25832) AS geom,
    'keiner'::text AS bearbeiter,
    (now())::timestamp without time zone AS datum,
    false AS selbst,
    false AS fertig,
    false AS geprueft,
	0 as verbindungsfehler
   FROM st_dump(st_difference(( SELECT st_union(bezirke.geom) AS st_union
           FROM geobasis.bezirke), ( SELECT st_union(bearbeitung.geom) AS st_union
           FROM radverkehr.bearbeitung))) st_dump(path, geom);
		   
		   
