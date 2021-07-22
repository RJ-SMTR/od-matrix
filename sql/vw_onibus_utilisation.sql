-- this table likely wont work with multiple days

WITH H3Table AS (  									-- H3 table
    
	SELECT  tile_id,
            resolution,
            parent_id,
            ST_GEOGFROMTEXT(geometry) AS geometry

    FROM `rj-smtr.br_rj_riodejaneiro_geo.h3_res8` 
    ),

ticketing_onibus AS (

	SELECT *
	FROM pytest.vw_ticketing_origin_destination 
			
	WHERE origin_tile_id IS NOT NULL
	AND destination_tile_id IS NOT NULL
	AND origin_mode = 'Ônibus'
	
	),
	
onibus_gps AS (		
-- Onibus GPS table, bus GPS joined with h3 geometry (this should be done in view later)
	SELECT 
		onibus_oneday.as_at,
		onibus_oneday.onibus_id,
		onibus_oneday.line,
		onibus_oneday.tile_id,
		onibus_oneday.h3_time_enter,
		onibus_oneday.h3_time_exit,
		capacity_sitting,
		capacity_standing,
		capacity_total,
		h3t1.geometry AS tile_geometry
		
	FROM pytest.onibus_oneday
		
	LEFT JOIN H3Table AS h3t1
			ON h3t1.tile_id = onibus_oneday.tile_id

),

working_table AS (								-- Working table, join gps data with ticketing data, match tap with GPS ping
SELECT 
	onibus_gps.as_at,
	onibus_id,
	onibus_gps.line,
	onibus_gps.tile_id,
	onibus_gps.h3_time_enter,
	onibus_gps.h3_time_exit,
	capacity_sitting,
	capacity_standing,
	capacity_total,
	
	card_id,
	origin_time,
	destination_tile_id,
	tile_geometry,
	geometry AS destination_tile_geometry

FROM onibus_gps

LEFT JOIN ticketing_onibus
		ON origin_code = CAST(RIGHT(onibus_id,5) AS INT)
			AND ticketing_onibus.as_at = onibus_gps.as_at
			AND origin_time BETWEEN onibus_gps.h3_time_enter AND onibus_gps.h3_time_exit

LEFT JOIN H3Table
	ON H3Table.tile_id = ticketing_onibus.destination_tile_id
	
	),

distance_table AS (							-- Match all gps pings that occur 2hrs after boarding with each tap for a given bus. Calculate distance.

SELECT 
	ROW_NUMBER() OVER (PARTITION BY B.onibus_id, card_id, origin_time ORDER BY B.h3_time_enter) AS n,
	B.as_at,
	B.onibus_id,
	B.line,
	B.tile_id,
	B.h3_time_enter,
	B.h3_time_exit,
--	B.tile_geometry,
	B.capacity_sitting,
	B.capacity_standing,
	B.capacity_total,
	card_id,
	origin_time,
	destination_tile_id,
	(
		ST_DISTANCE(B.tile_geometry, destination_tile_geometry) +
		ST_MAXDISTANCE(B.tile_geometry, destination_tile_geometry)
	) / 2	 AS distance_avg,				-- this calcs the average distance
	
	MIN(
				(							-- this calcs the minimum distance for a given tap
				ST_DISTANCE(B.tile_geometry, destination_tile_geometry) +
				ST_MAXDISTANCE(B.tile_geometry, destination_tile_geometry)
				) / 2
				
		) OVER (PARTITION BY B.onibus_id, card_id, origin_time) 					AS distance_min
	
FROM onibus_gps B

INNER JOIN working_table A
	ON A.as_at = B.as_at AND A.onibus_id = B.onibus_id
	AND B.h3_time_exit > origin_time
	AND B.h3_time_enter < TIME_ADD(origin_time, INTERVAL 2 HOUR)

ORDER BY h3_time_enter

	),
	
min_distance AS (							-- min distance row for each tap, to identify where along the route the user got off
	SELECT as_at, onibus_id, line, card_id, origin_time, MIN(n) AS max_row		
	FROM distance_table
	
	WHERE distance_min = distance_avg	-- keep only the minimum distance rows, identified by the row number
	
	GROUP BY  as_at, onibus_id, line, card_id, origin_time
	ORDER BY card_id
)

SELECT 	a.as_at, a.onibus_id, a.line, tile_id, h3_time_enter, h3_time_exit, 
		COUNT(*) 									AS n_passengers, 
		AVG(capacity_sitting)						AS capacity_sitting,
		AVG(capacity_standing)						AS capacity_standing,
		AVG(capacity_total) 						AS average_capacity_total,
		COUNT(*) / AVG(capacity_sitting)			AS utilisation_sitting
FROM distance_table a
LEFT JOIN min_distance b
	ON a.as_at = b.as_at AND a.onibus_id = b.onibus_id AND a.card_id = b.card_id AND a.origin_time = b.origin_time

WHERE n <= max_row
GROUP BY a.as_at, a.onibus_id, a.line, tile_id, h3_time_enter, h3_time_exit
ORDER BY onibus_id, h3_time_enter