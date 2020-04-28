--ALTER TABLE bezirke.strassennamen_area ALTER COLUMN geom SET DATA TYPE geometry;
--select strassenname, st_astext(geom) from bezirke.strassennamen_area where  not st_isvalid(geom);
--update bezirke.strassennamen_area set geom = st_makevalid(geom) where not st_isvalid(geom);

--select * from bezirke.strassenname_area where strassenname = 'Bremer Straße';

drop table if exists radverkehr.name;
create table radverkehr.name as
select radweg_id, name_id from 
	(
		select radweg_id, strassenname from 
			(
				select 
					radweg_id, 
					strassenname, 
					ST_Length(ST_Intersection(geom, geometrie))/ST_LENGTH(geometrie) len 
				from radverkehr.o_radweg inner join 
					bezirke.strassenname_area on st_intersects(geom, geometrie)
				where name_id is null and st_length(geometrie) > 0
			) a 
		group by radweg_id, strassenname order by radweg_id having sum(len) > 0.5
	) b
inner join radverkehr.kt_strassenname on bezeichnung = strassenname;

select count(*) from radverkehr.o_radweg where name_id is null;

update radverkehr.o_radweg r 
	set name_id = (select n.name_id from radverkehr.name n where n.radweg_id  = r.radweg_id)
	where r.name_id is null;