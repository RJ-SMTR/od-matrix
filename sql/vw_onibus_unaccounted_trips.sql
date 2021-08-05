WITH unaccounted_trips  AS (
SELECT 
	as_at, 
	onibus_id, 
	onibus_line, 
	origin_hour, 
--	origin_tile_id,
--	destination_tile_id,
	CASE 
		WHEN origin_tile_id IS NULL OR destination_tile_id IS NULL	THEN 'Unexplained'
		ELSE 'Explained'
	END 						AS accounted_unaccounted
	--count(*) AS unexplained_trips
	
FROM pytest.vw_ticketing_origin_destination
	
WHERE origin_mode = 'Ônibus'

),
group_total AS (
SELECT 
	as_at, 
	onibus_id, 
	onibus_line, 
	origin_hour, 
	accounted_unaccounted, 
	COUNT(*)  AS n,
	SUM(COUNT(*)) OVER (PARTITION BY as_at, onibus_id, onibus_line, origin_hour) AS group_total,
	CAST(COUNT(*) AS NUMERIC) / CAST((SUM(COUNT(*)) OVER (PARTITION BY as_at, onibus_id, onibus_line, origin_hour)) AS NUMERIC) AS perc_group_total
	
FROM unaccounted_trips

--WHERE accounted_unaccounted = 'Unexplained'

GROUP BY
	as_at, 
	onibus_id, 
	onibus_line, 
	origin_hour, 
	accounted_unaccounted
	
ORDER BY onibus_id, onibus_line, origin_hour
)

SELECT *

FROM group_total

WHERE perc_group_total <> 1
