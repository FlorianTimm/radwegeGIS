update radverkehr.o_radweg 
set hindernis_id = 'cd35e0d6-57de-11ea-8895-02004c4f4f50'
where 
hindernis_id is null and 
radweg_art_id in ('84c54ed4-b14a-11ea-a78c-005056ac04af','9ff1dbb6-eb3c-11e9-b23a-02004c4f4f50','9fef7998-eb3c-11e9-b237-02004c4f4f50');

-- Tunnel
update radverkehr.o_radweg
set niveau_id = '16e92519-4ca2-11ea-b083-02004c4f4f50',
oberflaeche_id = 'c8a52bba-12a8-11ea-8e56-02004c4f4f50'
where niveau_id is null and oberflaeche_id = 'c8a52bbc-12a8-11ea-8e58-02004c4f4f50';

-- Brücken
update radverkehr.o_radweg
set niveau_id = '16e9251a-4ca2-11ea-b084-02004c4f4f50',
oberflaeche_id = 'c8a52bba-12a8-11ea-8e56-02004c4f4f50'
where niveau_id is null and oberflaeche_id = 'c8a52bbb-12a8-11ea-8e57-02004c4f4f50';

-- Rest
update radverkehr.o_radweg
set niveau_id = '16e92518-4ca2-11ea-b082-02004c4f4f50'
where niveau_id is null and geometrie is not null;