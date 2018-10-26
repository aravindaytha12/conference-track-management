require_relative "ctm/track"
require_relative "ctm/session"
require_relative "ctm/talk"
require "pry"

# file = ARGV.first
file = './lib/test_input.txt'
talk_lists_hash = Hash.new
File.readlines(file).each do |line|
  t = Talk.new(line.strip)
  talk_lists_hash[t.title] = t.length
end

number_of_tracks_needed = Talk.quantity_of_tracks(talk_lists_hash)
number_of_tracks_needed.times do |n|
  puts
  puts "TRACK #{n + 1}"

  track = Track.new
  track.insert_talks_on_track(talk_lists_hash)#track objects = morning_sessions, afternoon_sessions 
  Talk.update_talk_lists(talk_lists_hash, track)#Deleting old talk related hash data, in next looping.
  puts "- MORNING SESSION"
  puts track.morning_sessions.talks
  puts "12:00 Lunch"
  puts "- AFTERNOON SESSION"
  puts track.afternoon_sessions.talks
  puts "#{track.afternoon_sessions.network_time} Networking Event"
  puts "==============================="

end
