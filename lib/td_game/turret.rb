class Turret
	attr_accessor :health_max, :health, :power_cost, :cost, :enabled, :fire_rate, :damage, :range, :position, :sprites, :dir, :fire_timer

	def initialize (health_max, health, power_cost, cost, enabled, fire_rate, damage, range, position, sprites)
		@health_max = health_max
		@health = health
		@power_cost = power_cost
		@cost = cost
		@enabled = enabled
		@fire_rate = fire_rate
		@damage = damage
		@range = range
		@position = position
		@sprites = sprites
		@dir = 0
		@fire_timer = 0
	end
end

def turret_ai_tick (turret, gamestate)
	# If we can fire again
	if (Gosu.milliseconds > turret.fire_timer)
		range = turret.range
		target = nil
		min_range = Float::INFINITY

		gamestate.enemies.each.with_index { |enemy, i|
			dst = Vector2.manhatten_distance(turret.position, enemy.tile_position)
			if (dst < range && dst < min_range)
				min_range = dst
				target = i
			end
		}

		if (target != nil)
			enemy = gamestate.enemies[target]
			facing_vector = enemy.position - turret.position
			angle = Vector2.angle(Vector2.new(0, 1), facing_vector)

			if (angle < Math::PI / 4)
				# Is down
				turret.dir = 2
			elsif (angle > Math::PI * 3 / 4)
				# Is up
				turret.dir = 0
			else
				if (facing_vector.x > 0)
					turret.dir = 1
				else
					turret.dir = 3
				end
			end

			turret.fire_timer = Gosu.milliseconds + 1000 / turret.fire_rate
			gamestate_damage_enemy(gamestate, turret.damage, target)
			gamestate.lasers.push({ :start => turret.position, :end => enemy.position, :time => Gosu.milliseconds })
		end
	end
end