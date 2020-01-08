create view radverkehr.v_radweg as
select 
	radweg_id, 
	f.bezeichnung strassenname, 
	b.bezeichnung radweg_art, 
	c.bezeichnung richtung, 
	d.bezeichnung oberflaeche, 
	e.bezeichnung quelle,  
	id_in_quelle,
	breite, 
	geometrie 
from radverkehr.o_radweg a
left join radverkehr.kt_radweg_art b on a.radweg_art_id = b.radweg_art_id
left join radverkehr.kt_richtung c on a.richtung_id = c.richtung_id
left join radverkehr.kt_oberflaeche d on a.oberflaeche_id = d.oberflaeche_id
left join radverkehr.kt_quelle e on a.quelle_id = e.quelle_id
left join radverkehr.kt_strassenname f on a.name_id = f.name_id;