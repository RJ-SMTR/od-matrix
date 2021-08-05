SELECT origin_hour, origin_tile_id, destination_tile_id, count(*) AS n
FROM pytest.vw_ticketing_origin_destination
WHERE origin_tile_id IS NOT NULL
AND destination_tile_id IS NOT NULL

GROUP BY origin_hour, origin_tile_id, destination_tile_id