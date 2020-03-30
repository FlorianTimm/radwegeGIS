--Dienst
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
	 