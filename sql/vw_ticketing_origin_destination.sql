WITH ticketing_origin_destination AS (
	SELECT 
		vw_ticketing.as_at,
		card_id,
		daily_trip_id,
		daily_trip_stage,
		origin_time,
		EXTRACT(HOUR FROM origin_time) AS origin_hour,
		origin_mode,
		origin_code,
		tile_id AS origin_tile_id,
		destination_mode,
		destination_code,
		CASE	
			WHEN daily_trip_stage = 'Last Trip' THEN FIRST_VALUE(tile_id) OVER (PARTITION BY vw_ticketing.as_at, card_id ORDER BY daily_trip_id)
			ELSE LEAD(tile_id) OVER (PARTITION BY vw_ticketing.as_at, card_id ORDER BY origin_time)
		END AS destination_tile_id,
		operator,
		line_number,
		line AS onibus_line,
		h3_time_enter,
		h3_time_exit
--		capacity_sitting,
--		capacity_standing, 
--		capacity_total
	FROM pytest.vw_ticketing 
	
	LEFT JOIN pytest.onibus_oneday
		ON origin_code = CAST(RIGHT(onibus_id,5) AS INT)
		AND origin_time BETWEEN h3_time_enter AND h3_time_exit
		AND onibus_oneday.as_at = vw_ticketing.as_at		

	ORDER BY card_id, origin_time
)

SELECT
	*
FROM ticketing_origin_destination


