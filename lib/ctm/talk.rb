class Talk
  attr_reader :title
  attr_reader :length

  LIGHTNING_TALK_LENGTH = 5

  def initialize(talk)
    @title, @length = *title_and_length(talk)
  end

  def self.quantity_of_tracks(talk_lists)
    total_length_talks = talk_lists.values.reduce(:+)

    total_length = Session::MORNING_LENGTH + Session::AFTERNOON_LENGTH
    (total_length_talks / total_length.to_f).ceil
  end

  def self.update_talk_lists(talk_lists, track)
    # removing schedule and length
    track.morning_sessions.talks.each do |talk|
      talk = talk[/(?=\s).*(?=\s)/].strip
      talk_lists.delete_if {|k, v| k == talk }
    end

    track.afternoon_sessions.talks.each do |talk|
      talk = talk[/(?=\s).*(?=\s)/].strip
      talk_lists.delete_if {|k, v| k == talk }
    end

    talk_lists
  end

  private

    def title_and_length(talk)
      # talk = "Overdoing it in Python 45min"
      # talk[/.*(?=\s)/] = "Overdoing it in Python"
      # length = 45
      title = talk[/.*(?=\s)/]
      str_length = talk.split.last

      if str_length.downcase == "lightning"
        length = LIGHTNING_TALK_LENGTH
      elsif str_length.include?("min")
        length = str_length.gsub!("min", '').to_i
      else
        fail ArgumentError, "invalid talk length"
      end
      [title, length]
    end

end
