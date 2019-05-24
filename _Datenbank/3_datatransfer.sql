truncate radverkehr.o_radweg CASCADE;
alter table radverkehr.o_radweg add column old_id integer default null;
insert into radverkehr.o_radweg (old_id, geometrie, laenge, richtung_id) 
SELECT gid, ST_AddMeasure(ST_LineMerge(geom), 0, ST_Length(geom)), ST_Length(geom), (SELECT richtung_id FROM radverkehr.kt_richtung where bezeichnung = 'in Geometrie-Richtung') FROM radverkehr.velorouten;

truncate radverkehr.o_radroute CASCADE;						   
insert into radverkehr.o_radroute (bezeichnung, beschreibung, hyperlink, klasse_id)
select 
CONCAT('Veloroute ',fuer, ' ', richtung), comment, link_url, (select r.klasse_id from radverkehr.kt_routenklasse r where r.bezeichnung = 'Veloroute')
from radverkehr.metadaten where fuer <> 'alle';
													  
truncate radverkehr.v_radweg_route;
insert into radverkehr.v_radweg_route (radweg_id, radroute_id)
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 1 einwärts')
from radverkehr.velorouten where ein01a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 1 auswärts')
from radverkehr.velorouten where aus01a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 1a einwärts')
from radverkehr.velorouten where ein01b is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 1a auswärts')
from radverkehr.velorouten where aus01b is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 2 einwärts')
from radverkehr.velorouten where ein02 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 2 auswärts')
from radverkehr.velorouten where aus02 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 3 einwärts')
from radverkehr.velorouten where ein03 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 3 auswärts')
from radverkehr.velorouten where aus03 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 4 einwärts')
from radverkehr.velorouten where ein04 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 4 auswärts')
from radverkehr.velorouten where aus04 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 5 einwärts')
from radverkehr.velorouten where ein05a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 5 auswärts')
from radverkehr.velorouten where aus05a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 5a einwärts')
from radverkehr.velorouten where ein05b is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 5a auswärts')
from radverkehr.velorouten where aus05b is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 6 einwärts')
from radverkehr.velorouten where ein06 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 6 auswärts')
from radverkehr.velorouten where aus06 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 7 einwärts')
from radverkehr.velorouten where ein07a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 7 auswärts')
from radverkehr.velorouten where aus07a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 7a einwärts')
from radverkehr.velorouten where ein07b is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 7a auswärts')
from radverkehr.velorouten where aus07b is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 8 einwärts')
from radverkehr.velorouten where ein08a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 8 auswärts')
from radverkehr.velorouten where aus08a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 8a einwärts')
from radverkehr.velorouten where ein08b is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 8a auswärts')
from radverkehr.velorouten where aus08b is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 9 einwärts')
from radverkehr.velorouten where ein09 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 9 auswärts')
from radverkehr.velorouten where aus09 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 10 einwärts')
from radverkehr.velorouten where ein10 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 10 auswärts')
from radverkehr.velorouten where aus10 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 11 einwärts')
from radverkehr.velorouten where ein11 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 11 auswärts')
from radverkehr.velorouten where aus11 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 11a einwärts')
from radverkehr.velorouten where ein11a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 11a auswärts')
from radverkehr.velorouten where aus11a is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 12 einwärts')
from radverkehr.velorouten where ein12 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 12 auswärts')
from radverkehr.velorouten where aus12 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 12 einwärts')
from radverkehr.velorouten where ein12 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 12 auswärts')
from radverkehr.velorouten where aus12 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 13 einwärts')
from radverkehr.velorouten where ein13 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 13 auswärts')
from radverkehr.velorouten where aus13 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 14 einwärts')
from radverkehr.velorouten where ein14 is not null
union
select 
(select radweg_id from radverkehr.o_radweg where gid = old_id),
(select radroute_id from radverkehr.o_radroute where bezeichnung = 'Veloroute 14 auswärts')
from radverkehr.velorouten where aus14 is not null;
														   
alter table radverkehr.o_radweg drop column old_id;