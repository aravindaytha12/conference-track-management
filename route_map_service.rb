# Rm::RouteMapService.new
# All the common mothods across the Routes Manager are all here as protected methods
# These methods are used by the Extending Classes
class Rm::RouteMapService < Rm::BaseService
  attr_accessor :route_map_id, :route_map, :route_master, :route_master_id

  PAGE_SIZE = 25

  # route_map_id = -1 if the method calls are for Collection
  def initialize(route_map_id, route_master_id=nil)
    self.route_map_id = route_map_id
    self.route_map = Rm::RouteMap.find(route_map_id) if route_map_id != -1
    if route_master_id.present?
      self.route_master_id = route_master_id
      self.route_master = Rm::RouteMaster.find(route_master_id) if route_master_id != -1
    end
  end

  def new_route_map
    city_details_hash = _construct_route_map_attributes
    stages_count_hash = route_master.get_rm_stages_count  
    route_map_tree_obj = Rm::RouteMasterService.new(route_master.id).route_map_tree_structure(city_details_hash["city_pair_ids_arr"], city_details_hash["city_ids_arr"], stages_count_hash)
    return ObjReturn.new({city_details_hash: city_details_hash, route_map_tree_obj: route_map_tree_obj, route_master_name: route_master.name})
  end

  def route_map_form_data(obj_input)
    route_map = obj_input.route_map
    form_data = obj_input.form_data
    route_map_attributes = route_map.attributes
    route_map_attributes["name"] = form_data["rm_route_map"]["name"]
    route_map_attributes["description"] = form_data["rm_route_map"]["description"]
    route_map_attributes["origin"] = form_data["rm_route_map"]["origin"]
    route_map_attributes["destination"] = form_data["rm_route_map"]["destination"]
    route_map_attributes["route_master_id"] = route_master_id 
    route_map_attributes["skip_cities"] = form_data["rm_route_map"]["skip_cities"].present? ? (","+(form_data["rm_route_map"]["skip_cities"]).join(",")+",") : ""
    route_map_attributes["skip_city_pairs"] = form_data["rm_route_map"]["skip_city_pairs"].present? ? (","+(form_data["rm_route_map"]["skip_city_pairs"]).join(",")+",") : ""
    #TODO "Aravind", need confirmation for this.
    city_sequence_arr = route_master.cities_sequence.to_s.split(",").reject(&:empty?)
    skipped_cities  = route_map_attributes["skip_cities"].to_s.split(",").reject(&:empty?)
    final_city_seq = city_sequence_arr - skipped_cities
    route_map_attributes["cities_sequence"] = ",#{final_city_seq.join(',')},"
    route_map_attributes["status"] = "active"
    route_map_attributes
  end

  def create_route_map(obj_input)
    obj_input.ensure_arguments!(%w(form_data))
    form_data = obj_input.form_data
    route_map = Rm::RouteMap.new
    input_data = ObjInput.new({:route_map => route_map, :form_data => form_data})
    route_map.attributes = route_map_form_data(input_data)
    route_map.save
    return ObjReturn.new({:ar_object => route_map})
  end

  def edit_route_map
    city_details_hash = _construct_route_map_attributes
    stages_count_hash = route_master.get_rm_stages_count
    route_map_tree_obj = Rm::RouteMasterService.new(route_master_id).route_map_tree_structure(route_map.get_operated_city_pair_ids, route_map.get_operated_cities_ids, stages_count_hash)
    return ObjReturn.new({city_details_hash: city_details_hash, route_map_tree_obj: route_map_tree_obj})
  end

  def list(obj_input)
    selected_origin = obj_input.origin
    selected_destination = obj_input.destination
    if (obj_input.status.blank? && selected_origin.blank? && selected_destination.blank?)
      route_maps = Rm::RouteMap.where("route_master_id=? AND is_deleted=?", obj_input.rel_id, false).order(:name)
    else
      conditions = ["route_master_id=? AND is_deleted=?", obj_input.rel_id, false]
      if obj_input.status.present?
        conditions[0] += " AND status = ?" 
        conditions << obj_input.status
      end
      if selected_origin.present?
        conditions[0] += " AND origin = ?" 
        conditions << selected_origin
      end
      if selected_destination.present?
        conditions[0] += " AND destination = ?" 
        conditions << selected_destination
      end
      route_maps = Rm::RouteMap.where(conditions).order("name asc")
    end
    rmap_wise_hash = Hash.new
    route_maps_ids = route_maps.collect{|r| r.id}
    route_configs = Rm::RouteConfig.select("id, route_map_id").where("route_map_id in (?) and is_deleted =? ", route_maps_ids, false)
    route_configs_hash = route_configs.group_by(&:route_map_id)
    routes = Route.get_routes_based_on_route_config(nil, route_configs.map(&:id))
    if routes.present?
      services = routes.select("id, route_map_id")
      services_hash = services.group_by(&:route_map_id)
      schedules = Reservation.get_reservations_based_on_route_ids(services.map(&:id)).select("id, route_map_id")
      schedules_hash = schedules.group_by(&:route_map_id)
    else
      services = []
      services_hash = {}
      schedules = []
      schedules_hash =  {}
    end
    route_maps.each do |rm|
      rmap_wise_hash["#{rm.id}"] ||= Hash.new
      rmap_wise_hash["#{rm.id}"]["route_configs_count"] = route_configs_hash[rm.id].present? ? route_configs_hash[rm.id].size : 0
      rmap_wise_hash["#{rm.id}"]["services_count"] = services_hash[rm.id].present? ? services_hash[rm.id].size : 0
      rmap_wise_hash["#{rm.id}"]["schedules_count"] = schedules_hash[rm.id].present? ? schedules_hash[rm.id].size : 0
    end
    services_count = services.to_a.count
    schedules_count = schedules.to_a.count
    route_map_status_hash = route_maps.group_by(&:status)
    route_configs_count = route_configs_count.present? ? route_configs_count.size : 0
    all_route_maps = Rm::RouteMap.where("route_master_id=?", obj_input.rel_id)
    rm_origins = all_route_maps.collect {|rm| rm.origin.to_i }.uniq.compact
    rm_destinations =  all_route_maps.collect {|rm| rm.destination.to_i }.uniq.compact
    cities_arr = rm_origins + rm_destinations
    cities_hash = ListEntry.get_destinations_hash(cities_arr.flatten.uniq)
    origins = cities_hash.select{|k,v| rm_origins.include? k }.to_a.collect {|og| [og[1], og[0]]}.unshift ["#{I18n.t 'common.origin'}", ""]
    destinations = cities_hash.select{|k,v| rm_destinations.include? k }.to_a.collect {|ds| [ds[1], ds[0]]}.unshift ["#{I18n.t 'common.destination'}", ""]
    updated_by_ids = route_maps.collect{|rmap| rmap.updated_by}
    updated_by_ids.uniq!
    user_names_hash = User.get_users_hash(updated_by_ids)
    return ObjReturn.new({:route_maps_arr => route_maps, :route_maps_arr_count => route_maps.size, :route_maps_status_hash => route_maps.group_by(&:status), :page => obj_input.page, :next_page => obj_input.page + 1, :count => route_maps.size, :route_configs_count => route_configs_count, :services_count => services_count, :schedules_count => schedules_count, :cities_hash => cities_hash, :origins => origins, :destinations => destinations, :user_names_hash => user_names_hash, :rmap_wise_hash => rmap_wise_hash, :selected_origin => selected_origin, :selected_destination => selected_destination, :rmap_origin_name => cities_hash[selected_origin.to_i], :rmap_destination_name => cities_hash[selected_destination.to_i]})
  end

  def preview
    # do whatever here ...
    general_info_arr = _get_general_info
    services_info_arr =  _get_services_embed_list
    route_configs = _construct_route_config_list
    cityids = self.route_map.get_operated_cities_ids
    city_pairs = self.route_map.get_operated_city_pair_ids
    stages_count_hash = CommonUtils.get_city_stages_count(self.route_map.city_stages)
    route_map_tree_structure = Rm::RouteMasterService.new(self.route_map.route_master_id).route_map_tree_structure(city_pairs, cityids, stages_count_hash)
    # return values as follows ... 
    return ObjReturn.new({:general_info_arr => general_info_arr, :services_info_arr => services_info_arr, :route_configs => route_configs, :route_map_tree_structure => route_map_tree_structure})
  end

  def object_view
    general_info_arr = _get_general_info
    counts_hash, ids_hash = _get_all_ids_and_counts_hash
    rm_hash = Hash.new
    rm_hash["route_maps_data"] = [ids_hash[:route_map_id], "Rm::RouteMap"]
    #below three lines commented because we are showing default current object history
    #rm_hash["default_stages_data"] = [ids_hash[:default_stage_ids], "DefaultStage"]
    #rm_hash["route_configs_data"] = [ids_hash[:route_config_ids], "Rm::RouteConfig"]
    #rm_hash["services_data"] = [ids_hash[:service_ids], "Route"]
    obj_input = ObjInput.new({:ids_hash => ids_hash, :rm_hash => rm_hash})
    history_data, audit_info, user_names_hash = Rm::RouteMasterService.new(route_map.route_master_id).get_audit_info(obj_input)
    # return values as follows ... 
    return ObjReturn.new({:route_map => route_map, :general_info_arr => general_info_arr, :counts_hash => counts_hash, :audit_info => audit_info, :user_names_hash => user_names_hash, :history_data => history_data})
  end

  # Inputs: status, page
  # Output: ar_objects
  def create_form
    # ObjReturn.new({:rm_op_cities => operated_cities_arr, :rm_op_city_pairs => rm_op_city_pairs, :remaining_cities_arr => remaining_cities_arr, :remaining_city_pairs_arr => remaining_city_pairs_arr})
    Rm::RouteMasterService.new(route_master_id).construct_cities_and_city_pairs
  end

  # Inputs: form_data
  # Output: object_data
  def create(obj_input)
  end

  def change_or_delete(scheduling_info_id=nil)
    user_name_hash = Hash.new
    if scheduling_info_id.present?
      scheduling_info = Rm::SchedulingInfo.find(scheduling_info_id)
      route_configs = scheduling_info.route_configs.where(:is_deleted => false)
      object = scheduling_info
    else
      route_configs = route_map.route_configs.where(:is_deleted => false)
      object = route_map
    end
    user_name_hash[object.updated_by] = User.find(object.updated_by).name
    return ObjReturn.new({object: object, route_configs: route_configs, user_name_hash: user_name_hash})
  end
  
  def get_route_map_attributes(params)
    deleted_stage_ids = params[:deleted_stages_ids].present? ? params[:deleted_stages_ids].to_s.split(",") : []
    sorted_stage_ids = params[:updated_sorted_stages].present? ? params[:updated_sorted_stages].to_s.split(",") : params[:sorted_stages_ids].to_s.split(",")
    attributes = {}
    stage_sequence_obj = Hash.new
    if params["city_ids_arr"].present?
      city_ids_arr = params["city_ids_arr"].split(",")
      city_ids_arr.each do |city|
        route_map_hash = Hash.new
        rm_stage = Rm::Stage.where(:city_id => city,:route_master_id => params[:route_master_id].to_i)
        if rm_stage.present?
          rm_stage.each do |r|
            route_map_hash[r.default_stage_id] ||= Array.new
            route_map_hash[r.default_stage_id] << r
          end
          sorted_stage_ids = params["stage_sequence_#{city}"].to_s.split(",")
          sorted_stage_ids.delete("")
          sorted_stage_ids.uniq!
          sorted_stage_ids.each_with_index{|stage_id, i|
            rm_stage_map = route_map_hash[stage_id.to_i]
            stage_sequence_obj_arr = []
            stage_sequence_obj[city.to_i] ||= Array.new
            if !stage_sequence_obj_arr.include?(stage_id) && !deleted_stage_ids.include?(stage_id)
              distance = params["stage_distance_#{city}_#{stage_id}"].present? ? params["stage_distance_#{city}_#{stage_id}"] : "0:00"
              stage_hour = params["stage_duration_hr_#{city}_#{stage_id}"].present? ? params["stage_duration_hr_#{city}_#{stage_id}"] : "0"
              stage_min = params["stage_duration_min_#{city}_#{stage_id}"].present? ? params["stage_duration_min_#{city}_#{stage_id}"] : "00"
              stage_wait_min = params["stage_duration_wait_min_#{city}_#{stage_id}"].present? ? params["stage_duration_wait_min_#{city}_#{stage_id}"] : "00"
              stage_wait_hour = params["stage_duration_wait_hr_#{city}_#{stage_id}"].present? ? params["stage_duration_wait_hr_#{city}_#{stage_id}"] : "0"
              duration = "#{stage_hour}:#{stage_min}"
              wait_time = "#{stage_wait_hour}:#{stage_wait_min}"
              is_pick_up = params["is_pick_up_#{city}_#{stage_id}"].present? ? params["is_pick_up_#{city}_#{stage_id}"] : "1"
              is_eticketing = params["is_eticketing_#{city}_#{stage_id}"].present? ? params["is_eticketing_#{city}_#{stage_id}"] : "1"
              is_api = params["is_api_#{city}_#{stage_id}"].present? ? params["is_api_#{city}_#{stage_id}"] : "1"
              stage_sequence_obj[city.to_i] << [stage_id.to_i, duration.to_s, distance.to_s, wait_time.to_s, is_api.to_s, is_eticketing.to_s, is_pick_up.to_s]
              stage_sequence_obj_arr << stage_id
            end
          }
        end
      end
      cities_sequence = ",#{city_ids_arr.join(",")},"
      skip_stages_arr = []
      skip_stages_arr = route_map.skip_stages.to_s.split(",").reject(&:empty?) if route_map.present?
      skip_stages_arr << deleted_stage_ids
      skip_stages = skip_stages_arr.present? ? ",#{skip_stages_arr.join(",")}," : ""
      attributes = {:city_stages => stage_sequence_obj, :cities_sequence => cities_sequence, :skip_stages => skip_stages }
    end
    attributes
  end
  def update_route_map(params)
    route_config_ids = params["route_configs"].to_s.split(",")
    if route_config_ids.present?
      service_ids_arr = []
      regular_schedules_arr = []
      rc_schedules_arr = []
      if params[:apply_to_rc].present?
        rc_ids = params[:apply_to_rc].keys
        route_configs = Rm::RouteConfig.where("id in (?)", rc_ids)
        if route_configs.present?
          route_configs.each do |rc|
            rc.city_stages = route_map.city_stages
            rc.main_departure_stages = route_map.main_departure_stages
            rc.save
          end
        end
      end
      route_config_ids.each do |s|
        if params[:apply_services].present? && params[:apply_services]["#{s}"].present?
          service_ids = params[:apply_services]["#{s}"].keys
          service_ids_arr = service_ids_arr + service_ids
        end
        if params[:apply_regular_schedules].present? && params[:apply_regular_schedules]["#{s}"].present?
          res_ids = params[:apply_regular_schedules]["#{s}"].keys
          regular_schedules_arr = regular_schedules_arr + res_ids
        end
        if params[:apply_rc_schedules].present? && params[:apply_rc_schedules]["#{s}"].present?
          res_ids = params[:apply_rc_schedules]["#{s}"].keys
          rc_schedules_arr = rc_schedules_arr + res_ids
        end
      end
      if service_ids_arr.present?
        services = Route.where("id in (?)", service_ids_arr)
        services.each do |service|
          obj_input = ObjInput.new({:main_dept_stages => route_map.main_departure_stages, :params => params, :route_map_stages => route_map.city_stages})
          service = Rm::RmServiceService.new(service.id, service.route_master_id,  service.route_config_id, nil, nil, nil, current_user).update_route_stages_and_fares(obj_input)
          if rc_schedules_arr.present? || regular_schedules_arr.present?
            params["in_use_schedules"] = params[:apply_regular_schedules]["#{service.route_config_id}"] if regular_schedules_arr.include?(service.id.to_s)
            params["in_use_rc_schedules"] = params[:apply_rc_schedules]["#{service.route_config_id}"] if rc_schedules_arr.include?(service.id.to_s)
            params[:route_id] = service.id
            Rm::RmServiceService.new(service.id, service.route_master_id,  service.route_config_id, nil, nil, nil, current_user).update_schedules_fares(params, true) if params["in_use_schedules"].present? ||  params["in_use_rc_schedules"].present?
          end
        end
      end
      if regular_schedules_arr.present? || rc_schedules_arr.present?
        regular_schedules = []
        rc_schedules = []
        if regular_schedules_arr.present?
          route_ids = regular_schedules_arr
          regular_schedules =  Reservation.where("route_id in (?)  and travel_date >= ? and SUBSTRING(licenses, #{AdminType::IS_OVER_RIDED_RC.to_i + 1}, 1) = '0'", route_ids, CommonUtils.get_current_date)
        end
        if rc_schedules_arr.present?
          route_ids = rc_schedules_arr
          rc_schedules =  Reservation.where("route_id in (?) and travel_date >= ? and SUBSTRING(licenses, #{AdminType::IS_OVER_RIDED_RC.to_i + 1}, 1) = '1'", route_ids, CommonUtils.get_current_date)
        end
        schedules = (regular_schedules + rc_schedules).uniq
        if schedules.present?
          schedules.each do |schedule|
            if !service_ids_arr.include?(schedule.route_id.to_s)
              service = schedule.route
              input_data = ObjInput.new({:is_from_route_config => false, :cities_sequence => schedule.city_seq_order})
              object_data = Rm::RmStageService.new(service.route_master_id,nil,nil,nil,schedule.id).create_form(input_data)
              obj_input = {}
              obj_input[:id] = schedule.id
              obj_input[:rel_id] = service.route_master_id
              input_data = ObjInput.new({:main_departure_stages => route_map.main_departure_stages, :city_stages => route_map.city_stages, :params_hash => obj_input, :schedule_obj => schedule})
              schedule = Rm::ScheduleService.new(schedule.id, schedule.route_id, service.route_master_id,  service.route_config_id).update_schedule_stages_fares(input_data)
            end
            schedule.city_stages = route_map.city_stages
            schedule.main_departure_stages = route_map.main_departure_stages
            schedule.save!
            BIMAPendingReservation.log(BIMAPendingReservation::ACTION_TYPE_STAGE_CHANGE, schedule.id)
          end
        end
      end
    end
  end
  private
  def _get_general_info
    general_info_arr = []
    rmap_name = route_map.name
    rmap_description = route_map.description
    city_seq_arr = route_map.get_city_seq_arr
    rm_city_hash = CommonUtils.get_city_hash(route_map.route_master.get_cities)
    # TODO "2017-01-03", operated cities saving should be correct
    operated_cities_names_arr = route_map.get_operated_cities_names_arr(rm_city_hash)
    operated_city_pair_names_arr = route_map.get_operated_city_pair_names_arr(rm_city_hash)
    
    skipped_cities_names_arr = route_map.get_skipped_cities_names_arr(rm_city_hash)
    skip_city_pair_names_arr = route_map.get_skipped_city_pairs(rm_city_hash)
    
    operated_city_ids_arr = route_map.get_operated_cities_ids    
    origin_id = operated_city_ids_arr.first
    destination_id = operated_city_ids_arr.last

    origin_name = ListEntry.get_entry_name(AdminType::DESTINATIONS, origin_id.to_i)
    destination_name = ListEntry.get_entry_name(AdminType::DESTINATIONS, destination_id.to_i)
    

    used_for_text = ""

    if true
      block_bookings_till_main_departure_cities = ""
    end
    route_configs = Rm::RouteConfig.where("route_master_id = ? AND route_map_id = ? and is_deleted = ?", route_map.route_master_id, route_map.id, false).pluck("id")
    if route_configs.present?
      route_config_count = route_configs.size
      routes = Route.get_routes_based_on_route_config(nil, route_configs).to_a
      routes_count = routes.size
      schedules_count = routes.present? ? Reservation.get_reservations_based_on_route_ids(routes.map(&:id)).to_a.count : 0
      stages_count = route_map.get_stages_count
    else
      route_config_count = 0
      routes_count = 0
      schedules_count = 0
      stages_count = 0
    end

    # general_info_arr = [rmap_name, rmap_description, city_cities_names_arr, skip_city_pair_names_arr, excluded_users_names_arr, excluded_roles_arr, city_seq_arr.count, route_map_count, route_config_count, route_route_config_count, schedules_count, stages_count, skipped_cities_names_arr, origin_name, destination_name, rm_city_hash, used_for_text, block_bookings_till_main_departure_cities]

    general_info_arr = [rmap_name, rmap_description, origin_name, destination_name, skipped_cities_names_arr, skip_city_pair_names_arr, operated_cities_names_arr, operated_city_pair_names_arr, used_for_text, block_bookings_till_main_departure_cities, operated_city_ids_arr.count, stages_count, route_config_count, routes_count, schedules_count, rm_city_hash]

    general_info_arr
  end

  def _get_all_ids_and_counts_hash
    counts_hash = Hash.new
    ids_hash = Hash.new
    default_stage_ids = Array.new
    route_config_ids = Array.new
    route_configs = route_map.route_configs.present? ? route_map.route_configs : []
    route_config_ids = route_configs.present? ? route_configs.pluck(:id) : []
    services = Route.where("route_master_id = ? AND route_map_id = ? AND delete_flag = ? and status = ?", route_map.route_master_id, route_map_id, AdminType::DELETE_FLAG_NO, AdminType::ROUTE_STATUS_ACTIVE)
    counts_hash = {:routes_count => services.size, :route_configs_count => route_configs.size}
    stages = Rm::Stage.where("route_master_id=?", route_map.route_master_id)
    ids_hash = {:route_map_id => [route_map_id.to_i], :default_stage_ids => stages.pluck(:default_stage_id).uniq, :route_config_ids => route_config_ids, :service_ids => services.pluck(:id)}
    [counts_hash, ids_hash]
  end

  def _get_services_embed_list
    services_embed_arr = Rm::RmServiceService.new(-1, route_map.route_master_id, nil, nil, route_map.id).get_values_for_embed_list
    services_embed_arr
  end

  def _construct_route_config_list
    #TODO "2017-01-02", hardcoded need to change this below line.
    route_configs = Rm::RouteConfig.where(:route_master_id => route_master_id, :is_deleted => false).group_by(&:used_for)
    route_coach_types_count_hash = Hash.new
    scheduling_info_hash = Hash.new
    route_route_configs_hash = Hash.new
    city_count_hash = Hash.new
    if route_configs.present?
      route_configs.each do |k,v|
        v.each do |s|
          coach_types_arr = s.coach_type_ids.split(",").reject(&:empty?) if s.coach_type_ids.present?
          route_coach_types_count_hash[s.id] = coach_types_arr.length
          operated_cities = s.operated_cities.split(",").reject(&:empty?) if s.operated_cities.present?
          city_count_hash[s.id] = operated_cities.length
        end
      end
      route_config_ids = route_configs.values.flatten.map(&:id)
      route_route_configs_hash = Rm::RouteRouteConfig.where("route_config_id in (?)", route_config_ids).select("route_config_id, id, route_id").group_by(&:route_config_id)
      if route_route_configs_hash.present?
        route_ids =  route_route_configs_hash.values.flatten.map(&:route_id)
        reservations = Reservation.where(["route_id in (?) and travel_date >= ?", route_ids, CommonUtils.get_current_date]).select("route_id").group_by(&:route_id)
        route_route_configs_hash.each do |k, v|
          count = 0
          v.each do |a|
            count += reservations[a.route_id].present? ? reservations[a.route_id].length : 0
          end
          scheduling_info_hash[k] = count
        end
      end
    end
    route_config_list_arr = [route_configs, route_route_configs_hash, route_coach_types_count_hash, scheduling_info_hash, city_count_hash]
    route_config_list_arr
  end

  def _construct_route_map_embed_obj
    # rm = Rm::RouteMap.where(:id => self.route_master_id).first
    # raise TsException.new("RouteMap doesn't exists") if rm.blank?
    cityids = route_map.cities_sequence.split(',').reject(&:empty?)
    city_hash = CommonUtils.get_city_hash(cityids)
    city_pair_hash = Hash.new
    city_pairs = route_map.operated_city_pairs.split(',').reject(&:empty?)
    city_pairs.each do |city_pair|
      o, d = city_pair.split('-')
      city_pair_hash[[o, city_hash[o.to_i]]] ||= []
      city_pair_hash[[o, city_hash[o.to_i]]] << [d, city_hash[d.to_i]]
    end
    city_pair_hash.to_a
  end

  def _construct_route_map_attributes
    city_details_hash = Hash.new
    city_details_hash["selected_skipped_ids"] = []
    city_details_hash["selecte_skipped_pair_ids"] = [] 
    city_details_hash["city_pair_ids_arr"] = route_map.present? ? (route_map.get_operated_city_pair_ids+route_map.get_skip_city_pairs_arr-["#{route_map.origin}-#{route_map.destination}"]).uniq : route_master.get_city_pairs_arr
    if route_map.present?
      cities_seq = route_master.get_cities
      origin_index = cities_seq.index("#{route_map.origin}")
      destination_index = cities_seq.index("#{route_map.destination}")
      city_sequence = cities_seq.slice(origin_index..destination_index)
      city_details_hash["city_ids_arr"] = city_sequence
    else
      city_details_hash["city_ids_arr"] = route_master.get_cities
    end
    #city_details_hash["city_ids_arr"] = route_map.present? ? route_map.get_operated_cities_ids : route_master.get_cities
    # city_details_hash["city_ids_arr"] =  route_map.present? ? route_map.get_operated_cities_ids + route_map.get_skip_cities_arr: route_master.get_cities
    origin = route_map.present? ? route_map.origin : route_master.origin
    destination = route_map.present? ? route_map.destination : route_master.destination
    cities_names_hash = CommonUtils.get_city_hash(city_details_hash["city_ids_arr"])
    city_details_hash["cities_names_hash"] = cities_names_hash
    city_name_with_ids_arr = city_details_hash["city_ids_arr"].collect {|c| [cities_names_hash[c.to_i], c.to_i]}
    city_pair_name_with_ids_arr = city_details_hash["city_pair_ids_arr"].collect {|cp| [_map_city_pair_with_names(cp, cities_names_hash), cp]}
    city_details_hash["city_name_with_ids_arr"] = city_name_with_ids_arr.reject {|cn| [origin.to_i, destination.to_i].include? cn.last.to_i}
    city_details_hash["city_pair_name_with_ids_arr"] = city_pair_name_with_ids_arr.reject {|cnp| ["#{origin}-#{destination}"].include? cnp.last}
    if route_map.present?
      rm_route_config_ids = Rm::RouteConfig.where("route_map_id = #{route_map.id}").pluck("id")
      associated_cities, associated_city_pairs = CommonUtils.get_associated_cities_and_city_pairs(rm_route_config_ids)
      city_details_hash["city_name_with_ids_arr"] = CommonUtils.get_final_skip_cities(city_details_hash["city_name_with_ids_arr"], associated_cities)
      city_details_hash["city_pair_name_with_ids_arr"] = CommonUtils.get_final_skip_city_pairs(city_details_hash["city_pair_name_with_ids_arr"], associated_city_pairs)
      city_name_with_ids_arr = city_name_with_ids_arr.reject { |x| route_map.get_skip_cities_arr.include?(x[1].to_s)} if route_map.get_skip_cities_arr.present?
    end
    city_details_hash["origin_arr"] = city_name_with_ids_arr.reject { |x| x[1].to_i == destination.to_i }
    city_details_hash["destination_arr"] = city_name_with_ids_arr.reject { |x| x[1].to_i == origin.to_i }
    city_details_hash["rm_skip_city_pairs"] = route_master.get_skip_cities_arr
    if route_map.present?
      city_details_hash["selected_skipped_ids"] = route_map.get_skip_cities_arr
      city_details_hash["selecte_skipped_pair_ids"] = route_map.get_skip_city_pairs_arr
      city_details_hash["cities_sequence_names_str"] = route_map.get_operated_cities_ids.collect {|c| cities_names_hash[c.to_i] }
      route_config_ids = Rm::RouteConfig.where("route_map_id = #{route_map.id}").pluck("id")
      route_org_dest = Route.where("route_config_id in (?) and delete_flag = ?", route_config_ids, AdminType::DELETE_FLAG_NO).pluck_all_array("origin, destination")
      route_org_dest_pairs = route_org_dest.uniq
      route_org_dest.flatten!
      route_org_dest.uniq!
      city_details_hash["city_name_with_ids_arr"].each do |c|
        city_details_hash["city_name_with_ids_arr"].delete(c) if route_org_dest.include?(c[1])
      end
      city_details_hash["city_pair_name_with_ids_arr"].each do |c|
        org,dest = c[1].to_s.split("-").reject(&:empty?) 
        city_details_hash["city_pair_name_with_ids_arr"].delete(c) if route_org_dest_pairs.include?([org.to_i, dest.to_i]) #route_org_dest.include?(org.to_i) || route_org_dest.include?(dest.to_i)
      end
    else
      city_details_hash["cities_sequence_names_str"] = (Hash[city_name_with_ids_arr]).keys
    end 
    city_details_hash
  end

  def _map_city_pair_with_names(city_pair, cities_names_hash)
    first_city, second_city = city_pair.split("-")
    "#{cities_names_hash[first_city.to_i]}-#{cities_names_hash[second_city.to_i]}"
  end
end