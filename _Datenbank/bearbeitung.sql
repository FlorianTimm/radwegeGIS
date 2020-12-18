drop table radverkehr.bearbeitung;
create table radverkehr.bearbeitung (
	id serial primary key,
	geom geometry(polygon, 25832) not null,
	bearbeiter text default user,
	datum timestamp default now());

create view radverkehr.in_bearbeitung as 
 SELECT bearbeitung.id,
    bearbeitung.geom,
    bearbeitung.bearbeiter,
    bearbeitung.datum,
    USER::text = bearbeitung.bearbeiter AS selbst,
    bearbeitung.fertig
   FROM radverkehr.bearbeitung
UNION
 SELECT - st_dump.path[1] AS id,
    st_dump.geom::geometry(Polygon,25832) AS geom,
    'keiner'::text AS bearbeiter,
    now()::timestamp without time zone AS datum,
    false AS selbst,
    false AS fertig
   FROM st_dump(st_difference(( SELECT st_union(bezirke.geom) AS st_union
           FROM geobasis.bezirke), ( SELECT st_union(bearbeitung.geom) AS st_union
           FROM radverkehr.bearbeitung))) st_dump(path, geom);

create rule _insert as on 
insert to radverkehr.in_bearbeitung
do instead insert into radverkehr.bearbeitung (geom) values (new.geom) RETURNING
           bearbeitung.*, true;

create rule _update as on 
update to radverkehr.in_bearbeitung
do instead update radverkehr.bearbeitung set geom=new.geom where id = old.id;

create rule _delete as on 
delete to radverkehr.in_bearbeitung
do instead delete from radverkehr.bearbeitung where id = old.id and bearbeiter = user;