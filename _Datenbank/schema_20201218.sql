--
-- PostgreSQL database dump
--

-- Dumped from database version 11.8
-- Dumped by pg_dump version 13.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: radverkehr; Type: SCHEMA; Schema: -; Owner: radverkehr_admin
--

CREATE SCHEMA radverkehr;


ALTER SCHEMA radverkehr OWNER TO radverkehr_admin;

--
-- Name: history(); Type: FUNCTION; Schema: radverkehr; Owner: radverkehr_admin
--

CREATE FUNCTION radverkehr.history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
			
			update radverkehr.o_radweg_vertices_pgr set chk = 0 where st_dwithin(old.geometrie, o_radweg_vertices_pgr.the_geom, 0.1);

			update radverkehr.o_radweg_vertices_pgr set chk = 1 where id in (
			select distinct v.id from radverkehr.o_radweg w, radverkehr.o_radweg_vertices_pgr v 
			where st_dwithin(w.geometrie,v.the_geom,0.1) and v.id != w.source and v.id != w.target and st_dwithin(old.geometrie, v.the_geom, 0.2));
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
		
		update radverkehr.o_radweg_vertices_pgr set chk = 0 where st_dwithin(new.geometrie, o_radweg_vertices_pgr.the_geom, 0.1);

		update radverkehr.o_radweg_vertices_pgr set chk = 1 where id in (
		select distinct v.id from radverkehr.o_radweg w, radverkehr.o_radweg_vertices_pgr v 
		where st_dwithin(w.geometrie,v.the_geom,0.1) and v.id != w.source and v.id != w.target and st_dwithin(new.geometrie, v.the_geom, 0.2));

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
$$;


ALTER FUNCTION radverkehr.history() OWNER TO radverkehr_admin;

--
-- Name: refresh_routing(); Type: FUNCTION; Schema: radverkehr; Owner: postgres
--

CREATE FUNCTION radverkehr.refresh_routing() RETURNS void
    LANGUAGE plpgsql
    AS $$
	BEGIN
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
	END;
$$;


ALTER FUNCTION radverkehr.refresh_routing() OWNER TO postgres;

--
-- Name: update_harburg(); Type: FUNCTION; Schema: radverkehr; Owner: fronk
--

CREATE FUNCTION radverkehr.update_harburg() RETURNS text
    LANGUAGE sql
    AS $$insert into radverkehr.sackgassen (cnt, chk, ein, eout, the_geom)
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
	
update radverkehr.routing_vertices_pgr set geprueft = true where id in (
 select k.id from radverkehr.sackgassen s
	left join radverkehr.routing_vertices_pgr k
	on 
	s.cnt = k.cnt and
	s.chk = k.chk and
	s.ein = k.ein and
	s.eout = k.eout and
	k.the_geom = s.the_geom where k.id is not null);
	
select 'fertig'$$;


ALTER FUNCTION radverkehr.update_harburg() OWNER TO fronk;

SET default_tablespace = '';

--
-- Name: bearbeitung; Type: TABLE; Schema: radverkehr; Owner: postgres
--

CREATE TABLE radverkehr.bearbeitung (
    id integer NOT NULL,
    geom public.geometry(Polygon,25832) NOT NULL,
    bearbeiter text DEFAULT USER,
    datum timestamp without time zone DEFAULT now(),
    fertig boolean DEFAULT false,
    geprueft boolean DEFAULT false
);


ALTER TABLE radverkehr.bearbeitung OWNER TO postgres;

--
-- Name: bearbeitung_id_seq; Type: SEQUENCE; Schema: radverkehr; Owner: postgres
--

CREATE SEQUENCE radverkehr.bearbeitung_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE radverkehr.bearbeitung_id_seq OWNER TO postgres;

--
-- Name: bearbeitung_id_seq; Type: SEQUENCE OWNED BY; Schema: radverkehr; Owner: postgres
--

ALTER SEQUENCE radverkehr.bearbeitung_id_seq OWNED BY radverkehr.bearbeitung.id;


--
-- Name: benutzungspflicht; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.benutzungspflicht (
    fid bigint NOT NULL,
    geom public.geometry(Polygon,25832),
    pflicht character varying(10)
);


ALTER TABLE radverkehr.benutzungspflicht OWNER TO b4_admin;

--
-- Name: feldvergleich; Type: TABLE; Schema: radverkehr; Owner: postgres
--

CREATE TABLE radverkehr.feldvergleich (
    gid uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    problem text,
    erkenntnisse text,
    nutzer character varying(20) DEFAULT USER,
    create_date timestamp without time zone NOT NULL,
    geom public.geometry(Polygon,25832) NOT NULL
);


ALTER TABLE radverkehr.feldvergleich OWNER TO postgres;

--
-- Name: in_bearbeitung; Type: VIEW; Schema: radverkehr; Owner: postgres
--

CREATE VIEW radverkehr.in_bearbeitung AS
 SELECT b.id,
    b.geom,
    b.bearbeiter,
    b.datum,
    ((USER)::text = b.bearbeiter) AS selbst,
    b.fertig,
    b.geprueft,
    (0)::bigint AS verbindungsfehler
   FROM radverkehr.bearbeitung b
UNION
 SELECT (- st_dump.path[1]) AS id,
    (st_dump.geom)::public.geometry(Polygon,25832) AS geom,
    'keiner'::text AS bearbeiter,
    (now())::timestamp without time zone AS datum,
    false AS selbst,
    false AS fertig,
    false AS geprueft,
    0 AS verbindungsfehler
   FROM public.st_dump(public.st_difference(( SELECT public.st_union(bezirke.geom) AS st_union
           FROM geobasis.bezirke), ( SELECT public.st_union(bearbeitung.geom) AS st_union
           FROM radverkehr.bearbeitung))) st_dump(path, geom);


ALTER TABLE radverkehr.in_bearbeitung OWNER TO postgres;

--
-- Name: kt_ausstattungsart; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.kt_ausstattungsart (
    ausstattungsart_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200) NOT NULL,
    beschreibung text,
    zustaendigkeit text
);


ALTER TABLE radverkehr.kt_ausstattungsart OWNER TO b4_admin;

--
-- Name: kt_hindernis; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.kt_hindernis (
    hindernis_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200) NOT NULL,
    beschreibung text
);


ALTER TABLE radverkehr.kt_hindernis OWNER TO b4_admin;

--
-- Name: kt_niveau; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.kt_niveau (
    niveau_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200) NOT NULL,
    beschreibung text
);


ALTER TABLE radverkehr.kt_niveau OWNER TO b4_admin;

--
-- Name: kt_oberflaeche; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.kt_oberflaeche (
    oberflaeche_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200) NOT NULL,
    beschreibung text,
    sicherheit numeric(4,2) DEFAULT 1.0,
    geschwindigkeit integer DEFAULT 15
);


ALTER TABLE radverkehr.kt_oberflaeche OWNER TO b4_admin;

--
-- Name: kt_quelle; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.kt_quelle (
    quelle_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200) NOT NULL,
    beschreibung text
);


ALTER TABLE radverkehr.kt_quelle OWNER TO b4_admin;

--
-- Name: kt_radweg_art; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.kt_radweg_art (
    radweg_art_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200) NOT NULL,
    beschreibung text,
    kurzbezeichnung character varying(150),
    sicherheit numeric(3,2) DEFAULT 1.0,
    max_geschwindigkeit integer DEFAULT 30
);


ALTER TABLE radverkehr.kt_radweg_art OWNER TO b4_admin;

--
-- Name: kt_routenklasse; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.kt_routenklasse (
    klasse_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200) NOT NULL,
    beschreibung text,
    zustaendigkeit text
);


ALTER TABLE radverkehr.kt_routenklasse OWNER TO b4_admin;

--
-- Name: kt_status; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.kt_status (
    status_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200) NOT NULL,
    beschreibung text
);


ALTER TABLE radverkehr.kt_status OWNER TO b4_admin;

--
-- Name: kt_strassenname; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.kt_strassenname (
    name_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    strassenschluessel character varying(10),
    bezeichnung character varying(200) NOT NULL
);


ALTER TABLE radverkehr.kt_strassenname OWNER TO b4_admin;

--
-- Name: o_ausstattung; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.o_ausstattung (
    radroute_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200),
    ausstattungsart_id uuid NOT NULL,
    betreiber text,
    kontakt text,
    radweg_gid integer
);


ALTER TABLE radverkehr.o_ausstattung OWNER TO b4_admin;

--
-- Name: o_radroute; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.o_radroute (
    radroute_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    bezeichnung character varying(200) NOT NULL,
    beschreibung text,
    hyperlink character varying(200),
    klasse_id uuid,
    von_km double precision,
    bis_km double precision
);


ALTER TABLE radverkehr.o_radroute OWNER TO b4_admin;

--
-- Name: o_radweg; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.o_radweg (
    name_id uuid,
    radweg_art_id uuid,
    oberflaeche_id uuid,
    breite numeric(5,3),
    bemerkung text,
    quelle_id uuid,
    id_in_quelle character varying(100),
    geometrie public.geometry(LineString,25832),
    status_id uuid,
    niveau_id uuid,
    create_date timestamp without time zone DEFAULT now(),
    create_user text,
    update_date timestamp without time zone DEFAULT now(),
    update_user text,
    hindernis_id uuid,
    zweirichtung boolean DEFAULT false NOT NULL,
    radweg_id integer NOT NULL,
    source integer,
    target integer,
    len_out double precision DEFAULT '-1'::integer,
    len_in double precision DEFAULT '-1'::integer,
    sicherheit_in double precision DEFAULT '-1'::integer,
    sicherheit_out double precision DEFAULT '-1'::integer,
    zeit_in double precision DEFAULT '-1'::integer,
    zeit_out double precision DEFAULT '-1'::integer,
    CONSTRAINT o_radweg_check CHECK ((create_date <= update_date)),
    CONSTRAINT o_radweg_positive_breite CHECK ((breite > (0)::numeric))
);


ALTER TABLE radverkehr.o_radweg OWNER TO b4_admin;

--
-- Name: o_radweg_edit; Type: VIEW; Schema: radverkehr; Owner: postgres
--

CREATE VIEW radverkehr.o_radweg_edit AS
 SELECT o_radweg.name_id,
    o_radweg.radweg_art_id,
    o_radweg.oberflaeche_id,
    o_radweg.breite,
    o_radweg.bemerkung,
    o_radweg.quelle_id,
    o_radweg.id_in_quelle,
    o_radweg.geometrie,
    o_radweg.status_id,
    o_radweg.niveau_id,
    o_radweg.create_date,
    o_radweg.create_user,
    o_radweg.update_date,
    o_radweg.update_user,
    o_radweg.hindernis_id,
    o_radweg.zweirichtung,
    o_radweg.radweg_id
   FROM radverkehr.o_radweg
  WHERE public.st_intersects(o_radweg.geometrie, ( SELECT public.st_union(bearbeitung.geom) AS st_union
           FROM radverkehr.bearbeitung
          WHERE ((bearbeitung.bearbeiter = (USER)::text) AND (bearbeitung.fertig = false))));


ALTER TABLE radverkehr.o_radweg_edit OWNER TO postgres;

--
-- Name: o_radweg_gid_seq; Type: SEQUENCE; Schema: radverkehr; Owner: b4_admin
--

CREATE SEQUENCE radverkehr.o_radweg_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE radverkehr.o_radweg_gid_seq OWNER TO b4_admin;

--
-- Name: o_radweg_gid_seq; Type: SEQUENCE OWNED BY; Schema: radverkehr; Owner: b4_admin
--

ALTER SEQUENCE radverkehr.o_radweg_gid_seq OWNED BY radverkehr.o_radweg.radweg_id;


--
-- Name: o_radweg_history; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.o_radweg_history (
    id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    operation character(1) NOT NULL,
    stamp timestamp without time zone NOT NULL,
    userid text NOT NULL,
    name_id uuid,
    radweg_art_id uuid,
    oberflaeche_id uuid,
    breite numeric(5,3),
    bemerkung text,
    quelle_id uuid,
    id_in_quelle character varying(100),
    geometrie public.geometry(LineString,25832),
    status_id uuid,
    niveau_id uuid,
    create_date timestamp without time zone NOT NULL,
    create_user text,
    update_date timestamp without time zone,
    update_user text,
    hindernis_id uuid,
    zweirichtung boolean DEFAULT false,
    radweg_id integer NOT NULL,
    source integer,
    target integer,
    len_out double precision DEFAULT '-1'::integer,
    len_in double precision DEFAULT '-1'::integer,
    sicherheit_in double precision DEFAULT '-1'::integer,
    sicherheit_out double precision DEFAULT '-1'::integer,
    zeit_in double precision DEFAULT '-1'::integer,
    zeit_out double precision DEFAULT '-1'::integer,
    CONSTRAINT o_radweg_history_breite_check CHECK ((breite > (0)::numeric)),
    CONSTRAINT o_radweg_history_check CHECK ((create_date <= update_date))
);


ALTER TABLE radverkehr.o_radweg_history OWNER TO b4_admin;

--
-- Name: o_radweg_history_gid_seq; Type: SEQUENCE; Schema: radverkehr; Owner: b4_admin
--

CREATE SEQUENCE radverkehr.o_radweg_history_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE radverkehr.o_radweg_history_gid_seq OWNER TO b4_admin;

--
-- Name: o_radweg_history_gid_seq; Type: SEQUENCE OWNED BY; Schema: radverkehr; Owner: b4_admin
--

ALTER SEQUENCE radverkehr.o_radweg_history_gid_seq OWNED BY radverkehr.o_radweg_history.radweg_id;


--
-- Name: o_radweg_vertices_pgr; Type: TABLE; Schema: radverkehr; Owner: postgres
--

CREATE TABLE radverkehr.o_radweg_vertices_pgr (
    id bigint NOT NULL,
    cnt integer,
    chk integer,
    ein integer,
    eout integer,
    the_geom public.geometry(Point,25832),
    status boolean DEFAULT false NOT NULL
);


ALTER TABLE radverkehr.o_radweg_vertices_pgr OWNER TO postgres;

--
-- Name: o_radweg_vertices_pgr_id_seq; Type: SEQUENCE; Schema: radverkehr; Owner: postgres
--

CREATE SEQUENCE radverkehr.o_radweg_vertices_pgr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE radverkehr.o_radweg_vertices_pgr_id_seq OWNER TO postgres;

--
-- Name: o_radweg_vertices_pgr_id_seq; Type: SEQUENCE OWNED BY; Schema: radverkehr; Owner: postgres
--

ALTER SEQUENCE radverkehr.o_radweg_vertices_pgr_id_seq OWNED BY radverkehr.o_radweg_vertices_pgr.id;


--
-- Name: sackgassen; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.sackgassen (
    cnt integer,
    chk integer,
    ein integer,
    eout integer,
    the_geom public.geometry(Point,25832)
);


ALTER TABLE radverkehr.sackgassen OWNER TO b4_admin;

--
-- Name: stadtteil_status; Type: TABLE; Schema: radverkehr; Owner: postgres
--

CREATE TABLE radverkehr.stadtteil_status (
    id integer,
    status integer,
    datum timestamp without time zone DEFAULT now(),
    CONSTRAINT stadtteil_status_status_check CHECK (((status >= 0) AND (status <= 100)))
);


ALTER TABLE radverkehr.stadtteil_status OWNER TO postgres;

--
-- Name: stadtteil_status_geo; Type: VIEW; Schema: radverkehr; Owner: postgres
--

CREATE VIEW radverkehr.stadtteil_status_geo AS
 SELECT stadtteil_status.id,
    stadtteile.geom,
    stadtteile.bezirk_name,
    stadtteile.stadtteil_name,
    stadtteil_status.status
   FROM radverkehr.stadtteil_status,
    geobasis.stadtteile
  WHERE (stadtteil_status.id = stadtteile.stadtteil_nummer);


ALTER TABLE radverkehr.stadtteil_status_geo OWNER TO postgres;

--
-- Name: strassenname_area; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.strassenname_area (
    gid integer NOT NULL,
    geom public.geometry(Polygon,25832),
    strassenname character varying
);


ALTER TABLE radverkehr.strassenname_area OWNER TO b4_admin;

--
-- Name: strassenname_area_gid_seq; Type: SEQUENCE; Schema: radverkehr; Owner: b4_admin
--

CREATE SEQUENCE radverkehr.strassenname_area_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE radverkehr.strassenname_area_gid_seq OWNER TO b4_admin;

--
-- Name: strassenname_area_gid_seq; Type: SEQUENCE OWNED BY; Schema: radverkehr; Owner: b4_admin
--

ALTER SEQUENCE radverkehr.strassenname_area_gid_seq OWNED BY radverkehr.strassenname_area.gid;


--
-- Name: unbearbeitet; Type: VIEW; Schema: radverkehr; Owner: postgres
--

CREATE VIEW radverkehr.unbearbeitet AS
 SELECT public.st_difference(( SELECT public.st_union(bezirke.geom) AS st_union
           FROM geobasis.bezirke), ( SELECT public.st_union(bearbeitung.geom) AS st_union
           FROM radverkehr.bearbeitung)) AS st_difference;


ALTER TABLE radverkehr.unbearbeitet OWNER TO postgres;

--
-- Name: v_radweg; Type: VIEW; Schema: radverkehr; Owner: postgres
--

CREATE VIEW radverkehr.v_radweg AS
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
    (a.radweg_art_id)::character varying AS radweg_art_id,
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


ALTER TABLE radverkehr.v_radweg OWNER TO postgres;

--
-- Name: v_radweg_route; Type: TABLE; Schema: radverkehr; Owner: b4_admin
--

CREATE TABLE radverkehr.v_radweg_route (
    weg_route_id uuid DEFAULT public.uuid_generate_v1() NOT NULL,
    radroute_id uuid NOT NULL,
    radweg_gid integer
);


ALTER TABLE radverkehr.v_radweg_route OWNER TO b4_admin;

--
-- Name: view_fuer_dienst; Type: VIEW; Schema: radverkehr; Owner: postgres
--

CREATE VIEW radverkehr.view_fuer_dienst AS
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
    a.radweg_art_id,
    a.source,
    a.target,
    a.geometrie
   FROM radverkehr.v_radweg a
  WHERE (public.st_intersects(a.geometrie, ( SELECT public.st_union(in_bearbeitung.geom) AS st_union
           FROM radverkehr.in_bearbeitung
          WHERE (in_bearbeitung.fertig AND in_bearbeitung.geprueft))) OR public.st_intersects(a.geometrie, ( SELECT public.st_union(stadtteil_status_geo.geom) AS st_union
           FROM radverkehr.stadtteil_status_geo
          WHERE (stadtteil_status_geo.status = 100))));


ALTER TABLE radverkehr.view_fuer_dienst OWNER TO postgres;

--
-- Name: bearbeitung id; Type: DEFAULT; Schema: radverkehr; Owner: postgres
--

ALTER TABLE ONLY radverkehr.bearbeitung ALTER COLUMN id SET DEFAULT nextval('radverkehr.bearbeitung_id_seq'::regclass);


--
-- Name: o_radweg radweg_id; Type: DEFAULT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg ALTER COLUMN radweg_id SET DEFAULT nextval('radverkehr.o_radweg_gid_seq'::regclass);


--
-- Name: o_radweg_history radweg_id; Type: DEFAULT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg_history ALTER COLUMN radweg_id SET DEFAULT nextval('radverkehr.o_radweg_history_gid_seq'::regclass);


--
-- Name: o_radweg_vertices_pgr id; Type: DEFAULT; Schema: radverkehr; Owner: postgres
--

ALTER TABLE ONLY radverkehr.o_radweg_vertices_pgr ALTER COLUMN id SET DEFAULT nextval('radverkehr.o_radweg_vertices_pgr_id_seq'::regclass);


--
-- Name: strassenname_area gid; Type: DEFAULT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.strassenname_area ALTER COLUMN gid SET DEFAULT nextval('radverkehr.strassenname_area_gid_seq'::regclass);


--
-- Name: bearbeitung bearbeitung_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: postgres
--

ALTER TABLE ONLY radverkehr.bearbeitung
    ADD CONSTRAINT bearbeitung_pkey PRIMARY KEY (id);


--
-- Name: benutzungspflicht benutzungspflicht_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.benutzungspflicht
    ADD CONSTRAINT benutzungspflicht_pkey PRIMARY KEY (fid);


--
-- Name: feldvergleich feldvergleich_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: postgres
--

ALTER TABLE ONLY radverkehr.feldvergleich
    ADD CONSTRAINT feldvergleich_pkey PRIMARY KEY (gid);


--
-- Name: kt_ausstattungsart kt_ausstattungsart_bezeichnung_key; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_ausstattungsart
    ADD CONSTRAINT kt_ausstattungsart_bezeichnung_key UNIQUE (bezeichnung);


--
-- Name: kt_ausstattungsart kt_ausstattungsart_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_ausstattungsart
    ADD CONSTRAINT kt_ausstattungsart_pkey PRIMARY KEY (ausstattungsart_id);


--
-- Name: kt_hindernis kt_hindernis_bezeichnung_key; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_hindernis
    ADD CONSTRAINT kt_hindernis_bezeichnung_key UNIQUE (bezeichnung);


--
-- Name: kt_hindernis kt_hindernis_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_hindernis
    ADD CONSTRAINT kt_hindernis_pkey PRIMARY KEY (hindernis_id);


--
-- Name: kt_niveau kt_niveau_bezeichnung_key; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_niveau
    ADD CONSTRAINT kt_niveau_bezeichnung_key UNIQUE (bezeichnung);


--
-- Name: kt_niveau kt_niveau_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_niveau
    ADD CONSTRAINT kt_niveau_pkey PRIMARY KEY (niveau_id);


--
-- Name: kt_oberflaeche kt_oberflaeche_bezeichnung_key; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_oberflaeche
    ADD CONSTRAINT kt_oberflaeche_bezeichnung_key UNIQUE (bezeichnung);


--
-- Name: kt_oberflaeche kt_oberflaeche_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_oberflaeche
    ADD CONSTRAINT kt_oberflaeche_pkey PRIMARY KEY (oberflaeche_id);


--
-- Name: kt_quelle kt_quelle_bezeichnung_key; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_quelle
    ADD CONSTRAINT kt_quelle_bezeichnung_key UNIQUE (bezeichnung);


--
-- Name: kt_quelle kt_quelle_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_quelle
    ADD CONSTRAINT kt_quelle_pkey PRIMARY KEY (quelle_id);


--
-- Name: kt_radweg_art kt_radweg_art_bezeichnung_key; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_radweg_art
    ADD CONSTRAINT kt_radweg_art_bezeichnung_key UNIQUE (bezeichnung);


--
-- Name: kt_radweg_art kt_radweg_art_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_radweg_art
    ADD CONSTRAINT kt_radweg_art_pkey PRIMARY KEY (radweg_art_id);


--
-- Name: kt_routenklasse kt_routenklasse_bezeichnung_key; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_routenklasse
    ADD CONSTRAINT kt_routenklasse_bezeichnung_key UNIQUE (bezeichnung);


--
-- Name: kt_routenklasse kt_routenklasse_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_routenklasse
    ADD CONSTRAINT kt_routenklasse_pkey PRIMARY KEY (klasse_id);


--
-- Name: kt_status kt_status_bezeichnung_key; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_status
    ADD CONSTRAINT kt_status_bezeichnung_key UNIQUE (bezeichnung);


--
-- Name: kt_status kt_status_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_status
    ADD CONSTRAINT kt_status_pkey PRIMARY KEY (status_id);


--
-- Name: kt_strassenname kt_strassenname_bezeichnung_key; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_strassenname
    ADD CONSTRAINT kt_strassenname_bezeichnung_key UNIQUE (bezeichnung);


--
-- Name: kt_strassenname kt_strassenname_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.kt_strassenname
    ADD CONSTRAINT kt_strassenname_pkey PRIMARY KEY (name_id);


--
-- Name: o_ausstattung o_ausstattung_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_ausstattung
    ADD CONSTRAINT o_ausstattung_pkey PRIMARY KEY (radroute_id);


--
-- Name: o_radroute o_radroute_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radroute
    ADD CONSTRAINT o_radroute_pkey PRIMARY KEY (radroute_id);


--
-- Name: o_radweg_history o_radweg_history_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg_history
    ADD CONSTRAINT o_radweg_history_pkey PRIMARY KEY (id);


--
-- Name: o_radweg o_radweg_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg
    ADD CONSTRAINT o_radweg_pkey PRIMARY KEY (radweg_id);


--
-- Name: o_radweg_vertices_pgr o_radweg_vertices_pgr_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: postgres
--

ALTER TABLE ONLY radverkehr.o_radweg_vertices_pgr
    ADD CONSTRAINT o_radweg_vertices_pgr_pkey PRIMARY KEY (id);


--
-- Name: strassenname_area strassenname_area_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.strassenname_area
    ADD CONSTRAINT strassenname_area_pkey PRIMARY KEY (gid);


--
-- Name: v_radweg_route v_radweg_route_pkey; Type: CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.v_radweg_route
    ADD CONSTRAINT v_radweg_route_pkey PRIMARY KEY (weg_route_id);


--
-- Name: o_radweg_gist; Type: INDEX; Schema: radverkehr; Owner: b4_admin
--

CREATE INDEX o_radweg_gist ON radverkehr.o_radweg USING gist (geometrie);


--
-- Name: o_radweg_radweg_id; Type: INDEX; Schema: radverkehr; Owner: b4_admin
--

CREATE UNIQUE INDEX o_radweg_radweg_id ON radverkehr.o_radweg USING btree (radweg_id);


--
-- Name: o_radweg_source; Type: INDEX; Schema: radverkehr; Owner: b4_admin
--

CREATE INDEX o_radweg_source ON radverkehr.o_radweg USING btree (source);


--
-- Name: o_radweg_target; Type: INDEX; Schema: radverkehr; Owner: b4_admin
--

CREATE INDEX o_radweg_target ON radverkehr.o_radweg USING btree (target);


--
-- Name: o_radweg_vertices_pgr_id_idx; Type: INDEX; Schema: radverkehr; Owner: postgres
--

CREATE INDEX o_radweg_vertices_pgr_id_idx ON radverkehr.o_radweg_vertices_pgr USING btree (id);


--
-- Name: o_radweg_vertices_pgr_the_geom_idx; Type: INDEX; Schema: radverkehr; Owner: postgres
--

CREATE INDEX o_radweg_vertices_pgr_the_geom_idx ON radverkehr.o_radweg_vertices_pgr USING gist (the_geom);


--
-- Name: sidx_benutzungspflicht_geom; Type: INDEX; Schema: radverkehr; Owner: b4_admin
--

CREATE INDEX sidx_benutzungspflicht_geom ON radverkehr.benutzungspflicht USING gist (geom);


--
-- Name: sidx_strassenname_area_geom; Type: INDEX; Schema: radverkehr; Owner: b4_admin
--

CREATE INDEX sidx_strassenname_area_geom ON radverkehr.strassenname_area USING gist (geom);


--
-- Name: in_bearbeitung _delete; Type: RULE; Schema: radverkehr; Owner: postgres
--

CREATE RULE _delete AS
    ON DELETE TO radverkehr.in_bearbeitung DO INSTEAD  DELETE FROM radverkehr.bearbeitung
  WHERE ((bearbeitung.id = old.id) AND (bearbeitung.bearbeiter = (USER)::text));


--
-- Name: o_radweg_edit _delete; Type: RULE; Schema: radverkehr; Owner: postgres
--

CREATE RULE _delete AS
    ON DELETE TO radverkehr.o_radweg_edit DO INSTEAD  DELETE FROM radverkehr.o_radweg
  WHERE (o_radweg.radweg_id = old.radweg_id);


--
-- Name: in_bearbeitung _insert; Type: RULE; Schema: radverkehr; Owner: postgres
--

CREATE RULE _insert AS
    ON INSERT TO radverkehr.in_bearbeitung DO INSTEAD  INSERT INTO radverkehr.bearbeitung (geom, fertig)
  VALUES (new.geom, new.fertig)
  RETURNING bearbeitung.id,
    bearbeitung.geom,
    bearbeitung.bearbeiter,
    bearbeitung.datum,
    true AS bool,
    bearbeitung.fertig;


--
-- Name: o_radweg_edit _insert; Type: RULE; Schema: radverkehr; Owner: postgres
--

CREATE RULE _insert AS
    ON INSERT TO radverkehr.o_radweg_edit DO INSTEAD  INSERT INTO radverkehr.o_radweg (name_id, radweg_art_id, oberflaeche_id, breite, bemerkung, quelle_id, id_in_quelle, geometrie, status_id, niveau_id, create_date, create_user, update_date, update_user, hindernis_id, zweirichtung)
  VALUES (new.name_id, new.radweg_art_id, new.oberflaeche_id, new.breite, new.bemerkung, new.quelle_id, new.id_in_quelle, new.geometrie, new.status_id, new.niveau_id, new.create_date, new.create_user, new.update_date, new.update_user, new.hindernis_id, new.zweirichtung)
  RETURNING o_radweg.name_id,
    o_radweg.radweg_art_id,
    o_radweg.oberflaeche_id,
    o_radweg.breite,
    o_radweg.bemerkung,
    o_radweg.quelle_id,
    o_radweg.id_in_quelle,
    o_radweg.geometrie,
    o_radweg.status_id,
    o_radweg.niveau_id,
    o_radweg.create_date,
    o_radweg.create_user,
    o_radweg.update_date,
    o_radweg.update_user,
    o_radweg.hindernis_id,
    o_radweg.zweirichtung,
    o_radweg.radweg_id;


--
-- Name: in_bearbeitung _update; Type: RULE; Schema: radverkehr; Owner: postgres
--

CREATE RULE _update AS
    ON UPDATE TO radverkehr.in_bearbeitung DO INSTEAD  UPDATE radverkehr.bearbeitung SET geom = new.geom, fertig = new.fertig, geprueft = new.geprueft
  WHERE (bearbeitung.id = old.id);


--
-- Name: stadtteil_status_geo _update; Type: RULE; Schema: radverkehr; Owner: postgres
--

CREATE RULE _update AS
    ON UPDATE TO radverkehr.stadtteil_status_geo DO INSTEAD  UPDATE radverkehr.stadtteil_status SET status = new.status, datum = now()
  WHERE (stadtteil_status.id = new.id);


--
-- Name: o_radweg_edit _update; Type: RULE; Schema: radverkehr; Owner: postgres
--

CREATE RULE _update AS
    ON UPDATE TO radverkehr.o_radweg_edit DO INSTEAD  UPDATE radverkehr.o_radweg SET name_id = new.name_id, radweg_art_id = new.radweg_art_id, oberflaeche_id = new.oberflaeche_id, breite = new.breite, bemerkung = new.bemerkung, quelle_id = new.quelle_id, id_in_quelle = new.id_in_quelle, geometrie = new.geometrie, status_id = new.status_id, niveau_id = new.niveau_id, create_date = new.create_date, create_user = new.create_user, update_date = new.update_date, update_user = new.update_user, hindernis_id = new.hindernis_id, zweirichtung = new.zweirichtung, radweg_id = new.radweg_id
  WHERE (o_radweg.radweg_id = old.radweg_id);


--
-- Name: o_radweg o_radweg_history; Type: TRIGGER; Schema: radverkehr; Owner: b4_admin
--

CREATE TRIGGER o_radweg_history BEFORE INSERT OR DELETE OR UPDATE ON radverkehr.o_radweg FOR EACH ROW EXECUTE PROCEDURE radverkehr.history();


--
-- Name: o_radweg name_id_fk; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg
    ADD CONSTRAINT name_id_fk FOREIGN KEY (name_id) REFERENCES radverkehr.kt_strassenname(name_id) MATCH FULL;


--
-- Name: o_ausstattung o_ausstattung_ausstattungsart_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_ausstattung
    ADD CONSTRAINT o_ausstattung_ausstattungsart_id_fkey FOREIGN KEY (ausstattungsart_id) REFERENCES radverkehr.kt_ausstattungsart(ausstattungsart_id);


--
-- Name: o_ausstattung o_ausstattung_radweg_gid_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_ausstattung
    ADD CONSTRAINT o_ausstattung_radweg_gid_fkey FOREIGN KEY (radweg_gid) REFERENCES radverkehr.o_radweg(radweg_id);


--
-- Name: o_radroute o_radroute_klasse_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radroute
    ADD CONSTRAINT o_radroute_klasse_id_fkey FOREIGN KEY (klasse_id) REFERENCES radverkehr.kt_routenklasse(klasse_id);


--
-- Name: o_radweg o_radweg_hindernis_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg
    ADD CONSTRAINT o_radweg_hindernis_id_fkey FOREIGN KEY (hindernis_id) REFERENCES radverkehr.kt_hindernis(hindernis_id);


--
-- Name: o_radweg_history o_radweg_history_hindernis_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg_history
    ADD CONSTRAINT o_radweg_history_hindernis_id_fkey FOREIGN KEY (hindernis_id) REFERENCES radverkehr.kt_hindernis(hindernis_id);


--
-- Name: o_radweg_history o_radweg_history_name_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg_history
    ADD CONSTRAINT o_radweg_history_name_id_fkey FOREIGN KEY (name_id) REFERENCES radverkehr.kt_strassenname(name_id);


--
-- Name: o_radweg_history o_radweg_history_niveau_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg_history
    ADD CONSTRAINT o_radweg_history_niveau_id_fkey FOREIGN KEY (niveau_id) REFERENCES radverkehr.kt_niveau(niveau_id);


--
-- Name: o_radweg_history o_radweg_history_oberflaeche_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg_history
    ADD CONSTRAINT o_radweg_history_oberflaeche_id_fkey FOREIGN KEY (oberflaeche_id) REFERENCES radverkehr.kt_oberflaeche(oberflaeche_id);


--
-- Name: o_radweg_history o_radweg_history_quelle_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg_history
    ADD CONSTRAINT o_radweg_history_quelle_id_fkey FOREIGN KEY (quelle_id) REFERENCES radverkehr.kt_quelle(quelle_id);


--
-- Name: o_radweg_history o_radweg_history_radweg_art_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg_history
    ADD CONSTRAINT o_radweg_history_radweg_art_id_fkey FOREIGN KEY (radweg_art_id) REFERENCES radverkehr.kt_radweg_art(radweg_art_id);


--
-- Name: o_radweg_history o_radweg_history_status_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg_history
    ADD CONSTRAINT o_radweg_history_status_id_fkey FOREIGN KEY (status_id) REFERENCES radverkehr.kt_status(status_id);


--
-- Name: o_radweg o_radweg_niveau_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg
    ADD CONSTRAINT o_radweg_niveau_id_fkey FOREIGN KEY (niveau_id) REFERENCES radverkehr.kt_niveau(niveau_id);


--
-- Name: o_radweg o_radweg_oberflaeche_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg
    ADD CONSTRAINT o_radweg_oberflaeche_id_fkey FOREIGN KEY (oberflaeche_id) REFERENCES radverkehr.kt_oberflaeche(oberflaeche_id);


--
-- Name: o_radweg o_radweg_quelle_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg
    ADD CONSTRAINT o_radweg_quelle_id_fkey FOREIGN KEY (quelle_id) REFERENCES radverkehr.kt_quelle(quelle_id);


--
-- Name: o_radweg o_radweg_radweg_art_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg
    ADD CONSTRAINT o_radweg_radweg_art_id_fkey FOREIGN KEY (radweg_art_id) REFERENCES radverkehr.kt_radweg_art(radweg_art_id);


--
-- Name: o_radweg o_radweg_status_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.o_radweg
    ADD CONSTRAINT o_radweg_status_id_fkey FOREIGN KEY (status_id) REFERENCES radverkehr.kt_status(status_id);


--
-- Name: stadtteil_status stadtteil_status_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: postgres
--

ALTER TABLE ONLY radverkehr.stadtteil_status
    ADD CONSTRAINT stadtteil_status_id_fkey FOREIGN KEY (id) REFERENCES geobasis.stadtteile(stadtteil_nummer);


--
-- Name: v_radweg_route v_radweg_route_radroute_id_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.v_radweg_route
    ADD CONSTRAINT v_radweg_route_radroute_id_fkey FOREIGN KEY (radroute_id) REFERENCES radverkehr.o_radroute(radroute_id);


--
-- Name: v_radweg_route v_radweg_route_radweg_gid_fkey; Type: FK CONSTRAINT; Schema: radverkehr; Owner: b4_admin
--

ALTER TABLE ONLY radverkehr.v_radweg_route
    ADD CONSTRAINT v_radweg_route_radweg_gid_fkey FOREIGN KEY (radweg_gid) REFERENCES radverkehr.o_radweg(radweg_id);


--
-- Name: SCHEMA radverkehr; Type: ACL; Schema: -; Owner: radverkehr_admin
--

REVOKE ALL ON SCHEMA radverkehr FROM radverkehr_admin;
GRANT USAGE ON SCHEMA radverkehr TO b4_lesend;
GRANT USAGE ON SCHEMA radverkehr TO radverkehr_editor;
GRANT ALL ON SCHEMA radverkehr TO b4_admin WITH GRANT OPTION;
GRANT USAGE ON SCHEMA radverkehr TO fme_c;


--
-- Name: FUNCTION history(); Type: ACL; Schema: radverkehr; Owner: radverkehr_admin
--

GRANT ALL ON FUNCTION radverkehr.history() TO radverkehr_editor;
GRANT ALL ON FUNCTION radverkehr.history() TO b4_admin WITH GRANT OPTION;
SET SESSION AUTHORIZATION b4_admin;
GRANT ALL ON FUNCTION radverkehr.history() TO radverkehr_editor;
RESET SESSION AUTHORIZATION;


--
-- Name: FUNCTION refresh_routing(); Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT ALL ON FUNCTION radverkehr.refresh_routing() TO radverkehr_editor;
GRANT ALL ON FUNCTION radverkehr.refresh_routing() TO b4_admin WITH GRANT OPTION;
SET SESSION AUTHORIZATION b4_admin;
GRANT ALL ON FUNCTION radverkehr.refresh_routing() TO radverkehr_editor;
RESET SESSION AUTHORIZATION;


--
-- Name: FUNCTION update_harburg(); Type: ACL; Schema: radverkehr; Owner: fronk
--

GRANT ALL ON FUNCTION radverkehr.update_harburg() TO radverkehr_editor;
GRANT ALL ON FUNCTION radverkehr.update_harburg() TO b4_admin WITH GRANT OPTION;
SET SESSION AUTHORIZATION b4_admin;
GRANT ALL ON FUNCTION radverkehr.update_harburg() TO radverkehr_editor;
RESET SESSION AUTHORIZATION;


--
-- Name: TABLE bearbeitung; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT SELECT,DELETE,UPDATE ON TABLE radverkehr.bearbeitung TO b4_admin;
GRANT SELECT ON TABLE radverkehr.bearbeitung TO fme_c;
GRANT SELECT ON TABLE radverkehr.bearbeitung TO radverkehr_editor;


--
-- Name: SEQUENCE bearbeitung_id_seq; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT USAGE ON SEQUENCE radverkehr.bearbeitung_id_seq TO deegree;
GRANT ALL ON SEQUENCE radverkehr.bearbeitung_id_seq TO b4_admin WITH GRANT OPTION;
GRANT USAGE ON SEQUENCE radverkehr.bearbeitung_id_seq TO b4_schreibend;
GRANT SELECT,USAGE ON SEQUENCE radverkehr.bearbeitung_id_seq TO b4_lesend;
GRANT SELECT,USAGE ON SEQUENCE radverkehr.bearbeitung_id_seq TO radverkehr_editor;
GRANT SELECT ON SEQUENCE radverkehr.bearbeitung_id_seq TO fme_c;


--
-- Name: TABLE benutzungspflicht; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.benutzungspflicht FROM b4_admin;
GRANT ALL ON TABLE radverkehr.benutzungspflicht TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.benutzungspflicht TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.benutzungspflicht TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.benutzungspflicht TO fme_c;


--
-- Name: TABLE feldvergleich; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT ALL ON TABLE radverkehr.feldvergleich TO b4_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.feldvergleich TO b4_schreibend;
GRANT SELECT ON TABLE radverkehr.feldvergleich TO b4_lesend;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.feldvergleich TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.feldvergleich TO fme_c;


--
-- Name: TABLE in_bearbeitung; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT SELECT ON TABLE radverkehr.in_bearbeitung TO b4_lesend;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.in_bearbeitung TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.in_bearbeitung TO fme_c;


--
-- Name: TABLE kt_ausstattungsart; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.kt_ausstattungsart FROM b4_admin;
GRANT ALL ON TABLE radverkehr.kt_ausstattungsart TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_ausstattungsart TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.kt_ausstattungsart TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.kt_ausstattungsart TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.kt_ausstattungsart TO radverkehr_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_ausstattungsart TO fme_c;


--
-- Name: TABLE kt_hindernis; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.kt_hindernis FROM b4_admin;
GRANT ALL ON TABLE radverkehr.kt_hindernis TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_hindernis TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.kt_hindernis TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.kt_hindernis TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.kt_hindernis TO radverkehr_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_hindernis TO fme_c;


--
-- Name: TABLE kt_niveau; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.kt_niveau FROM b4_admin;
GRANT ALL ON TABLE radverkehr.kt_niveau TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_niveau TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.kt_niveau TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.kt_niveau TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.kt_niveau TO radverkehr_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_niveau TO fme_c;


--
-- Name: TABLE kt_oberflaeche; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.kt_oberflaeche FROM b4_admin;
GRANT ALL ON TABLE radverkehr.kt_oberflaeche TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_oberflaeche TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.kt_oberflaeche TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.kt_oberflaeche TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.kt_oberflaeche TO radverkehr_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_oberflaeche TO fme_c;


--
-- Name: TABLE kt_quelle; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.kt_quelle FROM b4_admin;
GRANT ALL ON TABLE radverkehr.kt_quelle TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_quelle TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.kt_quelle TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.kt_quelle TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.kt_quelle TO radverkehr_admin WITH GRANT OPTION;
GRANT INSERT ON TABLE radverkehr.kt_quelle TO weiss;
GRANT SELECT ON TABLE radverkehr.kt_quelle TO fme_c;


--
-- Name: TABLE kt_radweg_art; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.kt_radweg_art FROM b4_admin;
GRANT ALL ON TABLE radverkehr.kt_radweg_art TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_radweg_art TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.kt_radweg_art TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.kt_radweg_art TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.kt_radweg_art TO radverkehr_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_radweg_art TO fme_c;


--
-- Name: TABLE kt_routenklasse; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.kt_routenklasse FROM b4_admin;
GRANT ALL ON TABLE radverkehr.kt_routenklasse TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_routenklasse TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.kt_routenklasse TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.kt_routenklasse TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.kt_routenklasse TO radverkehr_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_routenklasse TO fme_c;


--
-- Name: TABLE kt_status; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.kt_status FROM b4_admin;
GRANT ALL ON TABLE radverkehr.kt_status TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_status TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.kt_status TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.kt_status TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.kt_status TO radverkehr_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_status TO fme_c;


--
-- Name: TABLE kt_strassenname; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.kt_strassenname FROM b4_admin;
GRANT ALL ON TABLE radverkehr.kt_strassenname TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_strassenname TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.kt_strassenname TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.kt_strassenname TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.kt_strassenname TO radverkehr_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.kt_strassenname TO b4_widmung_editor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.kt_strassenname TO fme_c;


--
-- Name: TABLE o_ausstattung; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.o_ausstattung FROM b4_admin;
GRANT ALL ON TABLE radverkehr.o_ausstattung TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.o_ausstattung TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.o_ausstattung TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.o_ausstattung TO fme_c;


--
-- Name: TABLE o_radroute; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.o_radroute FROM b4_admin;
GRANT ALL ON TABLE radverkehr.o_radroute TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.o_radroute TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.o_radroute TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.o_radroute TO fme_c;


--
-- Name: TABLE o_radweg; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.o_radweg FROM b4_admin;
GRANT ALL ON TABLE radverkehr.o_radweg TO b4_admin WITH GRANT OPTION;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.o_radweg TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.o_radweg TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.o_radweg TO fme_c;
GRANT SELECT ON TABLE radverkehr.o_radweg TO deegree;
GRANT SELECT ON TABLE radverkehr.o_radweg TO webserver;


--
-- Name: TABLE o_radweg_edit; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT ALL ON TABLE radverkehr.o_radweg_edit TO b4_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.o_radweg_edit TO b4_schreibend;
GRANT SELECT ON TABLE radverkehr.o_radweg_edit TO b4_lesend;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.o_radweg_edit TO radverkehr_editor;


--
-- Name: SEQUENCE o_radweg_gid_seq; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

GRANT SELECT,USAGE ON SEQUENCE radverkehr.o_radweg_gid_seq TO radverkehr_editor;
GRANT SELECT ON SEQUENCE radverkehr.o_radweg_gid_seq TO fme_c;


--
-- Name: TABLE o_radweg_history; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.o_radweg_history FROM b4_admin;
GRANT ALL ON TABLE radverkehr.o_radweg_history TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.o_radweg_history TO b4_lesend;
GRANT SELECT,INSERT ON TABLE radverkehr.o_radweg_history TO radverkehr_editor;
GRANT SELECT,INSERT,DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.o_radweg_history TO radverkehr_admin;
GRANT SELECT ON TABLE radverkehr.o_radweg_history TO fme_c;


--
-- Name: SEQUENCE o_radweg_history_gid_seq; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

GRANT SELECT ON SEQUENCE radverkehr.o_radweg_history_gid_seq TO radverkehr_editor;
GRANT SELECT ON SEQUENCE radverkehr.o_radweg_history_gid_seq TO fme_c;


--
-- Name: TABLE o_radweg_vertices_pgr; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT ALL ON TABLE radverkehr.o_radweg_vertices_pgr TO b4_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.o_radweg_vertices_pgr TO b4_schreibend;
GRANT SELECT ON TABLE radverkehr.o_radweg_vertices_pgr TO b4_lesend;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.o_radweg_vertices_pgr TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.o_radweg_vertices_pgr TO fme_c;


--
-- Name: SEQUENCE o_radweg_vertices_pgr_id_seq; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT USAGE ON SEQUENCE radverkehr.o_radweg_vertices_pgr_id_seq TO deegree;
GRANT ALL ON SEQUENCE radverkehr.o_radweg_vertices_pgr_id_seq TO b4_admin WITH GRANT OPTION;
GRANT USAGE ON SEQUENCE radverkehr.o_radweg_vertices_pgr_id_seq TO b4_schreibend;
GRANT SELECT,USAGE ON SEQUENCE radverkehr.o_radweg_vertices_pgr_id_seq TO b4_lesend;
GRANT SELECT,USAGE ON SEQUENCE radverkehr.o_radweg_vertices_pgr_id_seq TO radverkehr_editor;
GRANT SELECT ON SEQUENCE radverkehr.o_radweg_vertices_pgr_id_seq TO fme_c;


--
-- Name: TABLE sackgassen; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.sackgassen FROM b4_admin;
GRANT ALL ON TABLE radverkehr.sackgassen TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.sackgassen TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.sackgassen TO radverkehr_editor;
GRANT DELETE,TRUNCATE,UPDATE ON TABLE radverkehr.sackgassen TO radverkehr_admin;
GRANT SELECT,INSERT ON TABLE radverkehr.sackgassen TO radverkehr_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.sackgassen TO fme_c;


--
-- Name: TABLE stadtteil_status; Type: ACL; Schema: radverkehr; Owner: postgres
--

REVOKE ALL ON TABLE radverkehr.stadtteil_status FROM postgres;
GRANT SELECT ON TABLE radverkehr.stadtteil_status TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.stadtteil_status TO b4_admin;
GRANT SELECT ON TABLE radverkehr.stadtteil_status TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.stadtteil_status TO fme_c;


--
-- Name: TABLE stadtteil_status_geo; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT ALL ON TABLE radverkehr.stadtteil_status_geo TO b4_admin;
GRANT SELECT ON TABLE radverkehr.stadtteil_status_geo TO b4_lesend;
GRANT SELECT,UPDATE ON TABLE radverkehr.stadtteil_status_geo TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.stadtteil_status_geo TO fme_c;


--
-- Name: TABLE strassenname_area; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.strassenname_area FROM b4_admin;
GRANT ALL ON TABLE radverkehr.strassenname_area TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.strassenname_area TO b4_lesend;
GRANT SELECT ON TABLE radverkehr.strassenname_area TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.strassenname_area TO fme_c;


--
-- Name: SEQUENCE strassenname_area_gid_seq; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON SEQUENCE radverkehr.strassenname_area_gid_seq FROM b4_admin;
GRANT ALL ON SEQUENCE radverkehr.strassenname_area_gid_seq TO b4_admin WITH GRANT OPTION;
GRANT ALL ON SEQUENCE radverkehr.strassenname_area_gid_seq TO radverkehr_editor;
GRANT SELECT,USAGE ON SEQUENCE radverkehr.strassenname_area_gid_seq TO b4_lesend;
GRANT SELECT ON SEQUENCE radverkehr.strassenname_area_gid_seq TO fme_c;


--
-- Name: TABLE unbearbeitet; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT ALL ON TABLE radverkehr.unbearbeitet TO b4_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.unbearbeitet TO b4_schreibend;
GRANT SELECT ON TABLE radverkehr.unbearbeitet TO b4_lesend;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.unbearbeitet TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.unbearbeitet TO fme_c;


--
-- Name: TABLE v_radweg; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT ALL ON TABLE radverkehr.v_radweg TO b4_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.v_radweg TO b4_schreibend;
GRANT SELECT ON TABLE radverkehr.v_radweg TO b4_lesend;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.v_radweg TO radverkehr_editor;


--
-- Name: TABLE v_radweg_route; Type: ACL; Schema: radverkehr; Owner: b4_admin
--

REVOKE ALL ON TABLE radverkehr.v_radweg_route FROM b4_admin;
GRANT ALL ON TABLE radverkehr.v_radweg_route TO b4_admin WITH GRANT OPTION;
GRANT SELECT ON TABLE radverkehr.v_radweg_route TO b4_lesend;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.v_radweg_route TO radverkehr_editor;
GRANT SELECT ON TABLE radverkehr.v_radweg_route TO fme_c;


--
-- Name: TABLE view_fuer_dienst; Type: ACL; Schema: radverkehr; Owner: postgres
--

GRANT ALL ON TABLE radverkehr.view_fuer_dienst TO b4_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.view_fuer_dienst TO b4_schreibend;
GRANT SELECT ON TABLE radverkehr.view_fuer_dienst TO b4_lesend;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE radverkehr.view_fuer_dienst TO radverkehr_editor;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: radverkehr; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA radverkehr REVOKE ALL ON SEQUENCES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA radverkehr GRANT ALL ON SEQUENCES  TO b4_admin WITH GRANT OPTION;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA radverkehr GRANT SELECT,USAGE ON SEQUENCES  TO b4_lesend;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: radverkehr; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA radverkehr REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA radverkehr GRANT ALL ON TABLES  TO b4_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA radverkehr GRANT SELECT ON TABLES  TO b4_lesend;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA radverkehr GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO radverkehr_editor;


--
-- PostgreSQL database dump complete
--

