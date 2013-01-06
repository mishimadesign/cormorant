require './cormorant'
require 'clockwork'
include Clockwork

handler do |job|
  begin
    cormorant = Cormorant.new
    cormorant.wake
    puts "run #{job}"
  rescue Exception => e
    puts "failed to run #{job}"
    puts "reason: " + e.to_s
  end
end

every(1.hour, 'cormorant')
