update radverkehr.bearbeitung SET fertig = false;


create table radverkehr.stadtteil_status (
	id integer references geobasis.stadtteile(stadtteil_nummer),
	status integer check (status >= 0 and status <=100),
	datum timestamp default now()
);

insert into radverkehr.stadtteil_status (id, status)
select stadtteil_nummer as id, 0 as status
from geobasis.stadtteile;

create view radverkehr.stadtteil_status_geo as
select stadtteil_status.id, geom, bezirk_name, stadtteil_name, stadtteil_status.status from 
radverkehr.stadtteil_status, geobasis.stadtteile
where stadtteil_status.id = stadtteile.stadtteil_nummer;

drop rule _update on radverkehr.stadtteil_status_geo;
create rule _update as on update to radverkehr.stadtteil_status_geo do instead
update radverkehr.stadtteil_status set status = new.status, datum = now() where id = new.id;