class ReportsController < ApplicationController
	def list
   unless current_user.account.subdomain == "sys"
		@reports_arr = AdminType::REPORT_TYPES
		@services_arr = Service.where("account_id=?", current_user.account_id).collect{|s| ["#{s.number}(#{s.name})", s.id]}
		@date_range_arr = AdminType::REPORT_DATE_RANGE
   else
    @reports_arr = AdminType::SYS_REPORT_TYPES
    @services_arr = Service.where("account_id=?", current_user.account_id).collect{|s| ["#{s.number}(#{s.name})", s.id]}
    @date_range_arr = AdminType::REPORT_DATE_RANGE
    @operators= Account.where("id !=1 and status = 'active'").select("accounts.id,accounts.name") #User.joins(:account,:role).select("accounts.id,accounts.name").where.not("roles.user_type = 'bitla_admin'")
   end
	end

	def run_reports
    subdomain = current_user.account.subdomain
    report = params[:report]
    report_type = report[:id].to_i
    if subdomain == 'sys'
      if report_type == AdminType::OPERATOR_ACCOUNT_USAGE_REPORT
        @report_results_partial = "operator_account_usage_report"
      elsif report_type == AdminType::PRODUCT_USAGE_REPORT
        @report_results_partial = "product_usage_report"      
      else
        puts "REPORT NOT IMPLEMENTED - #{report_type}"
      end
    else
      if report_type == AdminType::SMS_TRACKERS_REPORT
        @report_results_partial = "sms_trackers_report_partial"
      elsif report_type == AdminType::FEEDBACK_REPORT
        @report_results_partial = "feedback_report_partial"
      elsif report_type == AdminType::TRACKING_LINK_ACCESS_REPORT
        @report_results_partial = "tracking_link_access_report"  
      elsif report_type == AdminType::BUS_HALT_REPORT
        @report_results_partial = "bus_halt_report"
        @service_trips,@service_places_hash = service_tracking_report(params[:report][:service_id],params[:report][:stage_type],params[:report][:selected_date])         
      else
        puts "REPORT NOT IMPLEMENTED - #{report_type}"
      end
    end
  end

  def operator_account_usage_report
    params[:account_id] = params[:report][:account_id]
    if params[:report][:date_range].to_i == AdminType::REPORT_DATE_CUSTOM
      params[:from_date] = parse_date(params[:report][:from_date]) 
      params[:to_date] = parse_date(params[:report][:to_date])
    end
    render json: OperatorAccountUsageDatatable.new(view_context)
  end

	def sms_trackers_report
    # binding.pry
    params[:account_id] = current_user.account_id
    if params[:report][:date_range].to_i == AdminType::REPORT_DATE_CUSTOM
      params[:from_date] = parse_date(params[:report][:from_date]) 
      params[:to_date] = parse_date(params[:report][:to_date])
    end
    render json: SmsTrackerDatatable.new(view_context)
	end

  def feedback_report
    params[:account_id] = current_user.account_id
    params[:feedback_for] = params["feedback_for"]["feedback_for"].to_i
    if params[:report][:date_range].to_i == AdminType::REPORT_DATE_CUSTOM
      params[:from_date] = parse_date(params[:report][:from_date]) 
      params[:to_date] = parse_date(params[:report][:to_date])
    end
    render json: FeedbackDatatable.new(view_context)
  end

  def tracking_link_access_report
    params[:account_id] = current_user.account_id
    if params[:report][:date_range].to_i == AdminType::REPORT_DATE_CUSTOM
      params[:from_date] = parse_date(params[:report][:from_date]) 
      params[:to_date] = parse_date(params[:report][:to_date])
    end
    render json: TrackingLinkAccessDatatable.new(view_context)
  end

  def tracking_link_access_by
    if params[:service_id] == "0"
    stt = ServiceTripTrackingLink.where(:account_id => current_user.account_id).pluck(:service_id)
    else
    stt = ServiceTripTrackingLink.where(:account_id => current_user.account_id, :service_id => params[:service_id]).pluck(:service_id)
    end
    service_ids = stt.uniq
    @st_travellers = ServiceTripTraveller.where("account_id =? and pnr_number =? and service_id in (?)", current_user.account_id, params[:pnr_number], service_ids)
  end
  
  def services_tracking_xls
      @service_trips,@service_places_hash = service_tracking_report(params[:service_id],params[:stage_type],params[:date])
      respond_to do |format|
        format.xls
      end
    end
  end

  def service_tracking_report(service_id,stage_type,date) 
    service_conditions = ["account_id = ?", current_user.account_id]
    if service_id.present? && service_id != "*"
      service_conditions[0] += " AND id = ?"
      service_conditions << service_id
    end
    services = Service.where(service_conditions)
    service_trip_conditions = ["account_id = ? AND running_status = ?", current_user.account_id, AdminType::COMPLETED]
    if date.present?
      service_trip_conditions[0] += " AND travel_date = ?"
      service_trip_conditions << date.to_date.to_s
    end
    if services.present?
      service_trip_conditions[0] += " AND service_id in (?)"
      service_trip_conditions << services.ids.uniq
    end
    @service_trips = ServiceTrip.where(service_trip_conditions)
    service_ids = Array.new
    service_trip_ids = Array.new
    service_trip_hash = Hash.new
    if @service_trips.present?
      @service_trips.each do |service_trip|
        service_ids << service_trip.service_id
        service_trip_ids << service_trip.id
        service_trip_hash[service_trip.service_id] = service_trip
      end
      service_place_conditions = ["account_id = ? AND service_id in (?) AND deleted_flag = false", current_user.account_id, service_ids.uniq]
      if stage_type.present?
        service_place_conditions[0] += " AND stage_type = ?"
        service_place_conditions << stage_type  
      end
      service_places = ServicePlace.where(service_place_conditions)
      @service_places_hash = ServicePlace.sort_service_place(service_places, service_trip_hash)
      @actual_time_hash = Hash.new
      service_trip_trackers_arr = ServiceTripTracker.where("account_id = ? AND service_id in (?) AND service_trip_id in (?) AND service_place_id is not null", current_user.account_id, service_ids.uniq, service_trip_ids.uniq)
      service_trip_trackers_arr.each do |service_trip_tracker|
        @actual_time_hash[service_trip_tracker.service_id] ||= Hash.new
        @actual_time_hash[service_trip_tracker.service_id][service_trip_tracker.service_place_id] = EtaController.new.get_ist_time_to_show(service_trip_tracker)
      end
      service_trip_tracker_latest_hash = Hash.new
      ServiceTripTrackerLatest.where("account_id=? AND service_id in (?) AND service_trip_id in (?)", current_user.account_id, service_ids.uniq, service_trip_ids.uniq).collect{|sttl| service_trip_tracker_latest_hash[sttl.service_id]=sttl.service_place_id}
      @service_trips.each do |service_trip|
        @last_stage_id = service_trip_tracker_latest_hash[service_trip.service_id]
      end
      ############################## Below Code is For Stage wise Seats Count ##############################
      service_trip_travellers_cond = ["account_id = ? AND service_id in (?) AND service_trip_id in (?)", 4, service_ids.uniq, service_trip_ids.uniq]
      service_trip_travellers_arr = ServiceTripTraveller.select("id, account_id, service_id, service_trip_id, boarding_at, drop_off, seat_number").where(service_trip_travellers_cond)
      seats_count_hash = Hash.new
      service_trip_travellers_arr.each do |stt|
        seats_count_hash[stt.service_trip_id] ||= Hash.new
        seats_count_hash[stt.service_trip_id][stt.boarding_at] ||= Array.new
        seats_count_hash[stt.service_trip_id][stt.drop_off] ||= Array.new
        seats_count_hash[stt.service_trip_id][stt.boarding_at].push(stt.seat_number) if stt.boarding_at.present?
        seats_count_hash[stt.service_trip_id][stt.drop_off].push(stt.seat_number) if stt.drop_off.present?
      end
      @stage_wise_seat_count_hash = Hash.new
      if @service_places_hash.present?
        @service_trips.each do |service_trip|
          if seats_count_hash.present? && seats_count_hash[service_trip.id].present?
            boarding_seat_count_str = ""
            dropoff_seat_count_str = ""
            @service_places_hash[service_trip.service_id].each do |service_place|
              if service_place.stage_type == "boarding"
                boarding_seat_count_str += seats_count_hash[service_trip.id][service_place.r_service_place_id].present? ? "#{seats_count_hash[service_trip.id][service_place.r_service_place_id].count}<br/>" : "0<br/>"
              elsif service_place.stage_type == "dropoff"
                dropoff_seat_count_str += seats_count_hash[service_trip.id][service_place.r_service_place_id].present? ? "#{seats_count_hash[service_trip.id][service_place.r_service_place_id].count}<br/>" : "0<br/>"
              end
              @stage_wise_seat_count_hash[service_trip.id] = boarding_seat_count_str + dropoff_seat_count_str
            end
          end
        end
      end
      return @service_trips,@service_places_hash
  end
end