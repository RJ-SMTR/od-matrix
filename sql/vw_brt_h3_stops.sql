WITH BRTStops AS ( --Currently there is only 1 distinct gtfs_version_date, in the future need 
-- to take latest. This should be done soon.
    SELECT *,
        ST_GEOGPOINT(stop_lon, stop_lat) AS Geography

    FROM `rj-smtr.br_rj_riodejaneiro_gtfs_planned.stops`
    WHERE location_type = 1 -- what does this mean?
   -- AND active = 1 -- what does this mean?
    --OR location_type IS NULL
    ),

H3Table AS (
    SELECT  tile_id,
            resolution,
            parent_id,
            ST_GEOGFROMTEXT(geometry) AS geometry

    FROM `rj-smtr.br_rj_riodejaneiro_geo.h3_res8` 
    )

 SELECT *
FROM BRTStops
WHERE stop_name LIKE '%Fundão%'
    
SELECT 
	COD_VEICULO AS ticketing_station_id,
	NOME 		AS ticketing_station_name,
	stop_id,
	stop_name,
	stop_desc 		AS stop_description,
	stop_lat,
	stop_lon,
	location_type,
	parent_station,
	corridor,
	active,
	tile_id,
	geometry
FROM BRTStops --  424 rows in table, inner join table returned 422 rows.
JOIN H3Table -- This appears to be an inner join which isn't ideal (may drop data). Why doesn't left join work?
    ON ST_INTERSECTS(BRTStops.geography, H3Table.geometry)
RIGHT JOIN pytest.brt_ticketing_gtfs_lookup
	ON CAST(brt_ticketing_gtfs_lookup.gtfs_stop_id AS string) = BRTStops.stop_id --Fundão is missing, fix later, caused by h3 inner join i think

ORDER BY gtfs_stop_name;


