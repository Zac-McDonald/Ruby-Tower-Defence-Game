class Enemy
	attr_accessor :health_max, :health, :speed, :damage, :position, :tile_position, :target, :animator, :velocity, :dir, :sprites, :attacking_timer, :target_pos

	def initialize (health_max, health, speed, damage, position, sprites)
		@health_max = health_max
		@health = health
		@speed = speed
		@damage = damage
		@position = position
		@tile_position = Vector2.one * -1
		@target_pos = Vector2.zero

		@target = nil
		@animator = nil
		@velocity = Vector2.zero
		@dir = 0
		@sprites = sprites
		@attacking_timer = 0
	end
end

def enemy_ai_tick (enemy, gamestate, sim_vars, resources)
	width = gamestate.level.width
	height = gamestate.level.height

	tile_position = enemy.position.floor
	x = tile_position.x.to_i
	y = tile_position.y.to_i

	pick_dir = -> (n, anims) {
		anim = nil
		case n
		when 0
			anim = anims[:north]
		when 1
			anim = anims[:east]
		when 2
			anim = anims[:south]
		when 3
			anim = anims[:west]
		end
		return anim
	}

	if (Gosu.milliseconds > enemy.attacking_timer && enemy.tile_position != tile_position)
		# For Path Following
		# Pick random neighbour with lowest cost (add random fraction to all costs, then pick lowest)
		# Desired vector towards neighbour center
		# Steer to desired vector
		# Push off or clamp from blocked sides (fences)

		field = sim_vars.base_field
		if (enemy.target == TileType::Crop && gamestate.level.crops.length > 0)
			field = sim_vars.crop_field
		elsif (enemy.target == TileType::Turret && gamestate.level.turrets.length > 0)
			field = sim_vars.turret_field
		else
			enemy.target = TileType::Base
		end

		# Gather neighbour information
		fences = level_fences_n(x + width * y, gamestate.level)
		fences[:north] = gamestate.level.fences[fences[:north]]
		fences[:south] = gamestate.level.fences[fences[:south]]
		fences[:west] = gamestate.level.fences[fences[:west]]
		fences[:east] = gamestate.level.fences[fences[:east]]

		neighbour_tiles = Array.new(4) { nil }
		neighbour_costs = Array.new(4) { width*height }
		if (!fences[:north] && y > 0)
			neighbour_tiles[0] = gamestate.level[x, y - 1]
			neighbour_costs[0] = field[x, y - 1] + rand(-0.5...0.5)
		end
		if (!fences[:south] && y < height - 1)
			neighbour_tiles[2] = gamestate.level[x, y + 1]
			neighbour_costs[2] = field[x, y + 1] + rand(-0.5...0.5)
		end
		if (!fences[:west] && x > 0)
			neighbour_tiles[3] = gamestate.level[x - 1, y]
			neighbour_costs[3] = field[x - 1, y] + rand(-0.5...0.5)
		end
		if (!fences[:east] && x < width - 1)
			neighbour_tiles[1] = gamestate.level[x + 1, y]
			neighbour_costs[1] = field[x + 1, y] + rand(-0.5...0.5)
		end

		# Decide if we are attacking or walking
		neighbouring_targets = neighbour_tiles.map.with_index { |tile, i|
			if (tile != nil && tile.type == enemy.target)
				i
			else
				nil
			end
		}.compact!

		# If in range of a target, attack it
		if (neighbouring_targets.length > 0)
			enemy.dir = neighbouring_targets.sample
			enemy.attacking_timer = Gosu.milliseconds + 500

			case enemy.target
			when TileType::Base
				gamestate_damage_base(gamestate, enemy.damage)
			when TileType::Crop
				gamestate_damage_crop(gamestate, enemy.damage, neighbour_tiles[enemy.dir].reference)
			when TileType::Turret
				gamestate_damage_turret(gamestate, enemy.damage, neighbour_tiles[enemy.dir].reference)
			end

			# Reset the target
			enemy.target = [TileType::Base, TileType::Crop, TileType::Turret].sample

			# Switch to attack anim
			enemy.animator.animation = resources.animations[pick_dir.call(enemy.dir, enemy.sprites[:attack])]
			enemy.animator.start_time = Gosu.milliseconds

			enemy.velocity = Vector2.zero
		# Otherwise move towards the cheapest neighbour
		else
			dir_vectors = [Vector2.new(0, -1), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(-1, 0)]
			move_dir = Vector2.zero

			lowest_neighbour = width*height
			sorted_costs = [0, 1, 2, 3].sort { |i, j|
				neighbour_costs[i] <=> neighbour_costs[j]
			}
			enemy.dir = sorted_costs[0]

			enemy.velocity = dir_vectors[sorted_costs[0]] / 40.0
			enemy.tile_position = tile_position

			# Reset animation
			enemy.animator.animation = resources.animations[pick_dir.call(enemy.dir, enemy.sprites[:walk])]
			enemy.animator.start_time = Gosu.milliseconds
		end
	end

	enemy.position += enemy.velocity
	#enemy.position.x.round + 0.5
	#enemy.position.y.round + 0.5

	#enemy.velocity = move_dir.set_magnitude(1.0 / enemy.speed.to_f) / 40.0
	#enemy.position += enemy.velocity
	#enemy.position = enemy.position.round(0.5)
end