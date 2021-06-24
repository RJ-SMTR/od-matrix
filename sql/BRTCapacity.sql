WITH GPSTable AS (
    SELECT *,
        ST_GEOGPOINT(longitude, latitude) AS Geography

    FROM `rj-smtr.br_rj_riodejaneiro_brt_gps.registros` — change to dashboard_monitoramento_brt.registros_tratada
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
        data                AS AsAt,
        EXTRACT(time FROM timestamp_captura) AS EnterH3Time,
        codigo              AS BRTCode,
        placa               AS LicencePlate,
        linha               AS Line,
        tile_id             AS TileID,
        sentido             AS BRTDirection,
        trajeto             AS Path,
        CASE
            WHEN LAG(tile_id) OVER (ORDER BY placa, data, timestamp_captura) = tile_id THEN 'DROP'
            ELSE 'KEEP'
        END AS RemoveRowLag

    FROM GPSTable -- 48,343,167 rows in table, inner join table returned 47,296,736 rows.
    JOIN H3Table -- This appears to be an inner join which isn't ideal (may drop data). Why doesn't left join work?
        ON ST_INTERSECTS(GPSTable.geography, H3Table.geometry)

),
BRTCapacity AS (
    SELECT 
        AsAt,
        BRTCode,
        LicencePlate,
        Line,
        TileID,
        EnterH3Time,
        LEAD(EnterH3Time) OVER 
            (   PARTITION BY GPSH3Table.LicencePlate, GPSH3Table.AsAt 
                ORDER BY GPSH3Table.LicencePlate, GPSH3Table.AsAt, EnterH3Time) 
                                                AS ExitH3Time,
        BRTDirection,
        Path,
        capacidade_sentados                     AS SittingCapacity,
        capacidade_em_pe                        AS StandingCapacity,
        capacidade_sentados + capacidade_em_pe  AS TotalCapacity
    FROM GPSH3Table
        LEFT JOIN `br_rj_riodejaneiro_transporte.veiculos_licenciados` AS VehicleTable
            ON GPSH3Table.LicencePlate = VehicleTable.placa

        LEFT JOIN `br_rj_riodejaneiro_transporte.plantas_chasis` AS VehicleDetailsTable
            ON VehicleTable.planta_chassi = VehicleDetailsTable.planta_chassi 
    WHERE RemoveRowLag = 'KEEP'
)

SELECT *
FROM BRTCapacity 

WHERE AsAt = '2021-03-18'

