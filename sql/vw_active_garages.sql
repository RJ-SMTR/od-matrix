WITH Garages AS (
    SELECT *,
        ST_GEOGPOINT(longitude, latitude) AS geography

    FROM `rj-smtr.br_rj_riodejaneiro_transporte.garagens`
    
    WHERE ativa = 1 -- Active garages only
    ),

H3Table AS (
    SELECT  tile_id,
            resolution,
            parent_id,
            ST_GEOGFROMTEXT(geometry) AS geometry

    FROM `rj-smtr.br_rj_riodejaneiro_geo.h3_res8` 
    )

SELECT 
	tile_id,
	sigla_empresa AS company_acronym,
	nome_empresa AS company_name,
	tipo AS kind,
	ativa AS active
FROM Garages
JOIN H3Table --This drops some active garages, fix lates (about 5)
  ON ST_INTERSECTS(geography, geometry)
