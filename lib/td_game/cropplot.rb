class CropPlot
	attr_accessor :health_max, :health, :cost, :harvest, :growth_time, :rounds_until_harvest, :sprites, :dir, :position

	def initialize (health_max, health, cost, harvest, growth_time, rounds_until_harvest, position, sprites)
		@health_max = health_max
		@health = health
		@cost = cost
		@harvest = harvest
		@growth_time = growth_time
		@rounds_until_harvest = rounds_until_harvest
		@position = position
		@sprites = sprites
		@dir = 0
	end
end