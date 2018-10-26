class Track
  attr_reader :morning_sessions
  attr_reader :afternoon_sessions

  def initialize
    @morning_sessions   = Session.new("morning")
    @afternoon_sessions = Session.new("afternoon")
  end

  def insert_talks_on_track(talk_lists)
    talk_lists.each do |title, length|
      # @morning_sessions.add(title, length) if title.include?("Rails Magic ")
      if @morning_sessions.has_space?(length)
        @morning_sessions.add(title, length)
        @morning_sessions.add("== Break ==", 6)

      elsif @afternoon_sessions.has_space?(length)
        @afternoon_sessions.add(title, length)
        @afternoon_sessions.add("== Break ==", 6)
      end
    end
  end
end