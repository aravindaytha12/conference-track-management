require "time"

class Session
  attr_reader :talks
  attr_reader :available_time
  attr_reader :time

  MORNING_LENGTH = 180
  AFTERNOON_LENGTH = 240

  def initialize(period="morning")
    @talks = []

    if period.downcase == "afternoon"
      @time = Time.parse("13:00")
      @available_time = AFTERNOON_LENGTH
    else
      @time = Time.parse("09:00")
      @available_time = MORNING_LENGTH
    end
  end

  def has_space?(talk_length)
    @available_time >= talk_length
  end

  def add(title, length)
    @available_time -= length
    @talks << "#{schedule(length)} #{title} #{length_format(length)}"
    # @available_time -= 5
    # @talks << "5 min break"
  end

  def network_time
    return "16:00" if @time < Time.parse("16:00")
    @time.strftime("%H:%M")
  end

  private
    def schedule(length)
      format = @time.strftime("%H:%M")
      @time += (60 * length)
# binding.pry
      format
    end

    def length_format(length)
      length == 5 ? "lightning" : "#{length}min"
    end

end
