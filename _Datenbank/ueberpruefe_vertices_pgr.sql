-- Punkte verschmelzen
update radverkehr.o_radweg set geometrie = ST_SetPoint(geometrie,0,s.geom), source = s.k from (
select distinct on (f.id) f.id f, k.id k, k.the_geom geom from radverkehr.o_radweg_vertices_pgr f, radverkehr.o_radweg_vertices_pgr k
where f.cnt = 1 and k.cnt > 1 and not st_within(f.the_geom,(select st_union(geom) from radverkehr.bearbeitung where not fertig)) 
and st_dwithin(f.the_geom, k.the_geom, 0.3) order by f.id, k.id, st_distance(f.the_geom, k.the_geom) asc) s
where source = s.f;

update radverkehr.o_radweg set geometrie = ST_SetPoint(geometrie,-1,s.geom), target = s.k from (
select distinct on (f.id) f.id f, k.id k, k.the_geom geom from radverkehr.o_radweg_vertices_pgr f, radverkehr.o_radweg_vertices_pgr k
where f.cnt = 1 and k.cnt > 1 and not st_within(f.the_geom,(select st_union(geom) from radverkehr.bearbeitung where not fertig)) 
and st_dwithin(f.the_geom, k.the_geom, 0.3) order by f.id, k.id, st_distance(f.the_geom, k.the_geom) asc) s
where target = s.f;


delete from radverkehr.o_radweg_vertices_pgr where the_geom is null;
delete from radverkehr.o_radweg where geometrie is null;
delete from radverkehr.o_radweg where source=target and st_length(geometrie)<0.05;

update radverkehr.o_radweg set geometrie = st_makevalid(geometrie) where not st_isvalid(geometrie) and ST_GeometryType(st_makevalid(geometrie)) = 'ST_LineString'


DELETE FROM radverkehr.o_radweg where not st_isvalid(geometrie)

with
dichte as (select distinct v.id from radverkehr.o_radweg w, radverkehr.o_radweg_vertices_pgr v where st_dwithin(w.geometrie,v.the_geom,0.1) and v.id != w.source and v.id != w.target),
alle as (select v.id, v.chk alt, case when d.id is null then 0 else 1 end neu from radverkehr.o_radweg_vertices_pgr v left join dichte d on v.id = d.id),
zuaendern as (select * from alle where alt != neu)
update radverkehr.o_radweg_vertices_pgr set chk = zuaendern.neu from
zuaendern where zuaendern.id = o_radweg_vertices_pgr.id;

with 
punkte as (select radweg_id, target kid from radverkehr.o_radweg
union
select radweg_id, source kid from radverkehr.o_radweg),
anzahl as (select kid, count(*) cnt from punkte group by kid),
fehler as (select v.id kid, COALESCE(anzahl.cnt, 0) cnt from radverkehr.o_radweg_vertices_pgr v left join anzahl on anzahl.kid = v.id where COALESCE(anzahl.cnt, 0) != v.cnt)
update radverkehr.o_radweg_vertices_pgr set cnt = fehler.cnt from
fehler where fehler.kid = id;

delete from radverkehr.o_radweg_vertices_pgr where cnt = 0;

with 
punkte as (select radweg_id, target kid from radverkehr.o_radweg
union
select radweg_id, source kid from radverkehr.o_radweg where zweirichtung),
anzahl as (select kid, count(*) ein from punkte group by kid),
fehler as (select anzahl.* from anzahl, radverkehr.o_radweg_vertices_pgr v where anzahl.kid = v.id and anzahl.ein != v.ein)
update radverkehr.o_radweg_vertices_pgr set ein = fehler.ein from
fehler where fehler.kid = id;

with 
punkte as (select radweg_id, target kid from radverkehr.o_radweg where zweirichtung
union
select radweg_id, source kid from radverkehr.o_radweg),
anzahl as (select kid, count(*) eout from punkte group by kid),
fehler as (select anzahl.* from anzahl, radverkehr.o_radweg_vertices_pgr v where anzahl.kid = v.id and anzahl.eout != v.eout)
update radverkehr.o_radweg_vertices_pgr set eout = fehler.eout from
fehler where fehler.kid = id;




CREATE FUNCTION tmp_verschmelzen() RETURNS VOID AS
$BODY$
DECLARE
	wert record;
	counter integer := 0;
BEGIN
	LOOP
		wert := null;
		select a.radweg_id a, b.radweg_id b, ST_LineMerge(st_union(a.geometrie, b.geometrie)) geom
		into wert
		from radverkehr.o_radweg_vertices_pgr v, radverkehr.o_radweg a, radverkehr.o_radweg b where v.cnt = 2 and v.chk = 0 and a.target = v.id and b.source = v.id
		and a.zweirichtung = b.zweirichtung
		and a.name_id = b.name_id and
		a.radweg_art_id = b.radweg_art_id and
		a.breite = b.breite and
		a.status_id = b.status_id and
		a.niveau_id = b.niveau_id and
		a.oberflaeche_id = b.oberflaeche_id and
		a.quelle_id = b.quelle_id and
		a.id_in_quelle = b.id_in_quelle and
		a.hindernis_id = b.hindernis_id and
		a.radweg_id != b.radweg_id and 
		ST_GeometryType(ST_LineMerge(st_union(a.geometrie, b.geometrie))) = 'ST_LineString'
		limit 1;
		counter := counter +1;
		EXIT WHEN counter > 100;
		EXIT WHEN wert.geom is null;
		
		--select wert;

		update radverkehr.o_radweg set geometrie = wert.geom where radweg_id = wert.a;
		delete from radverkehr.o_radweg where radweg_id = wert.b;
		
		
	END LOOP;
END
$BODY$
LANGUAGE plpgsql;

select tmp_verschmelzen();
drop function tmp_verschmelzen;


CREATE OR REPLACE FUNCTION radwege_teilen() RETURNS INT AS
$BODY$
DECLARE
	vorher integer := 0;
BEGIN

	create temporary table tmp_sackgassen as

		--Sackgasse an Startpunkt
		select radweg_id sackgasse, v.id knoten, v.the_geom punkt, 0 pkt_nr from 
		radverkehr.o_radweg n, radverkehr.o_radweg_vertices_pgr v where (v.cnt = 1 or v.chk = 1) and
		n.source = v.id and not st_within(v.the_geom,(select st_union(geom) from radverkehr.bearbeitung where not fertig));

		--Sackgasse an Endpunkt
		insert into tmp_sackgassen
		select radweg_id sackgasse, v.id knoten, v.the_geom punkt, -1 pkt_nr from 
		radverkehr.o_radweg n, radverkehr.o_radweg_vertices_pgr v where (v.cnt = 1 or v.chk = 1) and
		n.target = v.id and not st_within(v.the_geom,(select st_union(geom) from radverkehr.bearbeitung where not fertig));
		
	LOOP
	
		vorher := (select count(*) from tmp_sackgassen);

		-- Linien teilen
		create temporary table tmp_abschnitte_teilen as
		with
		sackgassen_punkt as (select distinct on (s.sackgasse) knoten, s.sackgasse, ST_ClosestPoint(s.punkt,n.geometrie) punkt, pkt_nr, n.radweg_id abschnitt, n.geometrie
			from radverkehr.o_radweg n, tmp_sackgassen s 
			where n.niveau_id = '16e92518-4ca2-11ea-b082-02004c4f4f50' and 
			target != knoten and source != knoten and s.sackgasse != n.radweg_id and st_dwithin(n.geometrie, punkt, 0.3) 
			order by s.sackgasse, st_distance(n.geometrie, punkt)),
		distinct_abschnitt as 
			(select distinct on (abschnitt) * from sackgassen_punkt),
		splitting as 
			(select knoten, sackgasse, punkt, pkt_nr, abschnitt, st_dump(st_split(st_snap(geometrie, punkt, 0.3), punkt)) trennung from distinct_abschnitt)
		select knoten, sackgasse, punkt, pkt_nr, abschnitt, (trennung).geom geom, (trennung).path[1] nr from splitting;

		-- Teilungsvorschläge ohne Teilung entfernen
		delete from tmp_abschnitte_teilen where abschnitt in (
		select abschnitt from tmp_abschnitte_teilen group by abschnitt, sackgasse having max(nr) != 2 and count(*) != 2);

		-- Anzahl der Kanten des Knoten erhöhen
		--update schulweg_neu.routing_aktuell_vertices_pgr 
		--set cnt = cnt + 2, chk = 0 where id in (select knoten from tmp_abschnitte_teilen);
		
		-- Koordinaten des Knoten anpassen
		update radverkehr.o_radweg_vertices_pgr set
		the_geom = punkt
		from tmp_abschnitte_teilen where knoten = id;

		-- Eintrag des geteilten Abschnittes anpassen
		update radverkehr.o_radweg set
		target = knoten,
		geometrie = geom
		from tmp_abschnitte_teilen where abschnitt = radweg_id and nr = 1;

		-- neuen Eintrag für zweite Hälfte des geteilten Abschnittes
		insert into radverkehr.o_radweg (name_id,radweg_art_id, oberflaeche_id, breite,bemerkung,quelle_id,id_in_quelle,geometrie,status_id,niveau_id,create_date,create_user,hindernis_id,zweirichtung)
				select name_id,radweg_art_id, oberflaeche_id, breite,bemerkung,quelle_id,id_in_quelle, geom geometrie,status_id,niveau_id,create_date,create_user,hindernis_id,zweirichtung
				from tmp_abschnitte_teilen, radverkehr.o_radweg where abschnitt = radweg_id and nr = 2;
		
		-- Endpunkt des neu angebundenen Abschnittes anpassen
		-- TODO mitgezogene Abschnitte auch anpassen (alle Abschnitte, die Knoten verwenden, der verschoben wurde)
		update radverkehr.o_radweg set
		geometrie = st_setpoint(geometrie, pkt_nr, punkt)
		from tmp_abschnitte_teilen where sackgasse = radweg_id;

		-- bearbeitete Abschnitte aus Liste entfernen
		delete from tmp_sackgassen where knoten in (select knoten from tmp_abschnitte_teilen);
		vorher := vorher - (select count(*) from tmp_sackgassen);
		RAISE NOTICE '% Fehler behoben!', vorher;

		drop table if exists tmp_knoten_verschmelzen;
		drop table if exists tmp_abschnitte_teilen;
		
		EXIT WHEN vorher = 0;

		END LOOP;
		
		drop table if exists tmp_sackgassen;

    RETURN vorher;
END
$BODY$
LANGUAGE plpgsql;

SELECT * FROM radwege_teilen();



update radverkehr.o_radweg set geometrie = geometrie from 
	(select distinct e.radweg_id id from radverkehr.o_radweg e, radverkehr.o_radweg_vertices_pgr v 
	where (id = source and not st_dwithin(st_startpoint(e.geometrie), v.the_geom,0.10)) or
	 	(not st_dwithin(st_endpoint(e.geometrie), v.the_geom,0.10) and id = target)) s 
where s.id = radweg_id;