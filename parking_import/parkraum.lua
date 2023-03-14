local json = require('dkjson')
local srid = 4326
local srid_metric = 25833
local import_schema = os.getenv("PG_SCHEMA_IMPORT")
local tables = {}

--TODO don't use boolean for oneway
tables.highways = osm2pgsql.define_table({
    name = "highways",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'type', type = 'text' }, --highway
        { column = 'surface', type = 'text' },
        { column = 'service', type = 'text' },
        { column = 'dual_carriageway', type = 'bool' },
        { column = 'lanes', sql_type = 'numeric' },
        { column = 'name', type = 'text' },
        { column = 'oneway', type = 'bool' },
        { column = 'parking_left_orientation', type = 'text' },
        { column = 'parking_left_offset', sql_type = 'numeric' },
        { column = 'parking_left_position', type = 'text' },
        { column = 'parking_left_width', sql_type = 'numeric' },
        { column = 'parking_left_width_carriageway', sql_type = 'numeric' },
        { column = 'parking_right_orientation', type = 'text' },
        { column = 'parking_right_offset', sql_type = 'numeric' },
        { column = 'parking_right_position', type = 'text' },
        { column = 'parking_right_width', sql_type = 'numeric' },
        { column = 'parking_right_width_carriageway', sql_type = 'numeric' },
        { column = 'parking_width_proc', sql_type = 'numeric' },
        { column = 'parking_width_proc_effective', sql_type = 'numeric' },
        { column = 'parking_left_capacity', sql_type = 'numeric' },
        { column = 'parking_right_capacity', sql_type = 'numeric' },
        { column = 'parking_left_source_capacity', type = 'text' },
        { column = 'parking_right_source_capacity', type = 'text' },
        { column = 'error_output', type = 'jsonb' },
        { column = 'geom', type = 'linestring', projection = srid, not_null = true }
    }
})

tables.service = osm2pgsql.define_table({
    name = "service",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'type', type = 'text' }, --highway
        { column = 'surface', type = 'text' },
        { column = 'service', type = 'text' },
        { column = 'dual_carriageway', type = 'bool' },
        { column = 'lanes', sql_type = 'numeric' },
        { column = 'name', type = 'text' },
        { column = 'oneway', type = 'bool' },
        { column = 'parking_left_orientation', type = 'text' },
        { column = 'parking_left_offset', sql_type = 'numeric' },
        { column = 'parking_left_position', type = 'text' },
        { column = 'parking_left_width', sql_type = 'numeric' },
        { column = 'parking_left_width_carriageway', sql_type = 'numeric' },
        { column = 'parking_right_orientation', type = 'text' },
        { column = 'parking_right_offset', sql_type = 'numeric' },
        { column = 'parking_right_position', type = 'text' },
        { column = 'parking_right_width', sql_type = 'numeric' },
        { column = 'parking_right_width_carriageway', sql_type = 'numeric' },
        { column = 'parking_width_proc', sql_type = 'numeric' },
        { column = 'parking_width_proc_effective', sql_type = 'numeric' },
        { column = 'parking_left_capacity', sql_type = 'numeric' },
        { column = 'parking_right_capacity', sql_type = 'numeric' },
        { column = 'parking_left_source_capacity', type = 'text' },
        { column = 'parking_right_source_capacity', type = 'text' },
        { column = 'error_output', type = 'jsonb' },
        { column = 'geom', type = 'linestring', projection = srid, not_null = true }
    }
})

tables.footways = osm2pgsql.define_table({
    name = "footways",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'footway', type = 'text' },
        { column = 'surface', type = 'text' },
        { column = 'is_sidepath:of', type = 'text' },
        { column = 'is_sidepath:of:name', type = 'text' },
        { column = 'error_output', type = 'jsonb' },
        { column = 'geom', type = 'linestring', projection = srid, not_null = true }
    }
})

tables.parking_poly = osm2pgsql.define_table({
    name = "parking_poly",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'amenity', type = 'text' },
        { column = 'access', type = 'text' },
        { column = 'capacity', sql_type = 'numeric' },
        { column = 'parking', type = 'text' },
        { column = 'building', type = 'text' },
        { column = 'parking_orientation', type = 'text' },
        { column = 'area', type = 'real' },
        { column = 'error_output', type = 'jsonb' },
        { column = 'geom', type = 'geometry', projection = srid, not_null = true }
    }
})

tables.obstacle_poly = osm2pgsql.define_table({
    name = "obstacle_poly",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'advertising', type = 'text' },
        { column = 'amenity', type = 'text' },
        { column = 'barrier', type = 'text' },
        { column = 'highway', type = 'text' },
        { column = 'leisure', type = 'text' },
        { column = 'man_made', type = 'text' },
        { column = 'natural', type = 'text' },
        { column = 'capacity', sql_type = 'numeric' },
        { column = 'buffer', sql_type = 'numeric' },
        { column = 'error_output', type = 'jsonb' },
        { column = 'geom', type = 'geometry', projection = srid, not_null = true }
    }
})

tables.obstacle_point = osm2pgsql.define_table({
    name = "obstacle_point",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'advertising', type = 'text' },
        { column = 'amenity', type = 'text' },
        { column = 'barrier', type = 'text' },
        { column = 'highway', type = 'text' },
        { column = 'leisure', type = 'text' },
        { column = 'man_made', type = 'text' },
        { column = 'natural', type = 'text' },
        { column = 'capacity', sql_type = 'numeric' },
        { column = 'buffer', sql_type = 'numeric' },
        { column = 'error_output', type = 'jsonb' },
        { column = 'geom', type = 'point', projection = srid, not_null = true }
    }
})

tables.area_highway = osm2pgsql.define_table({
    name = "area_highway",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'amenity', type = 'text' },
        { column = 'access', type = 'text' },
        { column = 'parking', type = 'text' },
        { column = 'area_highway', type = 'text' },
        { column = 'highway', type = 'text' },
        { column = 'footway', type = 'text' },
        { column = 'surface', type = 'text' },
        { column = 'bicycle', type = 'text' },
        { column = 'area', type = 'real' },
        { column = 'error_output', type = 'jsonb' },
        { column = 'geom', type = 'geometry', projection = srid, not_null = true }
    }
})

tables.crossings = osm2pgsql.define_table({
    name = "crossings",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'highway', type = 'text' },
        { column = 'crossing', type = 'text' },
        { column = 'crossing_ref', type = 'text' },
        { column = 'kerb', type = 'text' },
        { column = 'crossing_buffer_marking', type = 'text' },
        { column = 'crossing_kerb_extension', type = 'text' },
        { column = 'traffic_signals_direction', type = 'text' },
        { column = 'geom', type = 'point', projection = srid, not_null = true }
    }
})

tables.pt_platform = osm2pgsql.define_table({
    name = "pt_platform",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'name', type = 'text' },
        { column = 'bus', type = 'text' },
        { column = 'tram', type = 'text' },
        { column = 'railway', type = 'text' },
        { column = 'highway', type = 'text' },
        { column = 'error_output', type = 'jsonb' },
        { column = 'geom', type = 'linestring', projection = srid, not_null = true }
    }
})

tables.pt_stops = osm2pgsql.define_table({
    name = "pt_stops",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'name', type = 'text' },
        { column = 'public_transport', type = 'text' },
        { column = 'highway', type = 'text' },
        { column = 'bus', type = 'bool' },
        { column = 'tram', type = 'bool' },
        { column = 'railway', type = 'text' },
        { column = 'subway', type = 'bool' },
        { column = 'light_rail', type = 'bool' },
        { column = 'geom', type = 'point' , projection = srid, not_null = true}
    }
})

tables.ramps = osm2pgsql.define_table({
    name = "ramps",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'operator', type = 'text' },
        { column = 'kerb', type = 'text' },
        { column = 'geom', type = 'point', projection = srid, not_null = true }
    }
})

tables.amenity_parking_points = osm2pgsql.define_table({
    name = "amenity_parking_points",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'amenity', type = 'text' },
        { column = 'access', type = 'text' },
        { column = 'capacity', sql_type = 'numeric' },
        { column = 'bicycle', type = 'text' },
        { column = 'small_electric_vehicle', sql_type = 'text' },
        { column = 'small_vehicle_parking_position', type = 'text' },
        { column = 'parking', type = 'text' },
        { column = 'parking_position', type = 'text' },
        { column = 'geom', type = 'point' , projection = srid, not_null = true}
    }
})

tables.traffic_calming_points = osm2pgsql.define_table({
    name = "traffic_calming_points",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'traffic_calming', type = 'text' },
        { column = 'priority', type = 'text' },
        { column = 'geom', type = 'point' , projection = srid, not_null = true}
    }
})

tables.boundaries = osm2pgsql.define_table({
    name = "boundaries",
    schema = import_schema,
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only = true },
        { column = 'name', type = 'text' },
        { column = 'admin_level', sql_type = 'numeric' },
        { column = 'area', type = 'real' },
        { column = 'geom', type = 'geometry', projection = srid, not_null = true }
    }
})

local highway_list = {
  'primary',
  'primary_link',
  'secondary',
  'secondary_link',
  'tertiary',
  'tertiary_link',
  'residential',
  'living_street',
  'pedestrian',
  'road',
  'unclassified',
  'construction'
}

-- Prepare table 'highway_types' for quick checking of highway types
local highway_types = {}
for _, k in ipairs(highway_list) do
    highway_types[k] = 1
end

-- default width of streets (if not specified more precisely on the data object)
local width_minor_street = 11
local width_primary_street = 17
local width_secondary_street = 15
local width_tertiary_street = 13
local width_service = 4
local width_driveway = 2.5

-- default width of parking lanes (if not specified more precisely on the data object)
local width_para = 2   -- parallel parking -----
local width_diag = 4.5 -- diagonal parking /////
local width_perp = 5   -- perpendicular p. |||||

-- parking space length / distance per vehicle depending on parking direction
-- TODO: Attention: In some calculation steps that use field calculator formulas, these values are currently still hardcoded – if needed, the formulas would have to be generated as a string using these variables
local vehicle_dist_para = 5.2     -- parallel parking
local vehicle_dist_diag = 3.1     -- diagonal parking (angle: 60 gon = 54°)
local vehicle_dist_perp = 2.5     -- perpendicular parking
local vehicle_length = 4.4        -- average vehicle length (a single vehicle, without manoeuvring distance)
local vehicle_width = 1.8         -- average vehicle width

-- list of highway tags that do not belong to the regular road network but are also analysed
local service_list = {'service', 'track', 'bus_guideway', 'footway', 'cycleway', 'path'}

-- Prepare table 'service_types' for quick checking of service types
local service_types = {}
for _, k in ipairs(service_list) do
    service_types[k] = 1
end

local crossing_list = {
'crossing',
'traffic_signals',

}
local rev_highway_crossing_types = {}
for _, k in ipairs(crossing_list) do
    rev_highway_crossing_types[k] = 1
end

local orientation_keys = {
  'parallel',
  'perpendicular',
  'diagonal'
}
local rev_orientation = {}
for _, k in ipairs(orientation_keys) do
    rev_orientation[k] = 1
end

local position_keys = {
  'lane',
  'half_on_kerb',
  'on_kerb',
  'street_side',
  'shoulder',
  'no',
  'separate',
  'yes'
}
local rev_position = {}
for _, k in ipairs(position_keys) do
    rev_position[k] = 1
end

local parking_keys = {
  'parallel',
  'perpendicular',
  'diagonal',
  'marked'
}
local rev_parking = {}
for _, k in ipairs(parking_keys) do
    rev_parking[k] = 1
end

local bicycle_parking_position_keys = {
  'driveway',
  'kerb_extension',
  'lane',
  'parking_lane',
  'service_way',
  'street_side',
  'traffic_island',
  'shoulder'
}
local rev_bicycle_parking_position = {}
for _, k in ipairs(bicycle_parking_position_keys) do
    rev_bicycle_parking_position[k] = 1
end

local amenity_position_keys = {
  'lane',
  'street_side',
  'shoulder',
  'kerb_extension'
}
local rev_amenity_position = {}
for _, k in ipairs(amenity_position_keys) do
    rev_amenity_position[k] = 1
end

local crossing_allowed_values = {
    'marked',
    'unmarked',
    'uncontrolled',
    'zebra',
    'traffic_signals',
    'no',
    'island'
}
local rev_crossing_allowed_values = {}
for _, k in ipairs(crossing_allowed_values) do
    rev_crossing_allowed_values[k] = 1
end

local area_highway_values = {
  'prohibited',
  'uncontrolled',
}
local rev_area_highway_values = {}
for _, k in ipairs(area_highway_values) do
    rev_area_highway_values[k] = 1
end

local crossing_exclude_values = {
  'uncontrolled',
}
local rev_crossing_exclude_values = {}
for _, k in ipairs(crossing_exclude_values) do
    rev_crossing_exclude_values[k] = 1
end


function trim(s)
   return s:match"^()%s*$" and "" or s:match"^%s*(.*%S)"
end

function remove_whitespace(s)
  return s:gsub("%s+", "")
end

function obstacle_buffer(object)

    local buffer_default          = 0.5 --default for all other objects
    local buffer_street_lamp      = 0.4
    local buffer_tree             = 1.5
    local buffer_street_cabinet   = 1.5
    local buffer_bollard          = 0.3
    local buffer_advertising      = 1.4
    local buffer_recycling        = 5.0
    local buffer_traffic_sign     = 0.3
    local buffer_bicycle_parking  = 1.6 --per stand - per capacity / 2
    local buffer_sev_parking      = 5.0 --small electric vehicle parking
    local buffer_parklet          = 5.0
    local buffer_loading_ramp     = 2.0

    local buffer = buffer_default

    if object.tags["highway"] == 'street_lamp' then
        buffer = buffer_street_lamp
    end
    if object.tags["natural"] == 'tree' then
        buffer = buffer_tree
    end
    if object.tags["man_made"] == 'street_cabinet' then
        buffer = buffer_street_cabinet
    end
    if object.tags["barrier"] == 'bollard' or object.tags["barrier"] == 'collision_protection' then
        buffer = buffer_bollard
    end
    if object.tags["advertising"] then
        buffer = buffer_advertising
    end
    if object.tags["amenity"] == 'recycling' then
        buffer = buffer_recycling
    end
    if object.tags["highway"] == 'traffic_sign' or object.tags["barrier"] == 'barrier_board' then
        buffer = buffer_traffic_sign
    end
    if object.tags["amenity"] == 'bicycle_parking' then
        buffer = buffer_bicycle_parking
    end
    if object.tags["leisure"] == 'parklet' or object.tags["leisure"] == 'outdoor_seating' then
        buffer = buffer_parklet
    end
    if object.tags["amenity"] == 'loading_ramp' then
        buffer = buffer_loading_ramp
    end
    if object.tags["amenity"] == 'bicycle_parking' or object.tags["amenity"] == 'motorcycle_parking' or object.tags["amenity"] == 'bicycle_rental' then
        local capacity = parse_units(object.tags["capacity"]) or 2
        buffer = (math.min(capacity, 10) / 2) * buffer_bicycle_parking --limit size to capacity = 10 - better use polygons to map larger bicycle parkings!
    end
    if object.tags["amenity"] == 'small_electric_vehicle_parking' then
        buffer = buffer_sev_parking
    end

    return buffer

end

function parse_units(input)
    -- from parking_import/flex-config/data-types.lua
    if not input then
        return nil
    end

    local width = tonumber(input)

    -- If width is just a number, just return it
    if width then
        return width
    end

    width = remove_whitespace(trim(input))
    -- If there is an 'cm', 'm', 'ft' at the end, remove unit and return
    if width:sub(-2) == "cm" then
        local num = tonumber(width:sub(1, -3))
        if num then
            return num / 100
        end
    end

    if width:sub(-1) == "m" then
        local num = tonumber(width:sub(1, -2))
        if num then
          return num
        end
    end

    if input:sub(-2) == 'ft' then
        local num = tonumber(input:sub(1, -3))
        if num then
            return num * 0.3048
        end
    end

    return nil
end


function Split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function has_area_tags(tags)
    if tags.area == 'yes' then
        return true
    end
    if tags.area == 'no' then
        return false
    end

    return false
end

function osm2pgsql.process_way(object)

    if object.tags["obstacle:parking"] == "yes"
    then
        local obstacle_buffer =  obstacle_buffer(object)

        tables.obstacle_poly:insert({
            advertising = object.tags["advertising"],
            amenity = object.tags["amenity"],
            barrier = object.tags["barrier"],
            highway = object.tags["highway"],
            leisure = object.tags["leisure"],
            man_made = object.tags["man_made"],
            natural = object.tags["natural"],
            capacity = object.tags["capacity"],
            buffer = obstacle_buffer,
            error_output = object.tags["error_output"],
            geom = object:as_polygon()
        })
    end

    -- process public transport objects and push them to db table
    local public_transport = object.tags["public_transport"]
    if public_transport == "platform"
    then
        tables.pt_platform:insert({
            name = object.tags["name"],
            bus = object.tags["bus"],
            tram = object.tags["tram"],
            railway = object.tags["railway"],
            highway = object.tags["highway"],
            geom = object:as_linestring()
        })
        return
    end

    -- process parking objects and push them to db table
    local p_amenity = object.tags["amenity"]
    local p_leisure = object.tags["leisure"]
    if object.is_closed and p_amenity == "parking"
    then
        local geom = object:as_polygon()
        tables.parking_poly:insert({
            amenity = p_amenity,
            access = object.tags["access"],
            capacity = parse_units(object.tags["capacity"]),
            building = object.tags["building"],
            parking = object.tags["parking"],
            parking_orientation = object.tags["parking:orientation"],
            area = geom:transform(3857):area(),
            geom = geom
        })
        return
    end

    -- process bicycle_parking objects and push them to db table
    if object.is_closed and (
        p_amenity == "bicycle_parking" or
        p_leisure == "parklet" or
        (p_amenity == "bicycle_rental" and rev_amenity_position[object.tags["bicycle_rental:position"]]) or
        (p_amenity == "motorcycle_parking" and (rev_amenity_position[object.tags["motorcycle_parking:position"]] or rev_amenity_position[object.tags["parking"]])) or
        (p_amenity == "small_electric_vehicle_parking" and rev_amenity_position[object.tags["small_electric_vehicle_parking:position"]]) or
        (object.tags["bicycle_rental:position"] == 'yes')
    )
    then
        local geom = object:as_polygon()
        tables.parking_poly:insert({
            amenity = p_amenity,
            access = object.tags["access"],
            capacity = parse_units(object.tags["capacity"]),
            parking = object.tags["bicycle_parking:position"],
            area = geom:transform(3857):area(),
            geom = geom
        })
        return
    end

    local area_highway = object.tags["area:highway"]
    if object.is_closed and rev_area_highway_values[area_highway]
    then
        local geom = object:as_polygon()
        tables.area_highway:insert({
            amenity = p_amenity,
            access = object.tags["access"],
            parking = object.tags["parking"],
            highway = object.tags["highway"],
            footway = object.tags["footway"],
            bicycle = object.tags["bicycle"],
            area_highway = area_highway,
            area = geom:transform(3857):area(),
            geom = geom
        })
        return
    end

    -- ignore all objects with area=yes from now
    if has_area_tags(object.tags) then
        return
    end

    local type = object.tags["highway"]

    -- We are only interested in highways of the given highway/service types
    if not highway_types[type] and not service_types[type] then
        return
    end

--    local pl_both = nil
    local pl_error_output = {}

    local name = object.tags["name"]

--    local p_left_position = object.tags["parking:left:position"]
--    local p_right_position = object.tags["parking:right:position"]
    local p_left_width = object.tags["parking:left:width"]
    local p_right_width = object.tags["parking:right:width"]
    local p_left_width_carriageway = object.tags["parking:left:width:carriageway"]
    local p_right_width_carriageway = object.tags["parking:right:width:carriageway"]
    local p_left_offset = object.tags["parking:left:offset"]
    local p_right_offset = object.tags["parking:right:offset"]

    local p_condition_left = nil --object:grab_tag('parking:condition:left')
    local p_condition_right = nil --object:grab_tag('parking:condition:right')
    local p_condition_left_other = nil --object:grab_tag('parking:condition:left:other')
    local p_condition_right_other = nil --object:grab_tag('parking:condition:right:other')
    local p_condition_left_other_time = nil --object:grab_tag('parking:condition:left:other:time')
    local p_condition_right_other_time = nil --object:grab_tag('parking:condition:right:other:time')
    local p_condition_left_default = nil --object:grab_tag('parking:condition:left:default')
    local p_condition_right_default = nil --object:grab_tag('parking:condition:right:default')
    local p_condition_left_time_interval = nil --object:grab_tag('parking:condition:left:time_interval')
    local p_condition_right_time_interval = nil --object:grab_tag('parking:condition:right:time_interval')
    local p_condition_left_maxstay = nil --object:grab_tag('parking:condition:left:maxstay')
    local p_condition_right_maxstay = nil --object:grab_tag('parking:condition:right:maxstay')
    local p_left_capacity = nil --object:grab_tag('parking:left:capacity')
    local p_right_capacity = nil --object:grab_tag('parking:right:capacity')

    local p_condition_both = object.tags["parking:condition:both"]
    local p_condition_both_other = object.tags["parking:condition:both:other"]
    local p_condition_both_other_time = object.tags["parking:condition:both:other:time"]
    local p_condition_both_default = object.tags["parking:condition:both:default"]
    local p_condition_both_time_interval = object.tags["parking:condition:both:time_interval"]
    local p_condition_both_maxstay = object.tags["parking:condition:both:maxstay"]
    local p_both_capacity = object.tags["parking:both:capacity"]

    local constr = object.tags["construction"]

    local width_proc = nil

    for i,side in ipairs{"left","right"} do
        local p_position = nil
        local p_orientation = nil
        local p_source_capacity = nil
        local p_condition_side_default = nil
        local p_condition_side = nil
        local p_condition = nil
        local cond = nil
        local p_condition_other_time = nil
        local p_condition_other = nil

        if object.tags["parking:" .. side] == nil then
            if object.tags["parking:both"] ~= nil then
                p_position = object.tags["parking:both"]
            else
                table.insert(pl_error_output, {
                    error = "pl01" .. side:sub(1),
                    side = side:sub(1),
                    msg = "Attribute 'parking:" .. side .. "' und 'parking:both' gleichzeitig vorhanden. "
                })
            end
        else
            if object.tags["parking:both"] == nil then
                p_position = object.tags["parking:" .. side]
            else
                table.insert(pl_error_output, {
                    error = "pl01" .. side:sub(1),
                    side = side:sub(1),
                    msg = "Attribute 'parking:" .. side .. "' und 'parking:both' gleichzeitig vorhanden. "
                })
            end
        end

        if object.tags["parking:" .. side .. ":orientation"] == nil then
            if object.tags["parking:both:orientation"] ~= nil then
                p_orientation = object.tags["parking:both:orientation"]
            else
                table.insert(pl_error_output, {
                    error = "pl01" .. side:sub(1),
                    side = side:sub(1),
                    msg = "Attribute 'parking:" .. side .. ":orientation' und 'parking:both:orientation' gleichzeitig vorhanden. "
                })
            end
        else
            if object.tags["parking:both:orientation"] == nil then
                p_orientation = object.tags["parking:" .. side .. ":orientation"]
            else
                table.insert(pl_error_output, {
                    error = "pl01" .. side:sub(1),
                    side = side:sub(1),
                    msg = "Attribute 'parking:" .. side .. ":orientation' und 'parking:both:orientation' gleichzeitig vorhanden. "
                })
            end
        end

        if p_position then
            -- Parkstreifen-Regeln (und Abweichungen) ermitteln (kostenfrei, Ticket, Halte-/Parkverbote zu bestimmten Zeiten...)
            p_condition_side_default = object.tags["parking:condition:" .. side .. ":default"]

            if p_condition_both_default ~= nil then
                if p_condition_side_default ~= nil then
                    table.insert(pl_error_output, {
                        error = "pc02" .. side:sub(1),
                        side = side,
                        msg = 'Attribute "parking:condition:' .. side .. ':default" und "parking:condition:both:default" gleichzeitig vorhanden. '
                    })
                else
                    p_condition_side_default = p_condition_both_default
                end
            end

            p_condition_side = object.tags["parking:condition:" .. side]
            if p_condition_side_default == nil then
                if p_condition_side ~= nil and p_condition_both ~= nil then
                    table.insert(pl_error_output, {
                        error = "pc02" .. side:sub(1),
                        side = side,
                        msg = 'Attribute "parking:condition:' .. side .. '" und "parking:condition:both" gleichzeitig vorhanden. '
                    })
                end
                if p_condition_side == nil then
                    p_condition = p_condition_both
                end
            else
                p_condition = p_condition_side_default
                cond = p_condition_side
                if cond and p_condition_both then
                    table.insert(pl_error_output, {
                        error = "pc02" .. side:sub(1),
                        side = side,
                        msg = 'Attribute "parking:condition:' .. side .. '" und "parking:condition:both" gleichzeitig vorhanden. '
                    })
                end
                if cond == nil then
                    cond = p_condition_both
                end
                if p_condition_side ~= nil then
                end
                -- Mögliche conditional-Schreibweisen auflösen - Achtung, fehleranfällig, wenn andere conditions als Zeitangaben verwendet werden!
                if cond then
                    -- Zeichen @ suchen
                    pos = string.find(cond, '@')
                    if  pos == nil then
                        -- Wert verwenden
                        p_condition_other = cond
                    else
                        -- Wert aufteilen in condition und Zeitangabe, Klammern beginnende/endende Leerzeichen entfernen
                        splitstring = Split(cond, "@")
                        p_condition_other = trim(splitstring[1])
                        p_condition_other_time = trim(splitstring[2]):gsub("[()]", "")
                    end
                end
            end

            -- Parkstreifenbreite ermitteln
            parking_side_width = parse_units(object.tags["parking:" .. side .. ":width"])
            parking_both_width = parse_units(object.tags["parking:both:width"])
            --parking_side_position = object.tags["parking:" .. side]
            if parking_both_width ~= nil then
                if parking_side_width == nil then parking_side_width = parking_both_width
                else
                    table.insert(pl_error_output, {
                        error = "pl03" .. side:sub(1),
                        side = side,
                        msg = "Attribute 'parking:" .. side ..":width' und 'parking:both:width' gleichzeitig vorhanden. "
                    })
                end
            end
            -- Parkstreifenbreite aus Parkrichtung abschätzen, wenn nicht genauer angegeben
            if parking_side_width == nil then
                parking_side_width = 0
                if p_orientation == "parallel" then parking_side_width = width_para end
                if p_orientation == "diagonal" then parking_side_width = width_diag end
                if p_orientation == "perpendicular" then parking_side_width = width_perp end
            end

        end


        -- Segmente ignorieren, an denen ausschließlich Park- und Halteverbot besteht
        if (p_condition == 'no_parking' and p_condition_other == 'no_stopping') or (p_condition == 'no_stopping' and p_condition_other == 'no_parking') then
            return
        end
        local p_condition_time_interval_side = object.tags['parking:condition:' .. side .. ':time_interval']
        if p_condition_time_interval_side ~= nil then
            if p_condition_other_time then
                table.insert(pl_error_output, {
                    error = "pc03" .. side:sub(1),
                    side = side,
                    msg = ' Zeitliche Parkbeschränkung sowohl im conditional-restrictions- als auch im parking:' .. side .. ':time_interval-Schema vorhanden. '
                })
            end
            p_condition_other_time_set = p_condition_time_interval_side
        else
            p_condition_other_time_set = nil
        end

        if p_condition_both_time_interval ~= nil then
            if p_condition_other_time_set then
                table.insert(pl_error_output, {
                    error = "pc04" .. side:sub(1),
                    side = side,
                    msg = ' Attribute "parking:condition:' .. side .. ':time_interval" und "parking:condition:both:time_interval" gleichzeitig vorhanden. '
                })
            end
            if p_condition_other_time_set == nil then
                p_condition_other_time_set = p_condition_both_time_interval
            end
        end
        if p_condition_other_time == nil then
            p_condition_other_time = p_condition_other_time_set
        end

        local p_condition_maxstay_side = object.tags['parking:condition:' .. side .. ':maxstay']
        if p_condition_both_maxstay ~= nil then
            if p_condition_maxstay_side then
                table.insert(pl_error_output, {
                    error = "pc05" .. side:sub(1),
                    side = side,
                    msg = ' Attribute "parking:condition:' .. side .. ':maxstay" und "parking:condition:both:maxstay" gleichzeitig vorhanden. '
                })
            else
                p_condition_maxstay_side = object.tags['parking:condition:both:maxstay']
            end
        end

        local p_side_capacity = object.tags['parking:' .. side .. ':capacity']
        local p_capacity = nil
        if p_both_capacity ~= nil then
            if p_side_capacity ~= nil then
                table.insert(pl_error_output, {
                    error = "pl01" .. side:sub(1),
                    side = side,
                    msg = 'Attribute "parking:' .. side .. ':capacity" und "parking:both:capacity" gleichzeitig vorhanden. '
                })
            else
                p_capacity = p_both_capacity
            end
        else
            p_capacity = p_side_capacity
        end
        if p_capacity ~= nil then
            p_source_capacity = 'OSM'
        end


        -- Offset der Parkstreifen für spätere Verschiebung ermitteln (offset-Linie liegt am Bordstein)
        local parking_side_width_carriageway = 0
        if rev_orientation[p_orientation] then
            parking_side_width_carriageway = parking_side_width
            if parking_position == "half_on_kerb" then
                parking_side_width_carriageway = parking_side_width_carriageway / 2
            end
            if rev_position[parking_position] then
                parking_side_width_carriageway = 0
            end
        end

        if side == "left" then
            p_left_orientation = p_orientation
            p_left_position = p_position
            p_left_width = parking_side_width
            p_left_width_carriageway = parking_side_width_carriageway
            p_condition_left_default = p_condition_side_default
            p_condition_left = p_condition
            p_condition_left_other = p_condition_other
            p_condition_left_other_time = p_condition_other_time
            p_condition_left_maxstay = p_condition_maxstay_side
            p_left_capacity = p_capacity
            p_left_source_capacity = p_source_capacity
        else
            p_right_orientation = p_orientation
            p_right_position = p_position
            p_right_width = parking_side_width
            p_right_width_carriageway = parking_side_width_carriageway
            p_condition_right_default= p_condition_side_default
            p_condition_right = p_condition
            p_condition_right_other = p_condition_other
            p_condition_right_other_time = p_condition_other_time
            p_condition_right_maxstay = p_condition_maxstay_side
            p_right_capacity = p_capacity
            p_right_source_capacity = p_source_capacity
        end

    end

    -- Fahrbahnbreite ermitteln
    -- Mögliche vorhandene Breitenattribute prüfen: width:carriageway, width, est_width
    local width = object.tags["width:carriageway"]

    if width == nil then width = object.tags["width"] end
    if width == nil then width = object.tags["est_width"] end
    -- Einheiten korrigieren
    if width ~= nil and parse_units(width) ~= nil then width = parse_units(width)
    -- Ansonsten Breite aus anderen Straßenattributen abschätzen
    else
        highway = object.tags["highway"]
        if highway == "primary" then width = width_primary_street end
        if highway == "secondary" then width = width_secondary_street end
        if highway == "tertiary" then width = width_tertiary_street end
        if service_types[highway] then
            width = width_service
            if object.tags["service"] == "driveway" then
                width = width_driveway
            end
        end
        if highway == "construction" then
            if constr ~= nil then
                construction = object.tags["highway"]
                if construction == "primary" then width = width_primary_street end
                if construction == "secondary" then width = width_secondary_street end
                if construction == "tertiary" then width = width_tertiary_street end
                if service_types[construction] then
                    width = width_service
                end
            end
        end
        if parse_units(width) == nil then width = width_minor_street end
    end
    width_proc = width

    local width_effective = 0
    --print(name, type, width, p_left_width_carriageway, p_right_width_carriageway)
    --print(object.id, name, type, p_left_orientation, p_right_orientation, p_left_position, p_right_position)
    if (parse_units(p_left_width_carriageway) ~= nil and parse_units(p_right_width_carriageway) ~= nil and parse_units(width) ~= nil ) then
        width_effective = tonumber(parse_units(width)) - tonumber(parse_units(p_left_width_carriageway)) - tonumber(parse_units(p_right_width_carriageway))
        p_left_offset = (width_effective / 2) + tonumber(parse_units(p_left_width_carriageway))
        p_right_offset = -(width_effective / 2) - tonumber(parse_units(p_right_width_carriageway))
    end

    if highway_types[type] then
        tables.highways:insert{
            type = type,
            surface = object.tags["surface"],
            name = name,
            service = object.tags["service"],
            oneway = object.tags["oneway"],
            dual_carriageway = object.tags["dual_carriageway"],
            lanes = parse_units(object.tags["lanes"]),
            parking_left_orientation = p_left_orientation,
            parking_right_orientation = p_right_orientation,
            parking_width_proc = width_proc,
            parking_width_proc_effective = width_effective,
            parking_left_position = p_left_position,
            parking_right_position = p_right_position,
            parking_left_width = p_left_width,
            parking_right_width = p_right_width,
            parking_left_width_carriageway = p_left_width_carriageway,
            parking_right_width_carriageway = p_right_width_carriageway,
            parking_left_offset = p_left_offset,
            parking_right_offset = p_right_offset,
            error_output  = json.encode(pl_error_output),
            parking_condition_left = p_condition_left,
            parking_condition_left_other = p_condition_left_other,
            parking_condition_right = p_condition_right,
            parking_condition_right_other = p_condition_right_other,
            parking_condition_left_other_time = p_condition_left_other_time,
            parking_condition_right_other_time = p_condition_right_other_time,
            parking_condition_left_default = p_condition_left_default,
            parking_condition_right_default = p_condition_right_default,
            parking_condition_left_time_interval = p_condition_left_time_interval,
            parking_condition_right_time_interval = p_condition_right_time_interval,
            parking_condition_left_maxstay = p_condition_left_maxstay,
            parking_condition_right_maxstay = p_condition_right_maxstay,
            parking_left_capacity = p_left_capacity,
            parking_right_capacity = p_right_capacity,
            parking_left_source_capacity = p_left_source_capacity,
            parking_right_source_capacity = p_right_source_capacity,
            geom = object:as_linestring()
        }

    else
    if service_types[type] then
        tables.service:insert{
            type = type,
            surface = object.tags["surface"],
            name = name,
            service = object.tags["service"],
            oneway = object.tags["oneway"],
            dual_carriageway = object.tags["dual_carriageway"],
            lanes = parse_units(object.tags["lanes"]),
            parking_left_orientation = p_left_orientation,
            parking_right_orientation = p_right_orientation,
            parking_width_proc = width_proc,
            parking_width_proc_effective = width_effective,
            parking_left_position = p_left_position,
            parking_right_position = p_right_position,
            parking_left_width = p_left_width,
            parking_right_width = p_right_width,
            parking_left_width_carriageway = p_left_width_carriageway,
            parking_right_width_carriageway = p_right_width_carriageway,
            parking_left_offset = p_left_offset,
            parking_right_offset = p_right_offset,
            error_output  = json.encode(pl_error_output),
            parking_condition_left = p_condition_left,
            parking_condition_left_other = p_condition_left_other,
            parking_condition_right = p_condition_right,
            parking_condition_right_other = p_condition_right_other,
            parking_condition_left_other_time = p_condition_left_other_time,
            parking_condition_right_other_time = p_condition_right_other_time,
            parking_condition_left_default = p_condition_left_default,
            parking_condition_right_default = p_condition_right_default,
            parking_condition_left_time_interval = p_condition_left_time_interval,
            parking_condition_right_time_interval = p_condition_right_time_interval,
            parking_condition_left_maxstay = p_condition_left_maxstay,
            parking_condition_right_maxstay = p_condition_right_maxstay,
            parking_left_capacity = p_left_capacity,
            parking_right_capacity = p_right_capacity,
            parking_left_source_capacity = p_left_source_capacity,
            parking_right_source_capacity = p_right_source_capacity,
            geom = object:as_linestring()
        }
    end
    end

end

function osm2pgsql.process_node(object)

    local crossing_check = object.tags["crossing"]
    if (object.tags["highway"] == "traffic_signals") or
            (object.tags["highway"] == "crossing" and rev_crossing_allowed_values[crossing_check])
    then
        tables.crossings:insert({
            highway = object.tags["highway"],
            crossing = object.tags["crossing"],
            crossing_ref = object.tags["crossing_ref"],
            kerb = object.tags["kerb"],
            crossing_buffer_marking = object.tags["crossing:buffer_marking"],
            crossing_kerb_extension = object.tags["crossing:kerb_extension"],
            traffic_signals_direction = object.tags["traffic_signals:direction"],
            geom = object:as_point()
        })
    end

    if object.tags["highway"] == "bus_stop" or
            object.tags["public_transport"] == "stop_position"
    then
        --print("add row")
        tables.pt_stops:insert({
            highway = object.tags["highway"],
            name = object.tags["name"],
            public_transport = object.tags["public_transport"],
            bus = object.tags["bus"],
            tram = object.tags["tram"],
            railway = object.tags["railway"],
            subway = object.tags["subway"],
            light_rail = object.tags["light_rail"],
            geom = object:as_point()
        })
    end

    if object.tags["amenity"] == "loading_ramp"
    then
        tables.ramps:insert{
            operator = object.tags["operator"],
            kerb = object.tags["kerb"],
            geom = object:as_point()
        }
    end

    if object.tags["traffic_calming"] ~= nil
    then
        tables.traffic_calming_points:insert{
            traffic_calming = object.tags["traffic_calming"],
            priority = object.tags["priority"],
            geom = object:as_point()
        }
    end

    -- process parking objects and push them to db table
    local p_amenity = object.tags["amenity"]
    if (p_amenity == "bicycle_parking" and rev_bicycle_parking_position[object.tags["bicycle_parking:position"]])
            or p_amenity == "small_vehicle_parking"
    then
        tables.amenity_parking_points:insert({
            amenity = p_amenity,
            access = object.tags["access"],
            capacity = parse_units(object.tags["capacity"]),
            bicycle = object.tags["bicycle"],
            small_electric_vehicle = object.tags["small_electric_vehicle"],
            small_vehicle_parking_position = object.tags["small_vehicle_parking:position"],
            parking = object.tags["bicycle_parking"],
            parking_position = object.tags["bicycle_parking:position"],
            geom = object:as_point()
        })
        return
    end

    if object.tags["obstacle:parking"] == "yes"
    then
        local obstacle_buffer =  obstacle_buffer(object)

        tables.obstacle_point:insert({
            advertising = object.tags["advertising"],
            amenity = object.tags["amenity"],
            barrier = object.tags["barrier"],
            highway = object.tags["highway"],
            leisure = object.tags["leisure"],
            man_made = object.tags["man_made"],
            natural = object.tags["natural"],
            capacity = object.tags["capacity"],
            buffer = obstacle_buffer,
            error_output = object.tags["error_output"],
            geom = object:as_point()
        })
    end



end


function osm2pgsql.process_relation(object)
    if object.tags.type == 'boundary' and
       object.tags.boundary == "administrative"
    then
        local geom = object:as_multipolygon()
        tables.boundaries:insert{
            name = object.tags["name"],
            admin_level = object.tags["admin_level"],
            area = geom:transform(3857):area(),
            geom = geom
        }
    end

    local p_amenity = object.tags["amenity"]
    if p_amenity == "parking"
    then
        local geom = object:as_multipolygon()
        tables.parking_poly:insert({
            amenity = p_amenity,
            access = object.tags["access"],
            capacity = parse_units(object.tags["capacity"]),
            building = object.tags["building"],
            parking = object.tags["parking"],
            parking_orientation = object.tags["parking:orientation"],
            area = geom:transform(3857):area(),
            geom = geom
        })
        return
    end



end

