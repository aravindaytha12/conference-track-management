class SmsTrackerDatatable < AjaxDatatablesRails::Base
  def_delegators :@view, :link_to, :h, :mailto, :params

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
        mobile_number: {source: "SmsTracker.mobile_number"},
        message: {source: "SmsTracker.message"},
        service: {source: "SmsTracker.service_trip_id"},
        count: {source: "SmsTracker.count"},
        status: {source: "SmsTracker.status"},
        delivered_on: {source: "SmsTracker.delivered_on", orderable: true}
      }
  end

  def data
# binding.pry
    records.map do |record|
      {
        mobile_number: record.mobile_number,
        message: record.message,
        service: record.service_trip_id.present? ? "#{record.service_trip.service.number}(#{record.service_trip.service.name})" : "",
        count: record.count,
        status: record.status.to_i == AdminType::YES ? "Success" : "Failure",
        delivered_on: record.delivered_on.present? ? CommonUtils.get_ist_time(record.delivered_on).strftime('%d/%m/%Y %H:%M:%S %p') : ""
      }
    end
  end

  private

  def get_raw_records
    report = params[:report]
    date_range = report[:date_range].to_i
    current_date = CommonUtils.get_current_date
    if date_range == AdminType::REPORT_DATE_TODAY
      conditions = ["created_date = ?", current_date]      
    elsif date_range == AdminType::REPORT_DATE_YESTERDAY
      conditions = ["created_date = ?", current_date-1]
    elsif date_range == AdminType::REPORT_DATE_TOMORROW
      conditions = ["created_date = ?", current_date+1]
    elsif date_range == AdminType::REPORT_DATE_PRE7DAYS
      conditions = ["created_date between ? and ?", current_date-6, current_date]
    elsif date_range == AdminType::REPORT_DATE_CUSTOM
      params[:from_date] = CommonUtils.get_current_date-480
      params[:to_date] = CommonUtils.get_current_date
      from_date = params[:from_date]
      to_date = params[:to_date]
      conditions = ["created_date between ? and ?", from_date, to_date]
    end
    conditions[0] += " AND account_id = ?"
    conditions << params[:account_id]
    if (report[:service_id].present? && report[:service_id].to_s != "*")
      service_trip_ids_arr = ServiceTrip.select("id").where("service_id=?", report[:service_id])
      conditions[0] += " AND service_trip_id in (?)"
      conditions << service_trip_ids_arr
    end
    SmsTracker.select("id, mobile_number, message, count, status, delivered_on, service_trip_id").where(conditions)
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  # def sort_records(records)
  # end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary
end
