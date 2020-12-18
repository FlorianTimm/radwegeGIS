CREATE TABLE IF NOT EXISTS radverkehr.o_radweg_neu (
	radweg_id SERIAL PRIMARY KEY,
	name_id UUID REFERENCES radverkehr.kt_strassenname(name_id),
	radweg_art_id UUID REFERENCES radverkehr.kt_radweg_art(radweg_art_id),
	zweirichtung boolean default false,
	oberflaeche_id UUID REFERENCES radverkehr.kt_oberflaeche(oberflaeche_id),
	breite NUMERIC(5,3) check (breite > 0),
	status_id UUID REFERENCES radverkehr.kt_status(status_id),
	niveau_id UUID REFERENCES radverkehr.kt_niveau(niveau_id),
	hindernis_id UUID REFERENCES radverkehr.kt_hindernis(hindernis_id),
	bemerkung text,
	quelle_id UUID REFERENCES radverkehr.kt_quelle(quelle_id),
	id_in_quelle varchar(100),
	geometrie geometry(LINESTRING,25832) NOT NULL,
	source INTEGER,
	target INTEGER,
	create_date timestamp without time zone not null,
	create_user text,
	update_date timestamp without time zone,
	update_user text
);

insert into radverkehr.o_radweg_neu (name_id,radweg_art_id,zweirichtung,oberflaeche_id,breite,status_id,niveau_id,hindernis_id,bemerkung, quelle_id,id_in_quelle,geometrie,create_date,create_user,update_date,update_user)
select name_id,radweg_art_id,
CASE WHEN richtung_id = 'c1f220bf-7def-11e9-a7aa-02004c4f4f50' THEN true
WHEN richtung_id = 'c1efbe7e-7def-11e9-a7a8-02004c4f4f50' THEN false
ELSE null END zweirichtung
,oberflaeche_id,breite,status_id,niveau_id,hindernis_id,bemerkung, quelle_id,id_in_quelle,geometrie,create_date,create_user,update_date,update_user
from radverkehr.o_radweg where geometrie is not null;

CREATE INDEX IF NOT EXISTS index_o_radweg_neu_id ON radverkehr.o_radweg_neu USING btree (radweg_id);
CREATE INDEX IF NOT EXISTS index_o_radweg_neu_gist ON radverkehr.o_radweg_neu USING gist (geometrie); 
CREATE INDEX IF NOT EXISTS index_o_radweg_neu_source ON radverkehr.o_radweg_neu USING btree (source);
CREATE INDEX IF NOT EXISTS index_o_radweg_neu_target ON radverkehr.o_radweg_neu USING btree (target);

select pgr_createTopology('radverkehr.o_radweg_neu', 0.1,'geometrie' , 'radweg_id' ,'source' ,'target', 'true', true);
select pgr_analyzeGraph('radverkehr.o_radweg_neu', 0.1,'geometrie' , 'radweg_id' ,'source' ,'target', 'true');
select pgr_analyzeOneway('radverkehr.o_radweg_neu',
	ARRAY['true'],
	ARRAY['false', 'true'],
	ARRAY['false', 'true'],
	ARRAY['true'],
	oneway:='zweirichtung');

alter table radverkehr.o_radweg_neu_vertices_pgr add column status boolean default null;

update radverkehr.o_radweg_neu_vertices_pgr set status = false where
chk = 1 or cnt = 1 or cout = 0 or cin = 0;

update radverkehr.o_radweg_neu_vertices_pgr set status = true  where
status = false and id in (select v.id id from radverkehr.o_radweg_neu_vertices_pgr v,
radverkehr.sackgassen s where
st_dwithin(v.the_geom, s.the_geom, 0.1));

