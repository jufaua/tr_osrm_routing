require 'tr_osrm_routing'
require 'rails'
module TrOSRMRouting
  class Railtie < Rails::Railtie
    railtie_name :tr_osrm_routing
  end
end
