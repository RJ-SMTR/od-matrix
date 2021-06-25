WITH H3Table AS (
    SELECT  tile_id,
            resolution,
            parent_id,
            ST_GEOGFROMTEXT(geometry) AS geometry

    FROM `rj-smtr.br_rj_riodejaneiro_geo.h3_res8` 
    ),

GTFSStopsH3 AS (
    SELECT 
        PlannedRoutes.route_id,
        service_id,
        PlannedTrips.trip_id,
        trip_headsign,
        direction_id,
        shape_id,
        trip_short_name,
        Stops.stop_id,
        stop_name,
        tile_id,
        location_type AS stop_location_type,
        parent_station,
        corridor,
        active,
        stop_sequence,
        stop_headsign,
        agency_id,
        route_short_name,
        route_long_name,
        route_type,
        route_color,
        route_text_color,
        route_desc,
        route_url,
        route_sort_order,
        StopTimes.continuous_pickup,
        StopTimes.continuous_drop_off,
        PlannedTrips.gtfs_version_date,

    FROM `br_rj_riodejaneiro_gtfs_planned.routes` AS PlannedRoutes
    
        FULL JOIN `br_rj_riodejaneiro_gtfs_planned.trips` AS PlannedTrips
            ON PlannedRoutes.route_id = PlannedTrips.route_id 
            AND PlannedRoutes.gtfs_version_date = PlannedTrips.gtfs_version_date -- Consider if this is needed, or if there is a better way. Is it always the case version dates will be the same?

        FULL JOIN `br_rj_riodejaneiro_gtfs_planned.stop_times` AS StopTimes 
            ON PlannedTrips.trip_id = StopTimes.trip_id
            AND PlannedRoutes.gtfs_version_date = StopTimes.gtfs_version_date -- As above comment

        FULL JOIN `br_rj_riodejaneiro_gtfs_planned.stops` AS Stops 
            ON StopTimes.stop_id = Stops.stop_id
            AND PlannedRoutes.gtfs_version_date = Stops.gtfs_version_date -- As above comment
        
        JOIN H3Table -- This appears to be an inner join which isn't ideal (may drop data - some rows are dropped). Why doesn't left join work?
            ON ST_INTERSECTS(ST_GEOGPOINT(stop_lon, stop_lat), H3Table.geometry)
)
SELECT *

FROM GTFSStopsH3

ORDER BY route_id, trip_id

