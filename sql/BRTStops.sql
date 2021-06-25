WITH BRTStops AS ( --Currently there is only 1 distinct gtfs_version_date, in the future need 
-- to take latest. This should be done soon.
    SELECT *,
        ST_GEOGPOINT(stop_lon, stop_lat) AS Geography

    FROM `rj-smtr.br_rj_riodejaneiro_gtfs_planned.stops`
    WHERE location_type = 0
    OR location_type IS NULL
    ),

H3Table AS (
    SELECT  tile_id,
            resolution,
            parent_id,
            ST_GEOGFROMTEXT(geometry) AS geometry

    FROM `rj-smtr.br_rj_riodejaneiro_geo.h3_res8` 
    )

SELECT *
FROM BRTStops --  424 rows in table, inner join table returned 422 rows.
JOIN H3Table -- This appears to be an inner join which isn't ideal (may drop data). Why doesn't left join work?
    ON ST_INTERSECTS(BRTStops.geography, H3Table.geometry)
