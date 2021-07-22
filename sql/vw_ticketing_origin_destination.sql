WITH ticketing_origin_tile AS (
	
	SELECT
		vw_ticketing.as_at,
		card_id,
		daily_trip_id,
		daily_trip_stage,
		origin_time,
		EXTRACT(HOUR FROM origin_time) AS origin_hour,
		origin_mode,
		origin_code,
		destination_mode,
		destination_code,
		CASE 
			WHEN origin_mode = 'Ônibus' 	THEN onibus_oneday.tile_id
			WHEN origin_mode = 'BRT'		THEN vw_brt_h3_stops.tile_id
			ELSE NULL
		END 								AS origin_tile_id,
		operator,
		line_number,
		line 								AS onibus_line,
		h3_time_enter						AS onibus_h3_time_enter,
		h3_time_exit						AS onibus_h3_time_enter,	
		capacity_sitting					AS onibus_capacity_sitting,
		capacity_standing					AS onibus_capacity_standing, 
		capacity_total						AS onibus_capacity_total,
		stop_name 							AS brt_stop_name
	
	FROM pytest.vw_ticketing 
	
	LEFT JOIN pytest.onibus_oneday
		ON origin_code = CAST(RIGHT(onibus_id,5) AS INT)
		AND origin_time BETWEEN h3_time_enter AND h3_time_exit
		AND onibus_oneday.as_at = vw_ticketing.as_at
		AND origin_mode = 'Ônibus'
	LEFT JOIN pytest.vw_brt_h3_stops
		ON vw_brt_h3_stops.ticketing_station_id = origin_code
		AND origin_mode = 'BRT'

),
 
ticketing_origin_destination AS (
	SELECT 
		CASE	
			WHEN daily_trip_stage = 'Last Trip' THEN FIRST_VALUE(origin_tile_id) OVER (PARTITION BY as_at, card_id ORDER BY daily_trip_id)
			ELSE LEAD(origin_tile_id) OVER (PARTITION BY as_at, card_id ORDER BY origin_time)
		END AS destination_tile_id,
		*

	FROM ticketing_origin_tile
	
	ORDER BY card_id, origin_time
)

SELECT
	*
FROM ticketing_origin_destination
WHERE origin_mode LIKE 'BRT'


