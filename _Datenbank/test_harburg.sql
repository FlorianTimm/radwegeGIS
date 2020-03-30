insert into radverkehr.sackgassen (cnt, chk, ein, eout, the_geom)
	select cnt, chk, ein, eout, the_geom
	from radverkehr.routing_vertices_pgr 
	where geprueft = true;
	
truncate radverkehr.routing;
truncate radverkehr.routing_vertices_pgr;
 
insert into radverkehr.routing 
	(radweg_id, 
	name_id, 
	radweg_art_id, 
	richtung_id, 
	oberflaeche_id, 
	breite,
	bemerkung, 
	quelle_id,
	id_in_quelle,
	geometrie,
	status_id,
	niveau_id,
	create_date,
	create_user, 
	update_date,
	update_user,
	hindernis_id,
	len_out,
	len_in,
	sicherheit_in,
	sicherheit_out,
	zeit_in,
	zeit_out)
select 
	w.radweg_id, 
	w.name_id, 
	w.radweg_art_id, 
	w.richtung_id, 
	w.oberflaeche_id, 
	w.breite,
	w.bemerkung, 
	w.quelle_id,
	w.id_in_quelle,
	w.geometrie,
	w.status_id,
	w.niveau_id,
	w.create_date,
	w.create_user, 
	w.update_date,
	w.update_user,
	w.hindernis_id,
	-1.0 len_out,
	len_in,
	(len_in * COALESCE(a.sicherheit, 1) * COALESCE(o.sicherheit, 1)) sicherheit_in, 
	-1.0 sicherheit_out,
	CASE WHEN COALESCE(o.geschwindigkeit,15) > COALESCE(a.max_geschwindigkeit,30) 
		THEN len_in / COALESCE(a.max_geschwindigkeit,30) 
		ELSE len_in / COALESCE(o.geschwindigkeit,15) END zeit_in,
	-1.0 zeit_out
	from (
		select *, st_length(geometrie) len_in from radverkehr.o_radweg 
		where ST_intersects(geometrie, (select st_buffer(st_union(geom),250) from bezirke.stadtteile where stadtteil in ('Harburg','Wilstorf','Neuland','Gut Moor', 'Eißendorf')))
	) w 
		left join radverkehr.kt_oberflaeche o on w.oberflaeche_id = o.oberflaeche_id
		left join radverkehr.kt_radweg_art a on w.radweg_art_id = a.radweg_art_id;
		
update radverkehr.routing set len_out = len_in, zeit_out = zeit_in, sicherheit_out = sicherheit_in where richtung_id = 'c1f220bf-7def-11e9-a7aa-02004c4f4f50';

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