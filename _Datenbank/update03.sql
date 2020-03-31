create table radverkehr.kt_hindernis (
	hindernis_id UUID NOT NULL DEFAULT uuid_generate_v1() PRIMARY KEY,
	bezeichnung varchar(200) NOT NULL UNIQUE,
	beschreibung text
);

INSERT INTO radverkehr.kt_hindernis (bezeichnung, beschreibung) VALUES
	('Durchfahrbarkeit gegegeben','Durchfahrbarkeit mit einem Meter breiten Fahrzeug gegeben'),
	('Umfahrung möglich', 'Hindernis mit Durchfahrbarkeit gegeben, aber Umfahrung (z.B. Radweg, Straße) unkompliziert möglich'),
	('nicht durchfahrbar', 'Hindernisse, die nicht umfahren werden können (Nutzung einer anderen Geometrie notwendig)');

alter table radverkehr.o_radweg add column hindernis_id uuid REFERENCES radverkehr.kt_hindernis(hindernis_id);
alter table radverkehr.o_radweg_history add column hindernis_id uuid REFERENCES radverkehr.kt_hindernis(hindernis_id);

insert into radverkehr.kt_radweg_art (bezeichnung) VALUES ('Wege in Grünflächen');

update radverkehr.o_radweg set radweg_art_id = (select radweg_art_id from radverkehr.kt_radweg_art where bezeichnung = 'Wege in Grünflächen')
	where update_user = 'import' and id_in_quelle in (select concat (vnk, ' ', nnk) anz from sib_import.kanten where wegeart = 'G')

update radverkehr.o_radweg set hindernis_id = 
	(SELECT hindernis_id FROM radverkehr.kt_hindernis WHERE bezeichnung = 'Durchfahrbarkeit gegegeben')
	where radweg_art_id in (select radweg_art_id from radverkehr.kt_radweg_art where bezeichnung LIKE 'Straße %')
	
alter table radverkehr.kt_radweg_art add column kurzbezeichnung character varying (150);
update radverkehr.kt_radweg_art set kurzbezeichnung = bezeichnung;

update radverkehr.o_radweg set name_id = null where name_id = 'd0fdd215-4acc-4c6f-bc86-5c3c813c1607';
update radverkehr.o_radweg_history set name_id = null where name_id = 'd0fdd215-4acc-4c6f-bc86-5c3c813c1607';
delete from radverkehr.kt_strassenname where name_id = 'd0fdd215-4acc-4c6f-bc86-5c3c813c1607';



alter table radverkehr.kt_oberflaeche add column sicherheit numeric(3,2) default 1.0;
alter table radverkehr.kt_oberflaeche add column geschwindigkeit integer default 15;

alter table radverkehr.kt_radweg_art add column sicherheit numeric(3,2) default 1.0;
alter table radverkehr.kt_radweg_art add column max_geschwindigkeit integer default 30;

alter table radverkehr.routing_vertices_pgr add column status smallint default 0;
create table radverkehr.sackgassen as select cnt, chk, ein, eout, the_geom
	from radverkehr.routing_vertices_pgr 
	where status = 1;

CREATE OR REPLACE FUNCTION radverkehr.refresh_routing() RETURNS void AS $$
	BEGIN
		insert into radverkehr.sackgassen (cnt, chk, ein, eout, the_geom)
		select cnt, chk, ein, eout, the_geom
		from radverkehr.routing_vertices_pgr 
		where geprueft = true;

		drop table radverkehr.routing;
		drop table radverkehr.routing_vertices_pgr;
		create table radverkehr.routing as 
			select w.*, 
			-1.0 len_out,
			len_in * COALESCE(a.sicherheit, 1) * COALESCE(o.sicherheit, 1) sicherheit_in, 
			-1.0 sicherheit_out,
			CASE WHEN COALESCE(o.geschwindigkeit,15) > COALESCE(a.max_geschwindigkeit,30) 
				THEN len_in / COALESCE(a.max_geschwindigkeit,30) 
				ELSE len_in / COALESCE(o.geschwindigkeit,15) END zeit_in,
			-1.0 zeit_out
			from (select *, st_length(geometrie) len_in from radverkehr.o_radweg) w 
				left join radverkehr.kt_oberflaeche o on w.oberflaeche_id = o.oberflaeche_id
				left join radverkehr.kt_radweg_art a on w.radweg_art_id = a.radweg_art_id;
		alter table radverkehr.routing add column id serial;
		alter table radverkehr.routing add column source integer;
		alter table radverkehr.routing add column target integer;
		update radverkehr.routing set len_out = len_in, zeit_out = zeit_in, sicherheit_out = sicherheit_in where richtung_id = 'c1f220bf-7def-11e9-a7aa-02004c4f4f50';
		commit;
		select pgr_createTopology('radverkehr.routing', 0.1,'geometrie' , 'id' ,'source' ,'target', 'true', true);
		select pgr_analyzeGraph('radverkehr.routing', 0.1,'geometrie' , 'id' ,'source' ,'target', 'true');
		select pgr_analyzeOneway('radverkehr.routing',
			ARRAY['c1f220bf-7def-11e9-a7aa-02004c4f4f50'],
			ARRAY['c1efbe7e-7def-11e9-a7a8-02004c4f4f50', 'c1f220bf-7def-11e9-a7aa-02004c4f4f50'],
			ARRAY['c1efbe7e-7def-11e9-a7a8-02004c4f4f50', 'c1f220bf-7def-11e9-a7aa-02004c4f4f50'],
			ARRAY['c1f220bf-7def-11e9-a7aa-02004c4f4f50'],
			oneway:='richtung_id');

		delete from radverkehr.routing_vertices_pgr where id in (
			select k.id from radverkehr.sackgassen s
				left join radverkehr.routing_vertices_pgr k
				on 
				s.cnt = k.cnt and
				s.chk = k.chk and
				s.ein = k.ein and
				s.eout = k.eout and
				k.the_geom = s.the_geom);
	
		select '';
	END;
$$ LANGUAGE plpgsql;

select radverkehr.refresh_routing();


create or replace view radverkehr.v_radweg as
 SELECT a.radweg_id::varchar,
	s.bezeichnung AS status,
    f.bezeichnung AS strassenname,
    b.bezeichnung AS radweg_art,
    c.bezeichnung AS richtung,
    d.bezeichnung AS oberflaeche,
	a.breite,
	g.bezeichnung AS hindernis,
	n.bezeichnung AS niveau,
    e.bezeichnung AS quelle,
    a.id_in_quelle,
	a.bemerkung,
    a.geometrie,
    a.create_date,
	a.richtung_id::varchar,
	a.radweg_art_id::varchar
   FROM radverkehr.o_radweg a
     LEFT JOIN radverkehr.kt_radweg_art b ON a.radweg_art_id = b.radweg_art_id
     LEFT JOIN radverkehr.kt_richtung c ON a.richtung_id = c.richtung_id
     LEFT JOIN radverkehr.kt_oberflaeche d ON a.oberflaeche_id = d.oberflaeche_id
     LEFT JOIN radverkehr.kt_status s ON a.status_id = s.status_id
     LEFT JOIN radverkehr.kt_niveau n ON a.niveau_id = n.niveau_id
     LEFT JOIN radverkehr.kt_quelle e ON a.quelle_id = e.quelle_id
     LEFT JOIN radverkehr.kt_strassenname f ON a.name_id = f.name_id
	 LEFT JOIN radverkehr.kt_hindernis g ON a.hindernis_id = g.hindernis_id;
	 
	 
update radverkehr.o_radweg set geometrie = ST_Simplify(geometrie,0.1) where ST_Npoints(geometrie) > ST_NPoints(ST_Simplify(geometrie,0.1));
	 