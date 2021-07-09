WITH raw_ticketing AS (

	SELECT
		DATA_HORA_TRANSACAO		AS origin_as_at,
		NUMERO_CARTAO			AS card_id, 
		ROW_NUMBER() OVER (PARTITION BY NUMERO_CARTAO ORDER BY DATA_HORA_TRANSACAO) AS daily_trip_id, --Will need to partition by date in future
		MODAL					AS origin_mode, 
		COD_VEICULO 			AS origin_code, 
		LEAD(MODAL) OVER (PARTITION BY NUMERO_CARTAO ORDER BY DATA_HORA_TRANSACAO) AS destination_mode_partial,
		LEAD(COD_VEICULO) OVER (PARTITION BY NUMERO_CARTAO ORDER BY DATA_HORA_TRANSACAO) AS destination_code_partial,
		VALIDADOR_VEICULO		AS VALIDATOR_VEHICLE, 
		NR_CHIP_VEICULO			AS NR_CHIP_VEHICLE, 

		CD_OPERADORA			AS operator, 
		CD_LINHA				AS line_code, 
		NR_LINHA				AS line_number
	FROM `rj-smtr-dev`.pytest.ticketing 
	),

card_trips AS (

	SELECT 
		CASE
			WHEN MAX(daily_trip_id) OVER (PARTITION BY card_id) = 1 THEN 'Only Trip'
			WHEN MAX(daily_trip_id) OVER (PARTITION BY card_id) = daily_trip_id THEN 'Last Trip'
			WHEN MIN(daily_trip_id) OVER (PARTITION BY card_id) = daily_trip_id THEN 'First Trip'
		ELSE 'Intermediate Trip'
		END AS daily_trip_stage,
		*
	
	FROM raw_ticketing
	),

intermediate_ticketing AS (

	SELECT 
		CASE	
			WHEN daily_trip_stage = 'Last Trip' THEN FIRST_VALUE(origin_mode) OVER (PARTITION BY card_id ORDER BY daily_trip_id)
			ELSE destination_mode_partial 
		END AS destination_mode,
		CASE	
			WHEN daily_trip_stage = 'Last Trip' THEN FIRST_VALUE(origin_code) OVER (PARTITION BY card_id ORDER BY daily_trip_id)
			ELSE destination_code_partial
		END AS destination_code,
		*
	FROM card_trips
	),
	
ticketing AS (

	SELECT 
		card_id,
		origin_as_at,
		daily_trip_stage,
		origin_mode,
		origin_code,
		destination_mode,
		destination_code,
		operator,
		line_number
	FROM intermediate_ticketing
	ORDER BY card_id, origin_as_at
	)

SELECT *
FROM ticketing