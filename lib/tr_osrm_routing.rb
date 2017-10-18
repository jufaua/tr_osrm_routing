require 'open-uri'
module TrOSRMRouting
  
  def self.route(geographies = [], options = {})
    default_options = {
      :mode                        => :walking,
      :default_speed_m_s           => Rails.application.config.default_walking_speed,
      :api_url                     => nil,
      :added_distance_and_duration => true,
      :geographic_factory          => TrGeometry::GEOGRAPHIC_FACTORY,
      :instructions                => false,
      :zoom                        => nil,
      :polyline                    => true,
      :geojson                     => false,
      :geography                   => false,
      :departure_date              => nil, #"0000/00/00"
      :arrival_date                => nil,   #"0000/00/00"
      :departure_time              => nil, #"00:00"
      :arrival_time                => nil,   #"00:00"
      :return_all_stops_result     => false,
      :max_number_of_transfers     => 9999,
      :min_waiting_time            => 3,
      :starting_stop_id            => nil,
      :server_port                 => nil,
      :use_matching_algorithm      => false,
      #:match_long_distance_api_url => nil,
      :match_radius                => 20,
      :transfer_penalty_minutes    => 0,
      :only_service_ids            => nil,
      :by_number_of_transfers      => false,
      :max_travel_time_minutes     => nil,
      :max_access_travel_time_seconds   => 1200,
      :max_egress_travel_time_seconds   => 1200,
      :max_transfer_travel_time_seconds => 1200,
      :matching_legs               => false, # fetch matching legs (distance and duration of each leg)
      :server                      => nil # Optional TrOSRMRoutingServer object, takes precedence over mode and api_url
    }
    options            = default_options.merge(options)
    default_speed_m_s  = options[:default_speed_m_s].to_f
    geographic_factory = options[:geographic_factory]
    routing_mode       = options[:mode].to_sym
    api_url            = options[:api_url] || Rails.application.config.osrm_routing_api_urls[routing_mode]
    #match_long_distance_api_url = options[:match_long_distance_api_url] || Rails.application.config.osrm_routing_api_urls[(routing_mode.to_s+"_match_long_distance").to_sym]
    server             = options[:server]
    server_port        = options[:server_port]
    geojson            = options[:geojson]
    geography          = options[:geography]
    algorithm          = options[:use_matching_algorithm] ? 'match' : 'route'
    match_radius       = options[:match_radius].to_i # meters
    match_timestamp_interval = 100 # seconds
    
    if server_port
      api_url.gsub!(/:[0-9]{1,5}\//,":" + server_port.to_s + "/")
    end
    
    if server
      api_url = "http://127.0.0.1:#{server.port}/route/v1/" + routing_mode
      #until server.ready? # make sure the server is ready, or wait for readiness
      #end
    end
    
    if algorithm == 'match'
      api_url = api_url.gsub('/route/', '/match/')
    end
    
    geographies_query  = ""
    geographies.each_with_index do |geography, i|
      if geography.is_a?(String)
        geography = geographic_factory.point(geography.split(",").last, geography.split(",").first)
        geographies[i] = geography
      end
      if geography.is_a?(Array)
        geography = geographic_factory.point(geography[1], geography[0])
        geographies[i] = geography
      end
      geographies_query += ";#{geography.lon},#{geography.lat}"
    end
    
    radiuses   = []
    timestamps = []
    if algorithm == 'match'
      geographies.size.times do |i|
        radiuses.push(match_radius)
        timestamps.push(i * match_timestamp_interval)
      end
    end
    
    origin_geography      = nil
    destination_geography = nil
    if geographies.any?
      origin_geography      = geographies.first
      destination_geography = geographies.last
    end
    
    if options[:mode] == :transit
      
      departure_date                   = options[:departure_date]
      arrival_date                     = options[:arrival_date]
      departure_time                   = options[:departure_time]
      arrival_time                     = options[:arrival_time]
      return_all_stops_result          = options[:return_all_stops_result]
      detailed                         = options[:detailed]
      min_waiting_time                 = options[:min_waiting_time]
      max_travel_time_minutes          = options[:max_travel_time_minutes] || 9999
      max_number_of_transfers          = options[:max_number_of_transfers]
      only_service_ids                 = options[:only_service_ids]
      by_num_transfers                 = options[:by_number_of_transfers]
      transfer_penalty_minutes         = options[:transfer_penalty_minutes] || 0
      max_access_travel_time_minutes   = options[:max_access_travel_time_seconds]   ? (options[:max_access_travel_time_seconds].to_f   / 60).ceil : 20
      max_egress_travel_time_minutes   = options[:max_egress_travel_time_seconds]   ? (options[:max_egress_travel_time_seconds].to_f   / 60).ceil : max_access_travel_time_minutes
      max_transfer_travel_time_minutes = options[:max_transfer_travel_time_seconds] ? (options[:max_transfer_travel_time_seconds].to_f / 60).ceil : 20
      if options[:starting_stop_id]
        routing_query = "#{api_url}?starting_stop_id=#{options[:starting_stop_id]}&destination=#{destination_geography ? destination_geography.lat : 0},#{destination_geography ? destination_geography.lon : 0}&date=#{departure_date || arrival_date}&time=#{departure_time || arrival_time}&return_all_stops_result=#{ return_all_stops_result ? 'true' : 'false' }&reverse=#{ arrival_time ? 'true' : 'false' }&detailed=#{ detailed ? 'true' : 'false' }&max_number_of_transfers=#{ max_number_of_transfers }&min_waiting_time=#{ min_waiting_time }&max_travel_time=#{ max_travel_time_minutes }&max_access_travel_time_minutes=#{max_access_travel_time_minutes}&max_egress_travel_time_minutes=#{max_egress_travel_time_minutes}&max_transfer_travel_time_minutes=#{max_transfer_travel_time_minutes}&by_num_transfers=#{by_num_transfers ? 'true' : 'false' }&transfer_penalty_minutes=#{ transfer_penalty_minutes}#{ only_service_ids && only_service_ids.any? ? '&only_service_ids=' + only_service_ids.join(',') : ''}"
      elsif geographies.any?
        routing_query = "#{api_url}?origin=#{origin_geography.lat},#{origin_geography.lon}&destination=#{destination_geography.lat},#{destination_geography.lon}&date=#{departure_date || arrival_date}&time=#{departure_time || arrival_time}&return_all_stops_result=#{ return_all_stops_result ? 'true' : 'false' }&reverse=#{ arrival_time ? 'true' : 'false' }&detailed=#{ detailed ? 'true' : 'false' }&max_number_of_transfers=#{ max_number_of_transfers }&min_waiting_time=#{ min_waiting_time }&max_travel_time=#{ max_travel_time_minutes }&max_access_travel_time_minutes=#{max_access_travel_time_minutes}&max_egress_travel_time_minutes=#{max_egress_travel_time_minutes}&max_transfer_travel_time_minutes=#{max_transfer_travel_time_minutes}&by_num_transfers=#{by_num_transfers ? 'true' : 'false' }&transfer_penalty_minutes=#{ transfer_penalty_minutes}#{ only_service_ids && only_service_ids.any? ? '&only_service_ids=' + only_service_ids.join(',') : ''}"
      else
        raise "no geographies provided"
      end
      #puts routing_query
      #puts open(routing_query).read
      routing = Oj.load(open(routing_query).read) rescue nil
      #ap routing
      if routing && (routing["status"] || routing["stops"])
        
        routing["query"] = routing_query
        return routing
        
      else
        
        return {"status" => "failed", "query" => routing_query}
        
      end
      
      return nil
      
    else
      
      added_distance        = 0
      added_duration        = 0
      network_distance      = nil
      network_duration      = nil
      instructions          = nil
      polyline              = nil
      success               = nil
      if algorithm == 'match'
        routing_query         = "#{api_url}/#{geographies_query[1..-1]}?timestamps=#{timestamps.join(';')}&radiuses=#{radiuses.join(';')}&overview=full&geometries=geojson"
      else
        routing_query         = "#{api_url}/#{geographies_query[1..-1]}?alternatives=false&steps=#{options[:instructions] ? 'true' : 'false'}&overview=full&geometries=geojson"
      end
      route_geojson         = nil
      route_geography       = nil
      # debugging:
      #puts routing_query
      
      routing = Oj.load(open(routing_query).read) rescue nil
      
      #ap routing
      
      routes = []
      match_missing_points_count = 0
      
      if routing && algorithm == 'route' && routing["routes"] && routing["routes"].any?
        routes = routing["routes"]
      elsif routing && algorithm == 'match'  && routing["matchings"] && routing["matchings"].any?
        routes = routing["matchings"]
        match_missing_points_count = routing["tracepoints"].count{|tracepoint| tracepoint.nil? || tracepoint == 'null'}
        #if match_missing_points_count > 0 # if problem, match using long distance router
        #  routing_query = "#{match_long_distance_api_url}/#{geographies_query[1..-1]}?timestamps=#{timestamps.join(';')}&radiuses=#{radiuses.join(';')}&overview=full&geometries=geojson"
        #  routing = Oj.load(open(routing_query).read) rescue nil
        #  if routing && algorithm == 'match'  && routing["matchings"] && routing["matchings"].any?
        #    routes = routing["matchings"]
        #    match_missing_points_count = routing["tracepoints"].count{|tracepoint| tracepoint.nil? || tracepoint == 'null'}
        #  end
        #end
      end
      
      #if algorithm == 'match' && (routes.nil? || (routes && routes[0].nil?)) # if problem, match using long distance router
      #  routing_query = "#{match_long_distance_api_url}/#{geographies_query[1..-1]}?timestamps=#{timestamps.join(';')}&radiuses=#{radiuses.join(';')}&overview=full&geometries=geojson"
      #  routing = Oj.load(open(routing_query).read) rescue nil
      #  if routing && algorithm == 'match'  && routing["matchings"] && routing["matchings"].any?
      #    routes = routing["matchings"]
      #    match_missing_points_count = routing["tracepoints"].count{|tracepoint| tracepoint.nil? || tracepoint == 'null'}
      #  end
      #end
      
      if routes && routes[0]
        success           = true
        network_distance  = routes[0]["distance"].to_i
        network_duration  = routes[0]["duration"].to_i
        polyline          = routes[0]["geometry"]["coordinates"].map{ |coordinate| [coordinate[1], coordinate[0]] } # reverse lat/lon, osrm v5 now respond in geojson (lon,lat)
        
        if options[:instructions] # not yet implemented
          instructions = routes[0]["legs"] # needs redesign here since osrm instructions have changed in v5
        end
        
        matching_legs = []
        
        if algorithm == 'match' && options[:matching_legs] && routes[0]["legs"]
          matching_legs = routes[0]["legs"].map{|leg| {:distance => leg["distance"], :duration => leg["duration"]}}
        end
        
        if options[:added_distance_and_duration]
          polyline.insert( 0, [ origin_geography.lat,      origin_geography.lon      ])
          polyline.insert(-1, [ destination_geography.lat, destination_geography.lon ])
          added_distance        = geographic_factory.point(*polyline[0].reverse).distance(geographic_factory.point(*polyline[1].reverse)) + geographic_factory.point(*polyline[-2].reverse).distance(geographic_factory.point(*polyline[-1].reverse)).ceil
          added_duration        = (added_distance.to_f / default_speed_m_s).ceil
          network_distance     += added_distance
          network_duration     += added_duration
        end
        if options[:polyline] == false
          polyline = nil
        end
        
        if options[:geography] == true && polyline
          route_geography = TrGeometry::GEOGRAPHIC_FACTORY.line_string(polyline.map{ |point| TrGeometry::GEOGRAPHIC_FACTORY.point(point[1], point[0]) })
        end
        
        if options[:geojson] == true && polyline
          
          route_geography = TrGeometry::GEOGRAPHIC_FACTORY.line_string(polyline.map{ |point| TrGeometry::GEOGRAPHIC_FACTORY.point(point[1], point[0]) }) unless route_geography
          
          route_geojson = RGeo::GeoJSON::Feature.new(route_geography, nil, {
            :distance_meters        => (network_distance.round(0) rescue nil),
            :duration_seconds       => (network_duration.round(0) rescue nil),
            :added_distance_meters  => (added_distance.round(0) rescue nil),
            :added_duration_seconds => (added_duration.round(0) rescue nil),
            :mode                   => routing_mode.to_s
          })
          
        end
        
      else
        success = false
      end
      return {
        :status                     => ( success ? :success : :failed ),
        :distance                   => (network_distance.round(0) rescue nil),
        :duration                   => (network_duration.round(0) rescue nil),
        :polyline                   => polyline,
        :geography                  => route_geography,
        :geojson                    => RGeo::GeoJSON.encode(route_geojson),
        :instructions               => instructions,
        :added_distance             => (added_distance.round(0) rescue nil),
        :added_duration             => (added_duration.round(0) rescue nil),
        :matching_legs              => matching_legs,
        :match_missing_points_count => match_missing_points_count
      }
        
    
    end
    
    return {}
    
  end

  def self.nearest(geography, number_of_nearest_points = 1, options = {})
    default_options = {
      :mode                        => :walking,
      :api_url                     => nil,
      :geographic_factory          => TrGeometry::GEOGRAPHIC_FACTORY,
      :server_port                 => nil,
      :server                      => nil # Optional TrOSRMRoutingServer object, takes precedence over mode and api_url
    }
    options            = default_options.merge(options)
    geographic_factory = options[:geographic_factory]
    routing_mode       = options[:mode].to_sym
    api_url            = options[:api_url] || Rails.application.config.osrm_routing_api_urls[routing_mode]
    server             = options[:server]
    server_port        = options[:server_port]
    
    if server_port
      api_url.gsub!(/:[0-9]{1,5}\//,":" + server_port.to_s + "/")
    end
    
    if server
      api_url = "http://127.0.0.1:#{server.port}/nearest/v1/" + routing_mode
      #until server.ready? # make sure the server is ready, or wait for readiness
      #end
    end
    geography_query  = ""
    if geography.is_a?(String)
      geography = geographic_factory.point(geography.split(",").last, geography.split(",").first)
    end
    if geography.is_a?(Array)
      geography = geographic_factory.point(geography[1], geography[0])
    end
    geography_query += ";#{geography.lon},#{geography.lat}"
    
    routing_query = "#{api_url.gsub('/route/','/nearest/')}/#{geography_query[1..-1]}?number=#{number_of_nearest_points}"
    #puts routing_query
    routing = Oj.load(open(routing_query).read) rescue nil
    
    results = []
    
    if routing && routing["waypoints"] && routing["waypoints"].any?
      
      routing["waypoints"].each do |nearest_point|
        results.push({ geography: geographic_factory.point(nearest_point["location"].first, nearest_point["location"].last), distance: nearest_point["distance"].round, way_name: nearest_point["name"] })
      end
      success = true
              
    else
      
      success = false
      
    end
    
    return {
      :status         => ( success ? :success : :failed ),
      :nearest_points => results
    }
    
  end

## Needs verification:
#  def self.distance_matrix_route_from_file(file_path)
#    file = File.open(file_path, "r")
#    file_content = ""
#    until file.eof?
#      file_content << file.read(2**16)
#    end
#
#    routing = Oj.load(file_content)# rescue nil 
#    if routing && routing["durations"]
#      return routing["durations"].map{ |point_durations| point_durations.map!{ |duration| duration }} # raw results are in seconds since osrm v5
#    else
#      return nil
#    end
#  end
  
  def self.tsp_reorder(geographies = [], options = {})
    default_options = {
      :mode                        => :walking,
      :source                      => "first",
      :destination                 => "last",
      :roundtrip                   => false,
      :default_speed_m_s           => Rails.application.config.default_walking_speed,
      :api_url                     => nil,
      :geographic_factory          => TrGeometry::GEOGRAPHIC_FACTORY,
      :server_port                 => nil,
      :server                      => nil # Optional TrOSRMRoutingServer object, takes precedence over mode and api_url
    }
    options            = default_options.merge(options)
    default_speed_m_s  = options[:default_speed_m_s].to_f
    geographic_factory = options[:geographic_factory]
    routing_mode       = options[:mode].to_sym
    api_url            = options[:api_url] || Rails.application.config.osrm_routing_api_urls[routing_mode]
    server             = options[:server]
    server_port        = options[:server_port]
    
    if server_port
      api_url.gsub!(/:[0-9]{1,5}\//,":" + server_port.to_s + "/")
    end
    
    if server
      api_url = "http://127.0.0.1:#{server.port}/trip/v1/" + routing_mode
      #until server.ready? # make sure the server is ready, or wait for readiness
      #end
    end
    geographies_query  = ""
    geographies.each_with_index do |geography, i|
      if geography.is_a?(String)
        geography = geographic_factory.point(geography.split(",").last, geography.split(",").first)
        geographies[i] = geography
      end
      if geography.is_a?(Array)
        geography = geographic_factory.point(geography[1], geography[0])
        geographies[i] = geography
      end
      geographies_query += ";#{geography.lon},#{geography.lat}"
      
    end
    
    network_distance      = nil
    network_duration      = nil
    success               = nil
    routing_query         = "#{api_url.gsub('/route/','/trip/')}/#{geographies_query[1..-1]}?steps=false&source=#{options[:source]}&destination=#{options[:destination]}&roundtrip=#{options[:roundtrip].to_s}&overview=false&geometries=geojson&annotations=false"
    # debugging:
    #puts routing_query
    
    optimal_order = nil
    
    routing = Oj.load(open(routing_query).read) rescue nil
    
    if routing && routing["waypoints"] && routing["waypoints"].any?
      success           = true
      optimal_order = []
      routing["waypoints"].each do |waypoint|
        optimal_order.push(waypoint["waypoint_index"])
      end
    else
      success = false
    end      
      
    return {
      :status         => ( success ? :success : :failed ),
      :optimal_order  => optimal_order
    }
    
  end
  
  def self.table(geographies = [], options = {})
    self.distance_matrix_route(geographies, options)
  end
  
  def self.distance_matrix_route(geographies = [], options = {})
    default_options = {
      :mode => :walking,
      :api_url => nil, 
      :geographic_factory => TrGeometry::GEOGRAPHIC_FACTORY,
      :server => nil # Optional TrOSRMRoutingServer object, takes precedence over mode and api_url
    }
    options            = default_options.merge(options)
    geographic_factory = options[:geographic_factory]
    routing_mode       = options[:mode].to_sym
    api_url            = options[:api_url] || Rails.application.config.osrm_routing_distance_table_api_urls[routing_mode]
    server             = options[:server]
    if server
      api_url = "http://127.0.0.1:#{server.port}/table/v1/" + routing_mode
      #until server.ready? # make sure the server is ready, or wait for readiness
      #end
    end
    geographies_query  = ""
    geo  = false
    str  = false
    arr  = false
    geographies.each_with_index do |geography, i|
      if    geo || geography.respond_to?(:lat)
        geographies_query += ";#{geography.lon},#{geography.lat}"
        geo = true
      elsif str || geography.is_a?(String)
        geography = geographic_factory.point(geography.split(",").last, geography.split(",").first)
        geographies_query += ";#{geography.lon},#{geography.lat}"
        str = true
      elsif arr || geography.is_a?(Array)
        geographies_query += ";#{geography[1]},#{geography[0]}"
        arr = true
      else
        return nil
      end
    end
    
    query = "#{api_url}/"+geographies_query[1..-1] # [1..-1] is to remove the first & character from query
    #puts query
    #uri_query = URI(query)
    #ap uri_query.request_uri
    #puts uri_query.query.size.to_s
    #Net::HTTP.start(uri_query) do |http|
    #  ap http.request
    #  
    #end
    #return ""
    #f = File.new("/Users/admin/Desktop/test.json", "w+")
    #result = open(query, 'Accept-Encoding' => '', :read_timeout => nil).read
    #f.write(result)
    routing = Oj.load(open(query, 'Accept-Encoding' => '', :read_timeout => nil).read)# rescue nil 
    if routing && routing["durations"]
      return routing["durations"]#.map{ |point_durations| point_durations.map!{ |duration| duration }} # raw results are in seconds since osrm v5
    else
      return nil
    end
  end
  
  def self.index_of_nearest_from_origin(origin_geography, geographies = [], options = {})
    default_options = {
      :mode => :walking,
      :api_url => nil, 
      :geographic_factory => TrGeometry::GEOGRAPHIC_FACTORY,
      :server => nil # Optional TrOSRMRoutingServer object, takes precedence over mode and api_url
    }
    options            = default_options.merge(options)
    geographic_factory = options[:geographic_factory]
    routing_mode       = options[:mode].to_sym
    api_url            = options[:api_url] || Rails.application.config.osrm_routing_distance_table_api_urls[routing_mode]
    server             = options[:server]
    if server
      api_url = "http://127.0.0.1:#{server.port}/table/v1/" + routing_mode + "?sources=0"
      #until server.ready? # make sure the server is ready, or wait for readiness
      #end
    end
    geographies_query  = ""
    geo  = false
    str  = false
    arr  = false
    
    if origin_geography.respond_to?(:lat)
      geographies_query += ";#{origin_geography.lon},#{origin_geography.lat}"
    elsif origin_geography.is_a?(String)
      origin_geography = geographic_factory.point(origin_geography.split(",").last, origin_geography.split(",").first)
      geographies_query += ";#{origin_geography.lon},#{origin_geography.lat}"
    elsif origin_geography.is_a?(Array)
      geographies_query += ";#{origin_geography[1]},#{origin_geography[0]}"
    else
      return nil
    end
    
    geographies.each_with_index do |geography, i|
      if    geo || geography.respond_to?(:lat)
        geographies_query += ";#{geography.lon},#{geography.lat}"
        geo = true
      elsif str || geography.is_a?(String)
        geography = geographic_factory.point(geography.split(",").last, geography.split(",").first)
        geographies_query += ";#{geography.lon},#{geography.lat}"
        str = true
      elsif arr || geography.is_a?(Array)
        geographies_query += ";#{geography[1]},#{geography[0]}"
        arr = true
      else
        return nil
      end
    end
    
    query = "#{api_url}/"+geographies_query[1..-1]+"?sources=0" # [1..-1] is to remove the first & character from query
    #puts query
    #uri_query = URI(query)
    #ap uri_query.request_uri
    #puts uri_query.query.size.to_s
    #Net::HTTP.start(uri_query) do |http|
    #  ap http.request
    #  
    #end
    #return ""
    #f = File.new("/Users/admin/Desktop/test.json", "w+")
    #result = open(query, 'Accept-Encoding' => '', :read_timeout => nil).read
    #f.write(result)
    routing = Oj.load(open(query, 'Accept-Encoding' => '', :read_timeout => nil).read)# rescue nil 
    if routing && routing["durations"] && routing["durations"][0]
      min_duration = routing["durations"][0][1..-1].min
      min_index    = routing["durations"][0][1..-1].index(min_duration)
      return { :min_index => min_index, :min_duration => min_duration }
    else
      return nil
    end
  end
  
  def self.one_to_many_table_distance(origin_geography, geographies = [], options = {})
    default_options = {
      :mode => :walking,
      :api_url => nil, 
      :geographic_factory => TrGeometry::GEOGRAPHIC_FACTORY,
      :server => nil # Optional TrOSRMRoutingServer object, takes precedence over mode and api_url
    }
    options            = default_options.merge(options)
    geographic_factory = options[:geographic_factory]
    routing_mode       = options[:mode].to_sym
    api_url            = options[:api_url] || Rails.application.config.osrm_routing_distance_table_api_urls[routing_mode]
    server             = options[:server]
    if server
      api_url = "http://127.0.0.1:#{server.port}/table/v1/" + routing_mode
      #until server.ready? # make sure the server is ready, or wait for readiness
      #end
    end
    geographies_query  = ""
    geo  = false
    str  = false
    arr  = false
    
    if origin_geography.respond_to?(:lat)
      geographies_query += ";#{origin_geography.lon},#{origin_geography.lat}"
    elsif origin_geography.is_a?(String)
      origin_geography = geographic_factory.point(origin_geography.split(",").last, origin_geography.split(",").first)
      geographies_query += ";#{origin_geography.lon},#{origin_geography.lat}"
    elsif origin_geography.is_a?(Array)
      geographies_query += ";#{origin_geography[1]},#{origin_geography[0]}"
    else
      return nil
    end
    
    if geographies.is_a?(String)
      geographies_query += ";" + geographies
    else
       geographies.each_with_index do |geography, i|
        if    geo || geography.respond_to?(:lat)
          geographies_query += ";#{geography.lon},#{geography.lat}"
          geo = true
        elsif str || geography.is_a?(String)
          geography = geographic_factory.point(geography.split(",").last, geography.split(",").first)
          geographies_query += ";#{geography.lon},#{geography.lat}"
          str = true
        elsif arr || geography.is_a?(Array)
          geographies_query += ";#{geography[1]},#{geography[0]}"
          arr = true
        else
          return nil
        end
      end
    end
    
    query = "#{api_url}/"+geographies_query[1..-1]+"?sources=0" # [1..-1] is to remove the first ; character from query
    #puts query
    #uri_query = URI(query)
    #ap uri_query.request_uri
    #puts uri_query.query.size.to_s
    #Net::HTTP.start(uri_query) do |http|
    #  ap http.request
    #  
    #end
    #return ""
    #f = File.new("/Users/admin/Desktop/test.json", "w+")
    #result = open(query, 'Accept-Encoding' => '', :read_timeout => nil).read
    #f.write(result)
    routing = Oj.load(open(query, 'Accept-Encoding' => '', :read_timeout => nil).read)# rescue nil 
    if routing && routing["durations"] && routing["durations"][0]
      return routing["durations"][0][1..-1]
    else
      return nil
    end
  end
  
end
