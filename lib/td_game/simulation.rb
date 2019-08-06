class SpawnGroup
	attr_accessor :spawn_tile, :enemies, :time_between_spawns, :spawn_time_variation, :spawn_timer

	def initialize (spawn_tile, enemies, time_between_spawns, spawn_time_variation)
		@spawn_timer = 0

		@spawn_tile = spawn_tile
		@enemies = enemies
		@time_between_spawns = time_between_spawns
		@spawn_time_variation = spawn_time_variation
	end
end

class SimulationVariables
	attr_accessor :spawn_timer, :next_spawn, :restricted_tiles, :spawns, :base_field, :turret_field, :crop_field, :update_fields_timer, :disabled_tiles

	def initialize (gamestate)
		@spawn_timer = 4000
		@next_spawn = 0
		@spawns = []
		@disabled_tiles = []

		# Stores a list of restricted tiles
		@restricted_tiles = []		
		gamestate.level.tiles.each.with_index { |tile, i|
			if (tile.type == TileType::Restricted)
				@restricted_tiles.push(i)
			end
		}

		@update_fields_timer = 0
		@base_field = PotentialField.new(gamestate.level.width, gamestate.level.height)
		@turret_field = PotentialField.new(gamestate.level.width, gamestate.level.height)
		@crop_field = PotentialField.new(gamestate.level.width, gamestate.level.height)
	end
end

def simulation_update (gamestate, sim_vars, resources)
	# Detect start of round
	if (!gamestate.round_started)
		puts "Started Round #{gamestate.round}"
		gamestate.enemy_tokens = gamestate_get_enemy_tokens(gamestate.round)
		gamestate.round_started = true
		simulation_update_fields(gamestate, sim_vars)

		# Update disabled tiles
		disabled_tiles = []
		gamestate.level.tiles.each.with_index { |tile, i|
			if (tile.type == TileType::Disabled)
				disabled_tiles.push(i)
			end
		}

		disabled_tiles.each { |i|
			if (gamestate.level.tiles[i].reference <= 0)
				simulation_set_tile_to_empty(i, gamestate, resources)
			else
				gamestate.level.tiles[i].reference -= 1
			end
		}
	elsif (gamestate.round_started)	
		# Spawn Enemies
		if (Gosu.milliseconds > sim_vars.next_spawn)
			sim_vars.next_spawn = Gosu.milliseconds + sim_vars.spawn_timer + (rand(1000) - 500)
			simulation_spawn_enemies(gamestate, sim_vars, resources)
		end

		sim_vars.spawns.each.with_index { |spawn_group, i|
			# Update Spawn Group
			if (spawn_group.enemies.length > 0)
				# If we just started spawning
				if (spawn_group.spawn_timer == 0)
					simulation_set_tile_to_spawn(spawn_group.spawn_tile, gamestate, resources)

					# Guarantee an x-second telegraph
					spawn_group.spawn_timer = Gosu.milliseconds + 2000

					puts "Spawn Group Start" if DEBUG
				# Spawn the next enemy
				elsif (Gosu.milliseconds > spawn_group.spawn_timer)
						spawn_group.spawn_timer = Gosu.milliseconds + spawn_group.time_between_spawns + rand(spawn_group.spawn_time_variation) - (spawn_group.spawn_time_variation / 2)

						enemy = spawn_group.enemies.shift()
						enemy.animator = Animator.new(resources.animations["enemy_walk_east"], Gosu.milliseconds)

						gamestate.enemies.push(enemy)
						puts "Spawn Group Spawn" if DEBUG
				end
			# If we just finished spawning
			elsif (spawn_group.enemies.length <= 0)
				simulation_set_tile_to_restrict(spawn_group.spawn_tile, gamestate, resources)

				sim_vars.spawns[i] = nil
				puts "Spawn Group End" if DEBUG
			end
		}

		sim_vars.spawns.compact!

		# Detect end of round
		if (gamestate.enemy_tokens <= 0 && !gamestate.gameover && gamestate.enemies.length == 0 && sim_vars.spawns.length == 0)
			puts "Ended Round" if DEBUG
			gamestate.round_started = false
			gamestate.round += 1

			gamestate.phase = GamePhase::Building
			gamestate_do_crop_growth(gamestate)
		end
	end

	if (Gosu.milliseconds > sim_vars.update_fields_timer)
		sim_vars.update_fields_timer = Gosu.milliseconds + 5000
		simulation_update_fields(gamestate, sim_vars)
	end
end

def simulation_spawn_enemies (gamestate, sim_vars, resources)
	if (gamestate.enemy_tokens > 0)
		spawn_tile = sim_vars.restricted_tiles[rand(sim_vars.restricted_tiles.length)]

		enemy_count = 3 + rand(4)
		gamestate.enemy_tokens -= enemy_count
		enemy_target = [TileType::Base, TileType::Crop, TileType::Turret].sample

		enemies = []
		for i in 0...enemy_count
			enemy = resources.enemies["Crawler"].dup
			enemy.position = Vector2.new(spawn_tile % gamestate.level.width + 0.5, spawn_tile / gamestate.level.width + 0.5)
			enemy.target = enemy_target
			enemies.push(enemy)
		end

		time_between_spawns = 1000
		spawn_time_variation = 200
		spawn_group = SpawnGroup.new(spawn_tile, enemies, time_between_spawns, spawn_time_variation)

		sim_vars.spawns.push(spawn_group)
	end
end

def simulation_update_fields (gamestate, sim_vars)
	update_field = -> (tile_type) {
		level = gamestate.level

		# Create a new potential field, fill each tile with the longest possible distance
		field = PotentialField.new(level.width, level.height, level.tiles.length)

		all_tiles = level.tiles.map.with_index { |tile, i|
			{ :type => tile.type, :solid => [TileType::Base].include?(tile.type), :visited => false, :index => i }
		}

		# Breadth first search to fill out field	
		queue = []
		# Start with all tiles of the desired type
		for i in 0...all_tiles.length
			if (all_tiles[i][:type] == tile_type)
				queue.unshift(all_tiles[i])
				field.tiles[all_tiles[i][:index]] = 0
			end
		end

		if (queue.length > 0)
			queue[0][:visited] = true

			while queue.length > 0		
				v = queue.shift
				
				n = v[:index]
				x = n % level.width
				y = n / level.width

				v_cost = field.tiles[v[:index]]

				fences = level_fences_n(n, level)
				neighbours = []

				# Check walkability to neighbours
				if (!level.fences[fences[:north]] && y > 0 && !all_tiles[n - level.width][:solid])
					neighbours.push(all_tiles[n - level.width])
				end
				if (!level.fences[fences[:south]] && y < level.height - 1 && !all_tiles[n + level.width][:solid])
					neighbours.push(all_tiles[n + level.width])
				end
				if (!level.fences[fences[:west]] && x > 0 && !all_tiles[n - 1][:solid])
					neighbours.push(all_tiles[n - 1])
				end
				if (!level.fences[fences[:east]] && x < level.width - 1 && !all_tiles[n + 1][:solid])
					neighbours.push(all_tiles[n + 1])
				end

				for i in 0...neighbours.length
					if (!neighbours[i][:visited])
						neighbours[i][:visited] = true
						queue.push(neighbours[i])
					end

					# Update cost if we are closer
					if (field.tiles[neighbours[i][:index]] > v_cost + 1)
						field.tiles[neighbours[i][:index]] = v_cost + 1
					end
				end
			end

			# Find the highest cost
			highest = 0
			for i in 0...all_tiles.length
				if (!all_tiles[i][:visited] && !all_tiles[i][:solid])
					puts "Field did not reach tile #{i}" if DEBUG
				end

				if (field.tiles[all_tiles[i][:index]] > highest)
					highest = field.tiles[all_tiles[i][:index]]
				end
			end

			puts "Highest cost was #{highest}" if DEBUG
		end

		return field
	}

	sim_vars.base_field = update_field.call(TileType::Base)
	sim_vars.crop_field = update_field.call(TileType::Crop)
	sim_vars.turret_field = update_field.call(TileType::Turret)
end

def simulation_set_tile_to_empty (tile_index, gamestate, resources)
	gamestate.level.tiles[tile_index].type = TileType::Empty
	gamestate.level.tiles[tile_index].ground_sprite = "empty"
	gamestate.level.tiles[tile_index].reference = nil
end

def simulation_set_tile_to_restrict (tile_index, gamestate, resources)
	gamestate.level.tiles[tile_index].type = TileType::Restricted
	gamestate.level.tiles[tile_index].ground_sprite = "restrict"
	gamestate.level.tiles[tile_index].reference = nil
end

def simulation_set_tile_to_spawn (tile_index, gamestate, resources)
	gamestate.level.tiles[tile_index].type = TileType::Spawn
	gamestate.level.tiles[tile_index].ground_sprite = "enemy_spawn"
	gamestate.level.tiles[tile_index].reference = nil

	level_cleanup(gamestate.level)
end

def simulation_disable_tile (tile_index, gamestate, resources)
	gamestate.level.tiles[tile_index].type = TileType::Disabled
	gamestate.level.tiles[tile_index].ground_sprite = "disabled"
	gamestate.level.tiles[tile_index].reference = 2

	level_cleanup(gamestate.level)
end