--drop table radverkehr.routing;
--create table radverkehr.routing as select * from radverkehr.o_radweg;
--alter table radverkehr.routing add column id serial;
--alter table radverkehr.routing add column source integer;
--alter table radverkehr.routing add column target integer;

CREATE OR REPLACE FUNCTION radverkehr.refresh_routing() RETURNS void AS $$
	BEGIN
		truncate table radverkehr.routing;
		truncate table radverkehr.routing_vertices_pgr;
		insert into radverkehr.routing select * from radverkehr.o_radweg;

		select pgr_createTopology('radverkehr.routing', 0.1,'geometrie' , 'id' ,'source' ,'target', 'true', true);
		select pgr_analyzeGraph('radverkehr.routing', 0.1,'geometrie' , 'id' ,'source' ,'target', 'true');
	END;
$$ LANGUAGE plpgsql;

select radverkehr.refresh_routing();