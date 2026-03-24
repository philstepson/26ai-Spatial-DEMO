-- ============================================================================
-- Oracle 26ai Fleet Optimization Demo
-- Script : 02_seed_data.sql
-- Purpose: Seed depots, vehicles, customers, orders, and traffic zones
--          All coordinates are real Chicago-metro locations (WGS84 / SRID 4326)
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET ECHO OFF
SET FEEDBACK ON
SET DEFINE OFF   -- prevent substitution variable expansion in data values

PROMPT
PROMPT ============================================================
PROMPT  Oracle 26ai | Fleet Spatial Optimization Demo
PROMPT  Step 2/7 : Seeding Reference Data
PROMPT ============================================================
PROMPT

-- ============================================================
-- HELPER: Point geometry constructor (LON, LAT order for SDO)
-- ============================================================
-- SDO_GEOMETRY(2001, 4326, SDO_POINT_TYPE(lon, lat, NULL), NULL, NULL)

-- ============================================================
-- SECTION 1: DEPOTS  (3 Chicago-area distribution centres)
-- ============================================================
PROMPT  Inserting depots...

INSERT INTO fleet_depots (
    depot_name, city, address, location,
    capacity_m3, vehicle_slots, operating_open, operating_close, depot_meta
) VALUES (
    'O''Hare Logistics Hub',
    'Chicago (Northwest)',
    '10600 W Higgins Rd, Rosemont, IL 60018',
    SDO_GEOMETRY(2001, 4326, SDO_POINT_TYPE(-87.9073, 41.9742, NULL), NULL, NULL),
    15000, 8, 0500, 2200,
    JSON('{"region":"northwest","specialization":"industrial","dockDoors":12,"coldStorage":true}')
);

INSERT INTO fleet_depots (
    depot_name, city, address, location,
    capacity_m3, vehicle_slots, operating_open, operating_close, depot_meta
) VALUES (
    'McCormick Place Distribution Center',
    'Chicago (South Loop)',
    '2301 S King Dr, Chicago, IL 60616',
    SDO_GEOMETRY(2001, 4326, SDO_POINT_TYPE(-87.6160, 41.8523, NULL), NULL, NULL),
    12000, 6, 0600, 2100,
    JSON('{"region":"central","specialization":"commercial","dockDoors":8,"coldStorage":false}')
);

INSERT INTO fleet_depots (
    depot_name, city, address, location,
    capacity_m3, vehicle_slots, operating_open, operating_close, depot_meta
) VALUES (
    'Cicero West Industrial Depot',
    'Cicero',
    '5401 W Cermak Rd, Cicero, IL 60804',
    SDO_GEOMETRY(2001, 4326, SDO_POINT_TYPE(-87.7533, 41.8456, NULL), NULL, NULL),
    18000, 7, 0500, 2300,
    JSON('{"region":"west","specialization":"heavy_freight","dockDoors":16,"coldStorage":true}')
);

COMMIT;
PROMPT    3 depots inserted.

-- ============================================================
-- SECTION 2: VEHICLES  (15 vehicles, 5 per depot)
-- ============================================================
PROMPT  Inserting vehicles...

-- ---- DEPOT 1: O'Hare Logistics Hub (depot_id = 1) ----
INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (1,'OHR-HT-01','HEAVY_TRUCK',10000,40.0,'DIESEL',0.38,0.265,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9073,41.9742,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2023,"make":"Volvo","model":"FH16","vin":"YV2R4X2A3NB123401"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (1,'OHR-HT-02','HEAVY_TRUCK',10000,40.0,'DIESEL',0.38,0.265,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9073,41.9742,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2022,"make":"Mercedes","model":"Actros","vin":"WDB9631231L456702"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (1,'OHR-BT-01','BOX_TRUCK',5000,22.0,'DIESEL',0.24,0.172,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9073,41.9742,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2023,"make":"Isuzu","model":"NPR-HD","vin":"JALB4W165P7003103"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (1,'OHR-EV-01','ELECTRIC_VAN',1200,8.0,'ELECTRIC',0.09,0.0,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9073,41.9742,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2024,"make":"Ford","model":"E-Transit","vin":"1FTBW9CK2RKB00104"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (1,'OHR-VN-01','VAN',1500,10.0,'HYBRID',0.14,0.075,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9073,41.9742,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2023,"make":"Toyota","model":"HiAce H300","vin":"JTFGV52PX02000105"}'));

-- ---- DEPOT 2: McCormick (depot_id = 2) ----
INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (2,'MCC-HT-01','HEAVY_TRUCK',10000,40.0,'DIESEL',0.38,0.265,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6160,41.8523,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2023,"make":"Kenworth","model":"T680","vin":"1XKWDB0X3NJ000206"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (2,'MCC-BT-01','BOX_TRUCK',5000,22.0,'DIESEL',0.24,0.172,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6160,41.8523,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2022,"make":"Isuzu","model":"FRR","vin":"JALB4W166P7002307"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (2,'MCC-EV-01','ELECTRIC_VAN',1200,8.0,'ELECTRIC',0.09,0.0,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6160,41.8523,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2024,"make":"Mercedes","model":"eSprinter","vin":"W1Y7552861P000408"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (2,'MCC-EV-02','ELECTRIC_VAN',1200,8.0,'ELECTRIC',0.09,0.0,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6160,41.8523,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2024,"make":"Rivian","model":"EDV 500","vin":"7FCTGAAA5PN000509"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (2,'MCC-VN-01','VAN',1500,10.0,'HYBRID',0.14,0.075,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6160,41.8523,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2023,"make":"RAM","model":"ProMaster","vin":"3C6TRVDG5PE000510"}'));

-- ---- DEPOT 3: Cicero West (depot_id = 3) ----
INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (3,'CIC-HT-01','HEAVY_TRUCK',10000,40.0,'DIESEL',0.38,0.265,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7533,41.8456,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2023,"make":"Peterbilt","model":"579","vin":"1XPBDB9X3ND000611"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (3,'CIC-HT-02','HEAVY_TRUCK',10000,40.0,'DIESEL',0.38,0.265,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7533,41.8456,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2022,"make":"Freightliner","model":"Cascadia","vin":"1FUJHHDR4NLGC0712"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (3,'CIC-BT-01','BOX_TRUCK',5000,22.0,'DIESEL',0.24,0.172,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7533,41.8456,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2023,"make":"Hino","model":"338","vin":"5PVNJ8JT5P4S00813"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (3,'CIC-EV-01','ELECTRIC_VAN',1200,8.0,'ELECTRIC',0.09,0.0,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7533,41.8456,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2024,"make":"Ford","model":"E-Transit","vin":"1FTBW9CK3RKB00914"}'));

INSERT INTO fleet_vehicles (depot_id, vehicle_code, vehicle_type, max_payload_kg,
    max_volume_m3, fuel_type, fuel_cost_per_km, emissions_kg_per_km,
    current_location, status, vehicle_meta)
VALUES (3,'CIC-VN-01','VAN',1500,10.0,'HYBRID',0.14,0.075,
    SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7533,41.8456,NULL),NULL,NULL),
    'AVAILABLE',JSON('{"year":2023,"make":"Mercedes","model":"Sprinter 2500","vin":"W1Y9RBH10PT001015"}'));

COMMIT;
PROMPT    15 vehicles inserted (5 per depot).

-- ============================================================
-- SECTION 3: CUSTOMERS  (50 Chicago-area delivery points)
--   Real neighbourhoods, realistic addresses, SDO_GEOMETRY points
-- ============================================================
PROMPT  Inserting 50 customers...

-- Named-column inserts: immune to column-count mismatches.
-- city defaults to 'Chicago'; only overridden for suburbs.

-- --- NORTH SIDE ---
INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Windy City Auto Parts','Lincoln Park','Chicago','2455 N Clark St, Chicago, IL 60614',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6354,41.9244,NULL),NULL,NULL),0700,1600,20,2,'+1-312-555-0101');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Wicker Park Brewing Supplies','Wicker Park','Chicago','1565 N Milwaukee Ave, Chicago, IL 60622',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6778,41.9080,NULL),NULL,NULL),0800,1700,15,3,'+1-312-555-0102');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Bucktown Office Hub','Bucktown','Chicago','2022 W Armitage Ave, Chicago, IL 60647',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6770,41.9195,NULL),NULL,NULL),0900,1800,10,3,'+1-312-555-0103');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Logan Square Freight Co','Logan Square','Chicago','2840 N Milwaukee Ave, Chicago, IL 60618',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7079,41.9222,NULL),NULL,NULL),0600,1500,25,1,'+1-312-555-0104');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('River North Gallery','River North','Chicago','222 W Huron St, Chicago, IL 60654',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6329,41.8922,NULL),NULL,NULL),1000,1900,10,3,'+1-312-555-0105');

-- --- DOWNTOWN CORE ---
INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Gold Coast Fine Foods','Gold Coast','Chicago','1500 N Lake Shore Dr, Chicago, IL 60610',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6268,41.8996,NULL),NULL,NULL),0700,1200,30,1,'+1-312-555-0106');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Streeterville Medical Supplies','Streeterville','Chicago','320 E Huron St, Chicago, IL 60611',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6180,41.8941,NULL),NULL,NULL),0600,1400,20,1,'+1-312-555-0107');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('The Loop Print Shop','The Loop','Chicago','77 W Wacker Dr, Chicago, IL 60601',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6298,41.8781,NULL),NULL,NULL),0800,1700,15,3,'+1-312-555-0108');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('South Loop Coffee Roasters','South Loop','Chicago','1140 S Wabash Ave, Chicago, IL 60605',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6256,41.8669,NULL),NULL,NULL),0500,1100,20,2,'+1-312-555-0109');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Near West Restaurant Supply','Near West Side','Chicago','1411 W Madison St, Chicago, IL 60607',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6556,41.8783,NULL),NULL,NULL),0500,1000,30,1,'+1-312-555-0110');

-- --- WEST SIDE ---
INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Greektown Deli Distributors','Greektown','Chicago','327 S Halsted St, Chicago, IL 60661',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6469,41.8782,NULL),NULL,NULL),0600,1400,15,2,'+1-312-555-0111');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Little Village Tile and Stone','Little Village','Chicago','3158 W 26th St, Chicago, IL 60623',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7186,41.8490,NULL),NULL,NULL),0800,1700,20,3,'+1-312-555-0112');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Cicero Hardware Depot','Cicero','Cicero','5400 W Cermak Rd, Cicero, IL 60804',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7539,41.8456,NULL),NULL,NULL),0700,1700,25,3,'+1-312-555-0113');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Oak Park Organic Market','Oak Park','Oak Park','1101 Lake St, Oak Park, IL 60301',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7845,41.8850,NULL),NULL,NULL),0700,1300,20,2,'+1-708-555-0114');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Elmwood Park Sports','Elmwood Park','Elmwood Park','7433 W Grand Ave, Elmwood Park, IL 60707',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8073,41.9211,NULL),NULL,NULL),0900,1800,15,3,'+1-708-555-0115');

-- --- FAR NORTHWEST ---
INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Park Ridge Pharma Logistics','Park Ridge','Park Ridge','400 W Talcott Rd, Park Ridge, IL 60068',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8403,42.0114,NULL),NULL,NULL),0700,1600,20,1,'+1-847-555-0116');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Rosemont Convention Supplies','Rosemont','Rosemont','5555 N River Rd, Rosemont, IL 60018',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8722,41.9839,NULL),NULL,NULL),0600,2200,15,2,'+1-847-555-0117');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Schaumburg Tech Campus','Schaumburg','Schaumburg','1299 E Algonquin Rd, Schaumburg, IL 60196',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-88.0837,42.0334,NULL),NULL,NULL),0800,1700,20,3,'+1-847-555-0118');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Des Plaines Cold Storage','Des Plaines','Des Plaines','1700 S Mount Prospect Rd, Des Plaines, IL 60018',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8834,42.0107,NULL),NULL,NULL),0500,1400,30,1,'+1-847-555-0119');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Elk Grove Medical Center','Elk Grove Village','Elk Grove Village','800 Biesterfield Rd, Elk Grove Village, IL 60007',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9970,42.0036,NULL),NULL,NULL),0700,1500,25,1,'+1-847-555-0120');

-- --- NORTH SUBURBS ---
INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Evanston University Books','Evanston','Evanston','800 Emerson St, Evanston, IL 60201',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6878,42.0451,NULL),NULL,NULL),0900,1700,15,3,'+1-847-555-0121');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Skokie Electronics','Skokie','Skokie','4999 Oakton St, Skokie, IL 60077',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7333,42.0336,NULL),NULL,NULL),0800,1800,15,3,'+1-847-555-0122');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Niles Furniture Wholesale','Niles','Niles','7255 Oakton St, Niles, IL 60714',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8028,42.0180,NULL),NULL,NULL),0700,1600,30,2,'+1-847-555-0123');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Morton Grove Plastics','Morton Grove','Morton Grove','8300 Waukegan Rd, Morton Grove, IL 60053',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7831,42.0386,NULL),NULL,NULL),0700,1700,20,3,'+1-847-555-0124');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Northbrook Distribution Hub','Northbrook','Northbrook','2101 Pfingsten Rd, Northbrook, IL 60062',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8281,42.1253,NULL),NULL,NULL),0600,1800,25,2,'+1-847-555-0125');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Glenview Aerospace Parts','Glenview','Glenview','2901 Patriot Blvd, Glenview, IL 60026',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8281,42.0697,NULL),NULL,NULL),0700,1600,20,2,'+1-847-555-0126');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Arlington Heights Home Center','Arlington Heights','Arlington Heights','75 E Golf Rd, Arlington Heights, IL 60005',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9806,42.0884,NULL),NULL,NULL),0800,1700,15,3,'+1-847-555-0127');

-- --- FAR WEST SUBURBS ---
INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Hoffman Estates Auto Group','Hoffman Estates','Hoffman Estates','1200 Higgins Rd, Hoffman Estates, IL 60169',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-88.0803,42.0428,NULL),NULL,NULL),0800,1800,20,3,'+1-847-555-0128');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Bartlett Grain and Feed','Bartlett','Bartlett','1065 S Bartlett Rd, Bartlett, IL 60103',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-88.1858,41.9953,NULL),NULL,NULL),0600,1500,25,2,'+1-630-555-0129');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Hanover Park Logistics','Hanover Park','Hanover Park','2450 Irving Park Rd, Hanover Park, IL 60133',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-88.1442,41.9980,NULL),NULL,NULL),0700,1700,20,3,'+1-630-555-0130');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Carol Stream Packaging','Carol Stream','Carol Stream','360 Schmale Rd, Carol Stream, IL 60188',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-88.1347,41.9145,NULL),NULL,NULL),0700,1600,20,3,'+1-630-555-0131');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Addison Engineering Supplies','Addison','Addison','16 W 561 Shore Dr, Addison, IL 60101',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9887,41.9314,NULL),NULL,NULL),0800,1700,15,3,'+1-630-555-0132');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Wood Dale Aircraft Parts','Wood Dale','Wood Dale','155 E Irving Park Rd, Wood Dale, IL 60191',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9848,41.9639,NULL),NULL,NULL),0700,1600,20,2,'+1-630-555-0133');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Bensenville Freight Terminal','Bensenville','Bensenville','333 N York Rd, Bensenville, IL 60106',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9445,41.9561,NULL),NULL,NULL),0500,2000,30,1,'+1-630-555-0134');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Franklin Park Steel','Franklin Park','Franklin Park','9401 Mannheim Rd, Franklin Park, IL 60131',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8781,41.9317,NULL),NULL,NULL),0600,1600,25,2,'+1-708-555-0135');

-- --- WESTERN SUBURBS ---
INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Northlake Chemical Co','Northlake','Northlake','301 N Wolf Rd, Northlake, IL 60164',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9008,41.9139,NULL),NULL,NULL),0700,1600,20,2,'+1-708-555-0136');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Berkeley Food Service','Berkeley','Berkeley','5420 St Charles Rd, Berkeley, IL 60163',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8995,41.8894,NULL),NULL,NULL),0500,1200,20,1,'+1-708-555-0137');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Hillside Data Center Supplies','Hillside','Hillside','4343 Frontage Rd, Hillside, IL 60162',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.9062,41.8714,NULL),NULL,NULL),0800,1700,15,3,'+1-708-555-0138');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Maywood Medical Distributors','Maywood','Maywood','400 S 17th Ave, Maywood, IL 60153',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.8408,41.8800,NULL),NULL,NULL),0700,1500,25,1,'+1-708-555-0139');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Berwyn Industrial Coatings','Berwyn','Berwyn','6725 W Cermak Rd, Berwyn, IL 60402',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.7940,41.8503,NULL),NULL,NULL),0700,1600,20,3,'+1-708-555-0140');

-- --- SOUTH SIDE ---
INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Pilsen Arts Foundation','Pilsen','Chicago','1947 S Halsted St, Chicago, IL 60608',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6620,41.8546,NULL),NULL,NULL),1000,1800,15,3,'+1-312-555-0141');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Bridgeport Auto Parts','Bridgeport','Chicago','3150 S Halsted St, Chicago, IL 60608',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6546,41.8357,NULL),NULL,NULL),0700,1700,20,3,'+1-312-555-0142');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Hyde Park Laboratory','Hyde Park','Chicago','5801 S Ellis Ave, Chicago, IL 60637',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.5935,41.8027,NULL),NULL,NULL),0800,1800,25,2,'+1-312-555-0143');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Woodlawn Community Grocers','Woodlawn','Chicago','6333 S Cottage Grove Ave, Chicago, IL 60637',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.5992,41.7828,NULL),NULL,NULL),0600,1200,30,1,'+1-312-555-0144');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Chatham Building Materials','Chatham','Chicago','7943 S Cottage Grove Ave, Chicago, IL 60619',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6215,41.7498,NULL),NULL,NULL),0700,1600,20,3,'+1-312-555-0145');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Roseland Emergency Clinic','Roseland','Chicago','11117 S Michigan Ave, Chicago, IL 60628',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6287,41.6903,NULL),NULL,NULL),0000,2359,15,1,'+1-312-555-0146');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Kenwood Estate Wines','Kenwood','Chicago','4800 S Cottage Grove Ave, Chicago, IL 60615',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.5993,41.8173,NULL),NULL,NULL),1100,1900,15,3,'+1-312-555-0147');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Bronzeville Recording Studio','Bronzeville','Chicago','3500 S King Dr, Chicago, IL 60616',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6169,41.8360,NULL),NULL,NULL),1000,2000,10,3,'+1-312-555-0148');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Douglas Textile Factory','Douglas','Chicago','3600 S State St, Chicago, IL 60609',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-87.6211,41.8422,NULL),NULL,NULL),0700,1600,20,2,'+1-312-555-0149');

INSERT INTO fleet_customers (customer_name,neighborhood,city,address,location,time_window_open,time_window_close,service_minutes,priority,contact_phone)
VALUES ('Streamwood Plastics Corp','Streamwood','Streamwood','1035 W Irving Park Rd, Streamwood, IL 60107',SDO_GEOMETRY(2001,4326,SDO_POINT_TYPE(-88.1681,41.9908,NULL),NULL,NULL),0700,1600,20,3,'+1-630-555-0150');

COMMIT;
PROMPT    50 customers inserted.

-- ============================================================
-- SECTION 4: ORDERS  (75 orders for a single demo day)
--   Delivery date: SYSDATE + 1 (tomorrow = demo day)
--   Mix of urgency, weight, volume
-- ============================================================
PROMPT  Inserting 75 delivery orders...

DECLARE
  v_del_date DATE := TRUNC(SYSDATE) + 1;

  -- Assign depot based on customer geography (simple proximity logic)
  FUNCTION get_depot(p_cust_id NUMBER) RETURN NUMBER IS
    v_depot NUMBER;
  BEGIN
    -- Depot 1 (NW): customers 16-20, 26-27, 33-35
    -- Depot 3 (W):  customers 13-15, 21, 28-36
    -- Depot 2 (Central): everything else
    SELECT CASE
      WHEN p_cust_id IN (16,17,18,19,20,26,27,33,34,35,36) THEN 1
      WHEN p_cust_id IN (13,14,15,21,28,29,30,31,32,37,38,39,40,50) THEN 3
      ELSE 2
    END INTO v_depot FROM DUAL;
    RETURN v_depot;
  END;

  PROCEDURE ins_order(
    p_cust NUMBER, p_ref VARCHAR2,
    p_wt NUMBER, p_vol NUMBER, p_pri NUMBER,
    p_notes VARCHAR2 DEFAULT NULL
  ) IS
    v_depot NUMBER;
  BEGIN
    v_depot := get_depot(p_cust);   -- local fn call must be in PL/SQL, not SQL
    INSERT INTO fleet_orders (customer_id, depot_id, order_ref, order_date,
        delivery_date, weight_kg, volume_m3, priority, status, delivery_notes)
    VALUES (p_cust, v_depot, p_ref, TRUNC(SYSDATE), v_del_date,
        p_wt, p_vol, p_pri, 'PENDING', p_notes);
  END;

BEGIN
  -- Priority 1 (URGENT) orders – tight time windows
  ins_order( 6,'ORD-2026-0001', 450.0,1.8,1,'TEMPERATURE SENSITIVE – deliver before 10am');
  ins_order( 7,'ORD-2026-0002', 120.0,0.5,1,'Medical grade – signature required');
  ins_order(10,'ORD-2026-0003', 680.0,2.4,1,'Kitchen open at 5am – MUST be there by 5:30');
  ins_order(19,'ORD-2026-0004', 280.0,1.1,1,'Pre-market delivery 0600');
  ins_order(44,'ORD-2026-0005', 320.0,1.3,1,'24-hr freight terminal – dock 4');
  ins_order(46,'ORD-2026-0006',  80.0,0.4,1,'Emergency medical supplies');
  ins_order(20,'ORD-2026-0007', 540.0,2.0,1,'Airport catering – airside clearance needed');
  ins_order( 9,'ORD-2026-0008', 380.0,1.6,1,'Roaster needs beans by 5am');
  ins_order(16,'ORD-2026-0009', 260.0,1.0,1,'Pharma cold chain – GDP compliant');
  ins_order(37,'ORD-2026-0010', 420.0,1.7,1,'Hospital resupply – urgent');

  -- Priority 2 (HIGH) orders
  ins_order( 1,'ORD-2026-0011', 980.0,3.5,2,'Call 30 min ahead');
  ins_order( 4,'ORD-2026-0012',1200.0,4.2,2,'Loading dock B');
  ins_order(11,'ORD-2026-0013', 560.0,2.1,2,'Refrigerated items – see notes');
  ins_order(13,'ORD-2026-0014', 840.0,3.0,2,'Weekend restock');
  ins_order(14,'ORD-2026-0015',1400.0,5.0,2,'Heavy item – pallet jack required');
  ins_order(22,'ORD-2026-0016', 720.0,2.8,2,'Call on arrival');
  ins_order(23,'ORD-2026-0017',1650.0,6.2,2,'Second-floor delivery');
  ins_order(24,'ORD-2026-0018', 480.0,1.8,2,'Fragile – antique materials');
  ins_order(25,'ORD-2026-0019',1100.0,4.1,2,'Loading dock A, side entrance');
  ins_order(26,'ORD-2026-0020', 660.0,2.5,2,'Aerospace parts – handle with care');
  ins_order(35,'ORD-2026-0021', 790.0,3.1,2,'Dock 12');
  ins_order(39,'ORD-2026-0022', 540.0,2.2,2,'Park on north side');
  ins_order(43,'ORD-2026-0023', 620.0,2.4,2,'Gate code: 4821');
  ins_order(47,'ORD-2026-0024', 460.0,1.8,2,'Refrigerated unit on truck required');
  ins_order(48,'ORD-2026-0025', 840.0,3.3,2,'Data centre loading bay – ID needed');

  -- Priority 3 (NORMAL) orders – bulk of the work
  ins_order( 2,'ORD-2026-0026', 320.0,1.2,3,NULL);
  ins_order( 3,'ORD-2026-0027', 460.0,1.7,3,NULL);
  ins_order( 5,'ORD-2026-0028', 180.0,0.8,3,'Art handling required');
  ins_order( 8,'ORD-2026-0029', 240.0,0.9,3,NULL);
  ins_order(12,'ORD-2026-0030', 580.0,2.1,3,NULL);
  ins_order(15,'ORD-2026-0031', 760.0,2.9,3,NULL);
  ins_order(17,'ORD-2026-0032', 940.0,3.6,3,'Convention centre service entrance');
  ins_order(18,'ORD-2026-0033',1300.0,4.8,3,'Campus mail room');
  ins_order(21,'ORD-2026-0034', 620.0,2.3,3,NULL);
  ins_order(27,'ORD-2026-0035', 880.0,3.4,3,'Arlington office park – gate 3');
  ins_order(28,'ORD-2026-0036',1100.0,4.0,3,'Showroom delivery – suit up');
  ins_order(29,'ORD-2026-0037', 740.0,2.8,3,NULL);
  ins_order(30,'ORD-2026-0038', 600.0,2.3,3,'Farm gate – right before silo');
  ins_order(31,'ORD-2026-0039', 520.0,2.0,3,NULL);
  ins_order(32,'ORD-2026-0040', 680.0,2.6,3,NULL);
  ins_order(33,'ORD-2026-0041', 980.0,3.7,3,'Factory receiving – 8am–4pm only');
  ins_order(34,'ORD-2026-0042',1250.0,4.7,3,NULL);
  ins_order(36,'ORD-2026-0043', 440.0,1.7,3,NULL);
  ins_order(38,'ORD-2026-0044', 700.0,2.7,3,NULL);
  ins_order(40,'ORD-2026-0045', 560.0,2.2,3,NULL);
  ins_order(41,'ORD-2026-0046', 480.0,1.9,3,NULL);
  ins_order(42,'ORD-2026-0047', 820.0,3.1,3,'Side door, ring bell');
  ins_order(45,'ORD-2026-0048', 360.0,1.4,3,NULL);
  ins_order(49,'ORD-2026-0049',1060.0,4.1,3,NULL);
  ins_order(50,'ORD-2026-0050', 490.0,1.9,3,'After 7am only');

  -- Repeat customers with second orders (realistic – larger accounts)
  ins_order( 4,'ORD-2026-0051', 800.0,3.0,2,'Second delivery – afternoon slot');
  ins_order(10,'ORD-2026-0052', 440.0,1.7,2,'Lunch service resupply');
  ins_order(16,'ORD-2026-0053', 180.0,0.7,1,'Afternoon pharma run');
  ins_order(19,'ORD-2026-0054', 310.0,1.2,1,'Evening slot – 4–6pm');
  ins_order(25,'ORD-2026-0055',1400.0,5.3,2,'PM delivery accepted after 1pm');
  ins_order(33,'ORD-2026-0056', 720.0,2.7,2,'Afternoon shift delivery');
  ins_order(44,'ORD-2026-0057', 480.0,1.8,2,'Dock 7 – evening');
  ins_order( 1,'ORD-2026-0058', 640.0,2.4,3,'PM run');
  ins_order(13,'ORD-2026-0059', 560.0,2.1,3,'Spare parts – urgent but flexitime');
  ins_order(23,'ORD-2026-0060', 900.0,3.4,2,'Furniture – dolly available');
  ins_order( 6,'ORD-2026-0061', 200.0,0.8,1,'Same-day add-on – temperature critical');
  ins_order( 7,'ORD-2026-0062',  90.0,0.4,1,'Second medical delivery – afternoon clinic');
  ins_order(11,'ORD-2026-0063', 380.0,1.5,2,'Catering pickup add-on');
  ins_order(34,'ORD-2026-0064',1100.0,4.2,2,'Freight – two-man lift');
  ins_order(41,'ORD-2026-0065', 340.0,1.3,3,NULL);
  ins_order(47,'ORD-2026-0066', 280.0,1.1,1,'Refrigerant – urgent afternoon');
  ins_order( 2,'ORD-2026-0067', 220.0,0.9,3,NULL);
  ins_order(18,'ORD-2026-0068', 860.0,3.3,3,'Afternoon campus delivery');
  ins_order(28,'ORD-2026-0069',1050.0,4.0,2,'Showroom – afternoon appointment');
  ins_order(15,'ORD-2026-0070', 430.0,1.7,3,NULL);
  ins_order(22,'ORD-2026-0071', 500.0,1.9,2,'Store back entrance');
  ins_order(27,'ORD-2026-0072',1200.0,4.6,2,'PM delivery cleared');
  ins_order(30,'ORD-2026-0073', 380.0,1.5,3,NULL);
  ins_order(42,'ORD-2026-0074', 660.0,2.5,3,'Ring buzzer – unit 4B');
  ins_order( 8,'ORD-2026-0075', 290.0,1.1,3,'Print job ready at 2pm');

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  75 orders inserted.');
END;
/

-- ============================================================
-- SECTION 5: TRAFFIC ZONES  (Chicago congestion polygons)
-- ============================================================
PROMPT  Inserting traffic zone polygons...

INSERT INTO fleet_traffic_zones (zone_name, zone_type, zone_boundary,
    peak_am_factor, peak_pm_factor, avg_speed_kmh, zone_notes)
VALUES (
    'Chicago CBD (The Loop)', 'CBD',
    -- Approximate polygon of The Loop
    SDO_GEOMETRY(2003, 4326, NULL,
        SDO_ELEM_INFO_ARRAY(1,1003,1),
        SDO_ORDINATE_ARRAY(
            -87.643,41.870, -87.613,41.870, -87.613,41.890,
            -87.643,41.890, -87.643,41.870
        )),
    0.45, 0.40, 18.0,
    'Heavy congestion. Parking restrictions. Loading zones only 6–9am and 3–6pm.'
);

INSERT INTO fleet_traffic_zones (zone_name, zone_type, zone_boundary,
    peak_am_factor, peak_pm_factor, avg_speed_kmh, zone_notes)
VALUES (
    'O''Hare Airport Zone', 'AIRPORT',
    SDO_GEOMETRY(2003, 4326, NULL,
        SDO_ELEM_INFO_ARRAY(1,1003,1),
        SDO_ORDINATE_ARRAY(
            -87.940,41.950, -87.870,41.950, -87.870,42.010,
            -87.940,42.010, -87.940,41.950
        )),
    0.60, 0.55, 28.0,
    'Airport access restrictions. Security checkpoints. Allow extra 20 min.'
);

INSERT INTO fleet_traffic_zones (zone_name, zone_type, zone_boundary,
    peak_am_factor, peak_pm_factor, avg_speed_kmh, zone_notes)
VALUES (
    'I-290 Eisenhower Expressway Corridor', 'HIGHWAY',
    SDO_GEOMETRY(2003, 4326, NULL,
        SDO_ELEM_INFO_ARRAY(1,1003,1),
        SDO_ORDINATE_ARRAY(
            -87.900,41.860, -87.620,41.860, -87.620,41.880,
            -87.900,41.880, -87.900,41.860
        )),
    0.50, 0.45, 25.0,
    'Peak hour stop-and-go. Prefer I-88 or surface roads during peaks.'
);

INSERT INTO fleet_traffic_zones (zone_name, zone_type, zone_boundary,
    peak_am_factor, peak_pm_factor, avg_speed_kmh, zone_notes)
VALUES (
    'North Shore Residential', 'RESIDENTIAL',
    SDO_GEOMETRY(2003, 4326, NULL,
        SDO_ELEM_INFO_ARRAY(1,1003,1),
        SDO_ORDINATE_ARRAY(
            -87.730,42.020, -87.650,42.020, -87.650,42.100,
            -87.730,42.100, -87.730,42.020
        )),
    0.80, 0.75, 35.0,
    'School zones active 7–9am and 3–5pm. Parking restrictions apply.'
);

INSERT INTO fleet_traffic_zones (zone_name, zone_type, zone_boundary,
    peak_am_factor, peak_pm_factor, avg_speed_kmh, zone_notes)
VALUES (
    'Cicero-Berwyn Industrial Corridor', 'INDUSTRIAL',
    SDO_GEOMETRY(2003, 4326, NULL,
        SDO_ELEM_INFO_ARRAY(1,1003,1),
        SDO_ORDINATE_ARRAY(
            -87.800,41.830, -87.700,41.830, -87.700,41.870,
            -87.800,41.870, -87.800,41.830
        )),
    0.70, 0.65, 32.0,
    'Heavy truck traffic. Weight restrictions on residential side streets.'
);

COMMIT;
PROMPT    5 traffic zones inserted.

PROMPT
PROMPT ============================================================
PROMPT  Seed data complete.
PROMPT
PROMPT  Depots   :  3   (O''Hare NW, McCormick Central, Cicero W)
PROMPT  Vehicles : 15   (5 per depot, mix of types)
PROMPT  Customers: 50   (Chicago metro area)
PROMPT  Orders   : 75   (tomorrow''s delivery day)
PROMPT  Zones    :  5   (traffic congestion polygons)
PROMPT ============================================================
PROMPT  Next: run  @sql/03_baseline_routes.sql
PROMPT ============================================================
PROMPT
