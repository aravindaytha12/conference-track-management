class Rm::RouteMapsController < Rm::BaseController
  # used for row level mouse over tooltip views and its based on the context! 
  # tooltip/:id?rel_type=RouteMaster&rel_id=10
  before_filter :set_breadcrumb
  
  def tooltip
    todo_implementation("Format: tooltip/:id?rel_type=RouteMaster&rel_id=10")
  end
  
  # used for row level onclick previews and it shows full object with no header and no actions. 
  # Its based on the Object context!   
  # preview/:id?rel_type=RouteMaster&rel_id=10
  def preview
    @preview_object = Rm::RouteMapService.new(params[:id], params[:rel_id]).preview
  end

  def index
    status = (params[:status].blank? || params[:status].to_s=="all") ? "" : params[:status]
    obj_input = ObjInput.new({:status => status, :page => params[:page].to_i, :rel_id => params[:rel_id].to_i, :origin => params[:origin], :destination => params[:destination]})
    obj_output = Rm::RouteMapService.new(-1, params[:rel_id]).list(obj_input)
    if (params.key?("status") || params.key?("origin") || params.key?("destination"))
      render :partial => "rm/route_maps/route_maps_view", :layout => false, :locals => {list_hash: obj_output}
    else
      layout_cond = (!(request.xhr?.present?) && params["status_change"].present? && params["status_change"].to_s == "true") ? "ticket-simply" : false
      render :template => "rm/route_maps/index", :layout => layout_cond, :locals => {list_hash: obj_output} if params[:status].to_s != "all" 
    end
  end

  def index_old
    status = params[:status].blank? ? Rm::RouteMap::STATUS_ACTIVE : params[:status]
    obj_input = ObjInput.new({:status => status, :page => params[:page].to_i, :rel_id => params[:rel_id].to_i})
    obj_output = Rm::RouteMapService.new(-1, params[:rel_id]).list(obj_input)

    #TODO - Change below objects to locals
    @route_maps = obj_output.ar_objects
    @route_maps_count = obj_output.ar_objects.count
    @services_count = obj_output.services_count
    @schedules_count = obj_output.schedules_count
    @route_configs_count = obj_output.route_configs_count
    @route_maps_status_hash = obj_output.ar_objects.group_by(&:status)
    @cities_hash = obj_output.cities_hash
    @origins = obj_output.origins
    @destinations = obj_output.destinations
    updated_by_ids = @route_maps.collect{|rmap| rmap.updated_by}
    updated_by_ids.uniq!
    @user_names_hash = User.get_users_hash(updated_by_ids)
    if request.xhr?.present?
      render :layout=> false
    else
      render :template => "rm/route_maps/index", :layout => "ticket-simply"#, :locals => {:obj_output => obj_output}
    end
  end

  def new
    route_map_details = Rm::RouteMapService.new(-1, params[:rel_id]).new_route_map
    add_breadcrumb "#{route_map_details.route_master_name}", "/rm/route_masters/object_view/#{params[:rel_id]}"
    add_breadcrumb "#{I18n.t 'routes.route_maps'}", "/rm/route_masters/object_view/#{params[:rel_id]}?is_from_route_map_obj=#{true}&status_change=#{true}"
    add_breadcrumb "#{t 'common.create_new'}", "#"
    form_locals = {route_map: Rm::RouteMap.new, rel_id: params[:rel_id], city_details_hash: route_map_details.city_details_hash, route_map_tree_obj: route_map_details.route_map_tree_obj, :cities_count => route_map_details.cities_count, :stages_count => route_map_details.stages_count, controller_name: "/rm/route_maps", action_name: "create"}
    render :template => "rm/route_maps/new", :layout => "ticket-simply", :locals => {form_locals: form_locals}
  end

   def get_cities(city_pairs)
    city_pairs.collect{|cp| cp.split('-')}.flatten.uniq
  end

  def get_cities_sequence
    cities_sequence_names_arr = []
    @final_skip_city_ids_array = []
    @city_names_str = ""
    org_cities = get_cities(params[:city_pair_ids_arr].split(","))
    cities_names_hash = CommonUtils.get_city_hash(org_cities)
    filtered_cities = get_cities(params[:city_pair_ids_arr].split(',')-params[:rmap_skip_city_pair_ids_arr].split(','))
    org_cities = org_cities - (org_cities - filtered_cities)
    rm_final_city_ids_arr = params[:rmaster_city_ids].present? ? params[:rmaster_city_ids].split(",") : []
    @final_skip_city_ids_array = (rm_final_city_ids_arr - org_cities).uniq
    rm_final_city_ids_arr.each do |a|
      cities_sequence_names_arr << cities_names_hash[a.to_i] if org_cities.include? a
    end
    cities_sequence_names_arr.flatten!
    cities_sequence_names_arr.uniq!
    @city_names_str = cities_sequence_names_arr.join(" <b><span class='fa fa-angle-double-right'></span></b> ").html_safe
    #TODO "Aravind", Need to remove below line for getting route_master.
    if params[:rel_id].present?
      route_master = Rm::RouteMaster.find(params[:rel_id])
      stages_count_hash = route_master.get_rm_stages_count
      @route_map_tree_obj = Rm::RouteMasterService.new(route_master.id).route_map_tree_structure(params[:city_pair_ids_arr].split(',')-params[:rmap_skip_city_pair_ids_arr].split(','), org_cities, stages_count_hash)
    end
  end


  # def show_city_pair_combinations
  #   @final_city_pairs_arr = Array.new
  #   @final_city_pairs_ids_arr = Array.new
  #   city_names_arr = Array.new
  #   skip_cities_arr = params[:rmap_skip_cities_arr].split(",")
  #   remaining_city_pairs_arr = JSON.parse(params[:remaining_city_pairs_arr])
  #   remaining_cities_arr = remaining_city_pairs_arr.join("-").split("-").uniq!
  #   final_cities_arr = remaining_cities_arr - skip_cities_arr
  #   final_cities_arr = final_cities_arr.combination(2).to_a
  #   cities_names_hash = CommonUtils.get_city_hash(final_cities_arr.flatten.uniq)

  #   final_cities_arr.each do |c|
  #     origin_name = cities_names_hash[c[0].to_i]
  #     destination_name = cities_names_hash[c[1].to_i]
  #     @final_city_pairs_arr << ["#{origin_name}-#{destination_name}", "#{c[0]}-#{c[1]}"]
  #     @final_city_pairs_ids_arr << "#{c[0]}-#{c[1]}"
  #   end
  #   @final_city_pairs_arr
  #   @final_city_pairs_arr.each do |c|
  #     city_names_arr.push(c[0].split("-")) 
  #   end
  #   city_names_arr.flatten!
  #   city_names_arr.uniq!
  #   @city_names_str = ""
  #   @city_names_str = city_names_arr.join(" <span class='fa fa-angle-double-right'></span> ").html_safe
  #   #TODO "Aravind", Need to remove below line for getting route_master.
  #   route_master = Rm::RouteMaster.find(params[:rel_id])
  #   @rmaster_city_ids_arr = route_master.get_city_pairs_arr.join("-").split("-").uniq
  #   stages_count_hash = route_master.get_rm_stages_count
  #   @route_map_tree_obj = Rm::RouteMasterService.new(route_master.id).route_map_tree_structure(@final_city_pairs_ids_arr, (remaining_cities_arr - skip_cities_arr), stages_count_hash)
  # end

  def get_cities_and_city_pairs
    obj_input = ObjInput.new({:remaining_cities_arr => params[:remaining_cities_arr], :origin => params[:origin], :destination => params[:destination], :skip_city_value => params[:skip_city_value], :service_layer => params[:service_layer], :service_id => params[:service_id]})
    service_id = params[:service_id].present? ? params[:service_id] : -1
    obj_output = Rm::RmServiceService.new(service_id, params[:rel_id], params[:route_config_id]).get_cities_and_city_pairs(obj_input)
    if params["rmap_id"].present?
      rm_route_config_ids = Rm::RouteConfig.where("route_map_id = #{params["rmap_id"]}").pluck("id")
      associated_cities, associated_city_pairs = CommonUtils.get_associated_cities_and_city_pairs(rm_route_config_ids)
      obj_output.skip_city_list_arr = CommonUtils.get_final_skip_cities(obj_output.skip_city_list_arr, associated_cities)
      obj_output.skip_city_pairs_arr = CommonUtils.get_final_skip_city_pairs(obj_output.skip_city_pairs_arr, associated_city_pairs)
    end
    @skip_city_list_arr = obj_output.skip_city_list_arr
    @skip_city_pairs_arr = obj_output.skip_city_pairs_arr
    @city_sequence_arr = obj_output.city_sequence_arr
    @final_city_pairs_ids_arr = obj_output.final_city_pairs_ids_arr
    @selected_skip_cities = obj_output.selected_skip_cities
    @rmaster_city_ids_arr = obj_output.rmaster_city_ids_arr
    @route_map_tree_obj = obj_output.route_map_tree_obj
    @selected_city_pairs = params[:selected_city_pairs] if params[:selected_city_pairs].present?
  end

  def create
    obj_input = ObjInput.new({:form_data => params})
    obj_output = Rm::RouteMapService.new(-1, params["route_master_id"]).create_route_map(obj_input)
    @route_map = obj_output.ar_object
    if @route_map.save
      redirect_to :action => "object_view", :id => @route_map.id, :rel_id => @route_map.route_master_id 
    else
      flash[:error] = @route_map.errors.full_messages.join('<br/>').html_safe
      route_map_details = Rm::RouteMapService.new(-1, params[:route_master_id]).new_route_map
      add_breadcrumb "#{route_map_details.route_master_name}", "/rm/route_masters/object_view/#{params[:route_master_id]}"
      add_breadcrumb "#{I18n.t 'routes.route_maps'}", "/rm/route_masters/object_view/#{params[:route_master_id]}?is_from_route_map_obj=#{true}&status_change=#{true}"
      add_breadcrumb "#{t 'common.create_new'}"
      form_locals = {route_map: @route_map, rel_id: params[:route_master_id], city_details_hash: route_map_details.city_details_hash, route_map_tree_obj: route_map_details.route_map_tree_obj, :cities_count => route_map_details.cities_count, :stages_count => route_map_details.stages_count, controller_name: "/rm/route_maps", action_name: "create"}
      render :template => "rm/route_maps/new", :layout => "ticket-simply", :locals => {form_locals: form_locals}
    end
  end

  def edit
    route_map = Rm::RouteMap.find(params[:id])
    add_breadcrumb "#{route_map.route_master.name}", "/rm/route_masters/object_view/#{route_map.route_master_id}"
    add_breadcrumb "#{I18n.t 'routes.route_maps'}", "/rm/route_masters/object_view/#{route_map.route_master_id}?is_from_route_map_obj=#{true}&status_change=#{true}"
    add_breadcrumb "#{t 'common.modify_var'}: #{route_map.name}", "#"
    edit_object = Rm::RouteMapService.new(params[:id], route_map.route_master_id).edit_route_map
    form_locals = {route_map: route_map, rel_id: route_map.route_master_id, city_details_hash: edit_object.city_details_hash, route_map_tree_obj: edit_object.route_map_tree_obj, controller_name: "/rm/route_maps", action_name: "update"}
    render :template => "rm/route_maps/edit", :layout => "ticket-simply", :locals => {form_locals: form_locals}
  end

  def update
    route_map = Rm::RouteMap.find(params[:id])
    route_map.name = params["rm_route_map"]["name"] 
    route_map.description = params["rm_route_map"]["description"]
    #@route_map.save! #TODO "Aravind", need confirmation for below thing.
    if route_map.save
      redirect_to :action => "object_view", :id => route_map.id, :rel_id => route_map.route_master_id
    else
      flash[:error] = route_map.errors.full_messages.join(",")
      redirect_to :action => "edit", :id => route_map.id, :rel_id => route_map.route_master_id
    end
  end

  def show
    @route_map = Rm::RouteMap.find params[:id]
  end
  
  
  # its an embed component thats used to give the list of the rows
  # View is based on the Object context!
  # embed_list?rel_type=RouteMaster&rel_id=10
  def embed_list
    # todo_implementation("Format: embed_list?rel_type=RouteMaster&rel_id=10")
    # active_routemaps = Rm::RouteMap.where("status=?", "active").first(5)

    routemaps = Rm::RouteMap.where("status=?", "active").first(5)
    render :partial => "embed_list", :layout => "setting", :locals => {:routemaps => routemaps}
  end

  # its an embed component thats used to give the object view for that record
  # View is based on the Object context!
  # embed_view/:id?rel_type=RouteMaster&rel_id=10
  def embed_view
    embed_obj = _construct_embed_obj(params[:rel_type], params[:id])
    # todo_implementation("Format: embed_view/:id?rel_type=RouteMaster&rel_id=10")
    render :partial => "embed_view", :locals => {:embed_obj => embed_obj, :levels => 1, :header => "#{t 'common.route_city_stages'}"}
  end
  
  # its an embed component thats used to show the Object Form view for New & Edit screens
  # View is based on the Object context!
  # form_view/:id?rel_type=RouteMaster&rel_id=10  
  def form_view
    todo_implementation("Format: form_view/:id?rel_type=RouteMaster&rel_id=10")
  end

  def show_embed_view_info
    @embed_obj = _construct_embed_obj(params[:rel_type], params[:id])
  end

  def show_embed_list_info
    @routemaps = Rm::RouteMap.where("route_master_id = ? and is_deleted = ?", params[:id], false)
  end
  
  def object_view
    route_map_object = Rm::RouteMapService.new(params[:id], params[:rel_id]).object_view
    @widgets = route_map_object.route_map.view_widgets
    add_breadcrumb "#{route_map_object.route_map.route_master.name}", "/rm/route_masters/object_view/#{route_map_object.route_map.route_master_id}"
    add_breadcrumb "#{I18n.t 'routes.route_maps'}", "/rm/route_masters/object_view/#{route_map_object.route_map.route_master_id}?is_from_route_map_obj=#{true}&status_change=#{true}"
    add_breadcrumb "#{route_map_object.route_map.name}"
    @total_widgets = Rm::RouteMaster::VIEW_WIDGETS
    route_configs = route_map_object.route_map.route_configs.where(:is_deleted => false)
    edit_url = "/rm/route_maps/update/general_info?rel_id=#{route_map_object.route_map.route_master_id}&rmap_id=#{route_map_object.route_map.id}&is_launch_wizard=true"
    filter_names_arr = [["#{I18n.t 'routes.route_maps'}", Rm::RouteMaster::RM_ROUTE_MAPS], ["#{I18n.t 'routes.stages'}", Rm::RouteMaster::RM_STAGES], ["#{I18n.t 'routes.route_configs'}", Rm::RouteMaster::RM_ROUTE_CONFIGS], ["#{I18n.t 'routes.services'}", Rm::RouteMaster::RM_SERVICES]]
    render :template => "rm/route_maps/object_view", :layout => "ticket-simply", :locals => {route_map: route_map_object.route_map, :rmap_general_info_arr => route_map_object.general_info_arr, rmap_counts_hash: route_map_object.counts_hash, rmap_audit_info: route_map_object.audit_info, rmap_user_names_hash: route_map_object.user_names_hash, rmap_history_data: route_map_object.history_data, :filter_names_arr => filter_names_arr, :edit_url => edit_url}
  end

  def change_status
    if params["is_from_scheduling_info"].present?
      @object_status = Rm::RouteMapService.new(-1, params[:rel_id]).change_or_delete(params[:id])
    else
      @object_status = Rm::RouteMapService.new(params[:id], params[:rel_id]).change_or_delete
    end
  end

  def update_status
    #TODO "Aravind", loading route_configs need to change, may take from the assosciations. 
    object_class = (params["object_class"].to_s=="Rm::RouteMap") ? Rm::RouteMap : Rm::SchedulingInfo
    object_name = (object_class.to_s=="Rm::RouteMap") ? "#{t 'common.route_map'}" : "#{t 'routes.scheduling_info'}"
    object = object_class.where("id = ?", params[:id]).first
    route_configs = object.route_configs.group_by(&:status)
    if route_configs.present?
      active_route_configs = route_configs[Rm::RouteConfig::STATUS_ACTIVE]
      #inactive_route_configs = route_configs[Rm::RouteConfig::STATUS_IN_ACTIVE]
    end
    active_route_configs_count = active_route_configs.present? ? active_route_configs.count : 0
    #Added Validation Under Route Config
    # inactive_route_configs_count = inactive_route_configs.present? ? inactive_route_configs.count : 0
    # if params[:status].to_s == object_class::STATUS_ACTIVE
    #   return flash[:error] = "#{t 'routes.object_cannot_active_alert', :object_name => object_name}" if inactive_route_configs_count != 0
    if params[:status].to_s == object_class::STATUS_IN_ACTIVE
      return flash[:error] = "#{t 'routes.object_cannot_in_active_alert', :object_name => object_name}" if active_route_configs_count != 0
    end
    if object.update_attribute :status, params[:status]
      flash[:notice] = (params[:status].to_s==object_class::STATUS_ACTIVE) ? "#{t 'routes.changed_to_active_alert'}" : "#{t 'common.updated_successfully'}"
    else 
      flash[:error] = "#{t 'routes.failed_to_update'}"
    end
    @badge_class = ""
    @badge_class = (object.is_in_active?) ? "badge-danger" : "badge-success"
    @status_text = object.status.titleize.to_s
  end
  
  def display_route_map_info
    if params["is_from_scheduling_info"].present?
      @object_status = Rm::RouteMapService.new(-1, params[:rel_id]).change_or_delete(params[:id])
    else
      @object_status = Rm::RouteMapService.new(params[:id], params[:rel_id]).change_or_delete
    end
  end

  def update_route_map_delete_status
    @object_class = (params["object_class"].to_s=="Rm::RouteMap") ? Rm::RouteMap : Rm::SchedulingInfo
    object_name = (@object_class.to_s=="Rm::RouteMap") ? "#{t 'common.route_map'}" : "#{t 'routes.scheduling_info'}"
    object = @object_class.where("id = ?", params[:id]).first
    route_configs = object.route_configs.where("is_deleted = ? and used_for = ?", false, "regular")
    @route_master_id = object.route_master_id
    return flash[:error] = "#{t 'routes.object_cant_delete', :object_name=>object_name}" if route_configs.present?
    #TODO "Aravind", need confirmation to update with "0" (or) true.
    name = "#{object.name}-DEL#{object.id}"
    object.name = name
    object.is_deleted = true
    if object.save!
      flash[:notice] = "#{t 'quotas_c.deleted_successfully'}"
    else
      flash[:error] = "#{t 'routes.failed_to_delete'}"
    end
  end

  # DASH on 24th Dec
  # Object's intelligence widgets
  # Often loaded in a separate request on loading of the main screen
  # GET: intelligence/:id
  # Format: HTML
  def intelligence
   route_map = Rm::RouteMap.where(id: params[:id]).first
   @widgets_data = route_map.view_widget_data
  end

  # DASH on 24th Dec  
  # Objects intelligence widgets, this is called in the list views
  # Often loaded in a separate request on loading of the main screen  
  # GET: intelligence => with no ID!
  # Format: HTML
  def list_intelligence
    todo_implementation("Format: list_intelligence")
  end

  def route_map_stages
    route_map = Rm::RouteMap.where(:id => params[:id]).last
    obj_input = ObjInput.new({:is_from_route_config => true, :cities_sequence => route_map.operated_cities, :route_map_id => route_map.id})
    @object = Rm::RmStageService.new(params[:rel_id]).create_form(obj_input)
    @controller_name = "rm/route_maps"
    @action_name = "edit_route_map_stages"
    render :template => "/rm/services/route_map_stages", :layout => false
  end

  def edit_route_map_stages
    route_map = Rm::RouteMap.where(:id => params[:id]).last
    obj_input = ObjInput.new({:is_from_route_config => true, :cities_sequence => route_map.operated_cities, :route_map_id => route_map.id})
    @object = Rm::RmStageService.new(params[:rel_id]).create_form(obj_input)
    @route_map_layer = true
    @object_view_edit = true
    @url = "/rm/route_maps/update_route_map"
  end

  def update_route_map
    Rm::RouteMap.transaction do
      route_map = Rm::RouteMap.where(:id => params[:route_map_id]).last
      attributes = Rm::RouteMapService.new(route_map.id, route_map.route_master_id).get_route_map_attributes(params) 
      st_object = Rm::RmStageService.new(route_map.route_master_id, params).get_main_departure_stages
      route_map.city_stages = attributes[:city_stages]
      route_map.main_departure_stages = st_object.stage_map_seq
      if route_map.save
        flash[:notice] = "#{t 'common.updated_successfully'}"
        @route_map_layer = true
        @object_view_edit = true
        params[:id] = route_map.id
        params[:rel_id] = route_map.route_master_id
        @controller_name = "rm/route_maps"
        @action_name = "edit_route_map_stages"
        obj_input = ObjInput.new({:is_from_route_config => true, :cities_sequence => route_map.operated_cities, :route_map_id => route_map.id})
        @object = Rm::RmStageService.new(route_map.route_master_id).create_form(obj_input)
      else
        flash[:error] = route_map.errors.full_messages.join('</br>')
      end
    end
  end

  def show_route_map_stages_object_view
    @controller_name = "rm/route_maps"
    @action_name = "edit_route_map_stages"
    route_map = Rm::RouteMap.where(:id => params[:id]).last
    obj_input = ObjInput.new({:is_from_route_config => true, :cities_sequence => route_map.operated_cities, :route_map_id => route_map.id})
    @object = Rm::RmStageService.new(params[:rel_id]).create_form(obj_input)
  end

#below method will call from route map edit finish page
  def update_apply_to_service
    if params["services"].present?
      route_map_id = params["route_map_id"]
      route_master_id = params["route_master_id"]
      object = Rm::RouteConfigService.new(nil, route_master_id, nil, nil, route_map_id, nil, current_user).update_route_map_edit_changes_to_services(params)
    end
    render js: ""
  end


  private

  def _construct_embed_obj(rel_type, rm_id)
    rm = Rm::RouteMap.where(:id => rm_id).first
      cityids = rm.operated_cities.split(',').reject(&:empty?)
      city_pairs = rm.operated_city_pairs.split(',').reject(&:empty?)
    # obj_input = ObjInput.new({:status => status, :page => params[:page].to_i})
    Rm::RouteMasterService.new(rm.route_master_id).route_map_tree_structure(city_pairs, cityids)

    # raise TsException.new("RouteMap doesn't exists") if rm.blank?
  end

  def set_breadcrumb
    add_breadcrumb "#{I18n.t 'routes.routes_manager'}", "/rm/route_masters/dashboard"
    add_breadcrumb "#{I18n.t 'routes.routes_masters'}", "/rm/route_masters"
  end
end
