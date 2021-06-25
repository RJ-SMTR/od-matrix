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
        GPSH3Table.data                         AS AsAt,
        GPSH3Table.ordem                        AS OnibusID,
        linha                                   AS Line,
        tile_id                                 AS TileID,
        hora_completa                           AS EnterH3Time,
        LEAD(hora_completa) OVER 
            (PARTITION BY GPSH3Table.ordem, GPSH3Table.data 
            ORDER BY GPSH3Table.ordem, GPSH3Table.data, hora_completa) 
                                                AS ExitH3Time,
        capacidade_sentados                     AS SittingCapacity,
        capacidade_em_pe                        AS StandingCapacity,
        capacidade_sentados + capacidade_em_pe  AS TotalCapacity
    
    FROM GPSH3Table 
        LEFT JOIN `br_rj_riodejaneiro_transporte.veiculos_licenciados` AS VehicleTable
            ON GPSH3Table.ordem = VehicleTable.ordem
    
        LEFT JOIN `br_rj_riodejaneiro_transporte.plantas_chasis` AS VehicleDetailsTable
            ON VehicleTable.planta_chassi = VehicleDetailsTable.planta_chassi

    WHERE RemoveRowLag = 'KEEP'
)

SELECT *
FROM OnibusCapacity 
WHERE AsAt >= '2021-06-11'
AND AsAt <= '2021-06-12'
ORDER BY AsAt, OnibusID, EnterH3Time



