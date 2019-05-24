create view radverkehr.v_radweg as
select radweg_id, wegenummer, laenge, b.bezeichnung radweg_art, c.bezeichnung richtung, d.bezeichnung oberflaeche, breite, geometrie from radverkehr.o_radweg a
left join radverkehr.kt_radweg_art b on a.radweg_art_id = b.radweg_art_id
left join radverkehr.kt_richtung c on a.richtung_id = c.richtung_id
left join radverkehr.kt_oberflaeche d on a.oberflaeche_id = d.oberflaeche_id;