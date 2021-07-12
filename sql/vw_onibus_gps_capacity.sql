WITH GPSTable AS (
    SELECT *,
        ST_GEOGPOINT(longitude, latitude) AS geography

    FROM `rj-smtr.br_rj_riodejaneiro_onibus_gps.registros_tratada`
    ),

H3Table AS (
    SELECT  tile_id,
            resolution,
            parent_id,
            ST_GEOGFROMTEXT(geometry) AS geometry

    FROM `rj-smtr.br_rj_riodejaneiro_geo.h3_res8` 
    ),

GPSH3Table AS (
    SELECT 
        ordem,
        data,
        linha,
        tile_id,
        resolution,
        parent_id,
        hora_completa,
        CASE
            WHEN LAG(tile_id) OVER (ORDER BY ordem, data, hora_completa) = tile_id THEN 'DROP'
            ELSE 'KEEP'
        END AS RemoveRowLag

    FROM GPSTable --15,410,765 rows in table, inner join table returned 15,161,095 rows.

    JOIN H3Table -- This appears to be an inner join which isn't ideal (may drop data). Why doesn't left join work?
        ON ST_INTERSECTS(GPSTable.geography, H3Table.geometry)
),

OnibusCapacity AS (
    SELECT 
        GPSH3Table.data                         AS as_at,
        GPSH3Table.ordem                        AS onibus_id,
        linha                                   AS line,
        tile_id                                 AS tile_id,
        hora_completa                           AS h3_time_enter,
        LEAD(hora_completa) OVER 
            (PARTITION BY GPSH3Table.ordem, GPSH3Table.data 
            ORDER BY GPSH3Table.ordem, GPSH3Table.data, hora_completa) 
                                                AS h3_time_exit,
        capacidade_sentados                     AS capacity_sitting,
        capacidade_em_pe                        AS capacity_standing,
        capacidade_sentados + capacidade_em_pe  AS capacity_total
    
    FROM GPSH3Table 
        LEFT JOIN `br_rj_riodejaneiro_transporte.veiculos_licenciados` AS VehicleTable
            ON GPSH3Table.ordem = VehicleTable.ordem
    
        LEFT JOIN `br_rj_riodejaneiro_transporte.plantas_chasis` AS VehicleDetailsTable
            ON VehicleTable.planta_chassi = VehicleDetailsTable.planta_chassi

    WHERE RemoveRowLag = 'KEEP'
)

SELECT *
FROM OnibusCapacity 
WHERE as_at = '2021-06-10'
ORDER BY as_at, onibus_id, h3_time_enter



