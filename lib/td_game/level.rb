class Tile
	attr_accessor :type, :ground_sprite, :reference

	def initialize (type, ground_sprite, reference)
		@type = type
		@ground_sprite = ground_sprite
		@reference = reference
	end
end

class Level
	attr_reader :width, :height
	attr_accessor :crops, :turrets, :tiles, :fences, :round_number, :base_location

	def initialize (width, height, crops, turrets, round_number, base_location)
		@width = width
		@height = height
		
		@crops = crops
		@turrets = turrets
		@fences = Array.new(2 * @width * @height + @width + @height) { false }
		@round_number = round_number
		@base_location = base_location

		@tiles = Array.new(@width * @height) { Tile.new(TileType::Empty, "empty", nil) }
	end

	def [](x, y)
		if (x < 0 || y < 0 || x >= @width || y >= @height)
			raise RangeError, "Level index [#{x},#{y}] is out of bounds"
			return nil
		else
			return @tiles[x + y * @height]
		end
	end

	def []=(x, y, value)
		if (x < 0 || y < 0 || x >= @width || y >= @height)
			raise RangeError, "Level index [#{x},#{y}] is out of bounds"
			return nil
		else
			@tiles[x + y * @height] = value
		end
	end
end

# Returns fences for a given index
def level_fences_n (n, level)
	s = n + level.width
	w = level.width * (level.height + 1) + n + (n.to_i / level.width.to_i)
	e = w + 1

	return { :north => n, :south => s, :west => w, :east => e }
end

# Returns fences for a given coord
def level_fences (x, y, level)
	n = x + y * level.width
	return level_fences_n(n, level)
end

# Default Symbols + Sprites
# Empty = . = "empty" = 0
# Restricted = x = "restrict" = 1
# Base = B = "base" = 2
# ALSO LOCATED IN resources.rb
def level_from_map (map)
	level = Level.new(map.width, map.height, [], [], 0, nil)

	first_base = nil

	for i in 0...level.tiles.length
		# Set appropriate tile
		ground_sprite = nil
		case map.tiles[i]
		when TileType::Empty
			ground_sprite = "empty"
		when TileType::Restricted
			ground_sprite = "restrict"
		when TileType::Base
			ground_sprite = "base"

			if (first_base == nil)
				first_base = i
			end
		else
			puts "Warning - Unknown Tile Type [#{map.tiles[i]}]"
		end

		level.tiles[i] = Tile.new(map.tiles[i], ground_sprite, nil)
	end

	# Setup tiles for base
	if (first_base != nil)
		first_base_x = first_base % level.width
		first_base_y = (first_base - first_base_x) / level.height

		level.base_location = Vector2.new(first_base_x, first_base_y)

		# Check for EAST base
		if (level.width > first_base_x + 2 && level.height > first_base_y + 1 && level[first_base_x + 2, first_base_y].type == TileType::Base)
			level[first_base_x, first_base_y].ground_sprite = "barn_east"

			level[first_base_x + 1, first_base_y + 0].ground_sprite = nil
			level[first_base_x + 2, first_base_y + 0].ground_sprite = nil
			level[first_base_x + 0, first_base_y + 1].ground_sprite = nil
			level[first_base_x + 1, first_base_y + 1].ground_sprite = nil
			level[first_base_x + 2, first_base_y + 1].ground_sprite = nil
		# Check for NORTH base
		elsif (level.width > first_base_x + 1 && level.height > first_base_y + 2 && level[first_base_x, first_base_y + 2].type == TileType::Base)
			level[first_base_x, first_base_y].ground_sprite = "barn_north"

			level[first_base_x + 1, first_base_y + 0].ground_sprite = nil
			level[first_base_x + 0, first_base_y + 1].ground_sprite = nil
			level[first_base_x + 1, first_base_y + 1].ground_sprite = nil
			level[first_base_x + 0, first_base_y + 2].ground_sprite = nil
			level[first_base_x + 1, first_base_y + 2].ground_sprite = nil
		else
			puts "Warning - No valid 2x3 or 3x2 Base found for loaded map: \"#{map.name}\""
		end
	end

	return level
end

# Cleans up tile references to remove empty entries from crops and turrets (i.e. removed turrets/crops)
def level_cleanup (level)
	# Get indices of removed crops
	removed_crops = level.crops.map.with_index { |crop, i|
		if (crop == nil)
			i
		else
			nil
		end
	}
	removed_crops.compact!

	# Remove nil crops
	level.crops.compact!

	# Get indices of removed turrets
	removed_turrets = level.turrets.map.with_index { |turret, i|
		if (turret == nil || level[turret.position.x.floor, turret.position.y.floor].type != TileType::Turret)
			i
		else
			nil
		end
	}
	removed_turrets.compact!

	# Remove nil turrets
	level.turrets.compact!

	# Fix broken references
	for y in 0...level.height
		for x in 0...level.width
			# Get the appropriate reference list
			ref_list = nil
			case level[x,y].type
			when TileType::Crop
				ref_list = removed_crops
			when TileType::Turret
				ref_list = removed_turrets
			end

			if (ref_list != nil)
				# Check each removed index, if we were referencing after it, decrease our reference by 1
				change = 0
				for i in 0...ref_list.length
					if (level[x,y].reference > ref_list[i])
						change += 1
					end
				end

				level[x,y].reference -= change
			end
		end
	end
end

def level_draw (level, resources)
	posts = Array.new(level.width + 1) { Array.new(level.height + 1) { false } }

	post = resources.sprites["fence_post"]
	rail_ns = resources.sprites["fence_rail_NS"]
	rail_ew = resources.sprites["fence_rail_EW"]

	draw_post = -> (x, y) {
		pos = world_to_screen(Vector2.new(x, y))
		z_order = ZOrder::Objects + x + y + 0.1
		post.image.draw(pos.x - post.ox, pos.y - post.oy, z_order)
	}

	draw_rail = -> (x, y, ns) {
		pos = world_to_screen(Vector2.new(x, y))
		z_order = ZOrder::Objects + x + y + 0.2

		if (ns)
			rail_ns.image.draw(pos.x - rail_ns.ox, pos.y - rail_ns.oy, z_order)
		else
			rail_ew.image.draw(pos.x - rail_ew.ox, pos.y - rail_ew.oy, z_order)
		end
	}

	for y in 0...level.height
		for x in 0...level.width
			# Draw Ground Sprites

			# Set Turret Sprite
			if (level[x,y].type == TileType::Turret && level[x,y].reference != nil)
				turret = level.turrets[level[x,y].reference]
				case turret.dir
				when 0
					level[x,y].ground_sprite = turret.sprites[:north]
				when 1
					level[x,y].ground_sprite = turret.sprites[:east]
				when 2
					level[x,y].ground_sprite = turret.sprites[:south]
				when 3
					level[x,y].ground_sprite = turret.sprites[:west]
				end
			end

			# Set Crop Plot Sprite
			if (level[x,y].type == TileType::Crop && level[x,y].reference != nil)
				crop = level.crops[level[x,y].reference]
				stage = crop.growth_time - crop.rounds_until_harvest
				case crop.dir
				when 0
					level[x,y].ground_sprite = crop.sprites[stage][:north]
				when 1
					level[x,y].ground_sprite = crop.sprites[stage][:east]
				when 2
					level[x,y].ground_sprite = crop.sprites[stage][:south]
				when 3
					level[x,y].ground_sprite = crop.sprites[stage][:west]
				end
			end

			sprite = resources.sprites[ level[x,y].ground_sprite ]
			pos = world_to_screen(Vector2.new(x,y))

			if (sprite != nil)
				z_order = ZOrder::Objects + x + y + ([sprite.span_x, sprite.span_y].max - 1)

				if ([TileType::Crop, TileType::Turret].include?(level[x,y].type))
					z_order += 0.3
				end

				sprite.image.draw(pos.x - sprite.ox, pos.y - sprite.oy, z_order)
			end

			# Draw Fences
			fences = level_fences(x, y, level).transform_values { |i| level.fences[i] }
			# For each direction, if the fence exists, we will draw the posts (provided they aren't already drawn) then draw the railing
			# Note we will only handle East and South for the eastmost and southmost tiles respectively, this is to prevent redrawing them
			if (fences[:north])
				if (!posts[x][y])
					draw_post.call(x, y)
					posts[x][y] = true
				end
				if (!posts[x + 1][y])
					draw_post.call(x + 1, y)
					posts[x + 1][y] = true
				end
				draw_rail.call(x, y, false)
			end
			if (fences[:south] && y + 1 == level.height)
				if (!posts[x][y + 1])
					draw_post.call(x, y + 1)
					posts[x][y + 1] = true
				end
				if (!posts[x + 1][y + 1])
					draw_post.call(x + 1, y + 1)
					posts[x + 1][y + 1] = true
				end
				draw_rail.call(x, y + 1, false)
			end
			if (fences[:west])
				if (!posts[x][y])
					draw_post.call(x, y)
					posts[x][y] = true
				end
				if (!posts[x][y + 1])
					draw_post.call(x, y + 1)
					posts[x][y + 1] = true
				end
				draw_rail.call(x, y, true)
			end
			if (fences[:east] && x + 1 == level.width)
				if (!posts[x + 1][y])
					draw_post.call(x + 1, y)
					posts[x + 1][y] = true
				end
				if (!posts[x + 1][y + 1])
					draw_post.call(x + 1, y + 1)
					posts[x + 1][y + 1] = true
				end
				draw_rail.call(x + 1, y, true)
			end
		end
	end
end

def level_can_build_fence? (x, y, fence, level)
	success = false
	fences = level_fences(x, y, level)
	can_build = [TileType::Empty, TileType::Crop, TileType::Turret]

	# If we can potentially build fences
	if (can_build.include?(level[x, y].type))
		north_check = (y > 0 && can_build.include?(level[x, y - 1].type)) || (y == 0)
		south_check = (y < level.height - 1 && can_build.include?(level[x, y + 1].type)) || (y == level.height - 1)
		west_check = (x > 0 && can_build.include?(level[x - 1, y].type)) || (x == 0)
		east_check = (x < level.width - 1 && can_build.include?(level[x + 1, y].type)) || (x == level.width - 1)

		# Omit the opposite side, it shouldn't be considered
		case fence
		when fences[:north]
			south_check = true
		when fences[:south]
			north_check = true
		when fences[:west]
			east_check = true
		when fences[:east]
			west_check = true
		end

		success = north_check && south_check && west_check && east_check
	end

	return success
end

def level_can_build_tile? (x, y, level)
	success = false

	success = level[x, y].type == TileType::Empty

	return success
end

def level_can_build_rect? (top, bottom, level)
	success = true

	for y in top.y...bottom.y
		for x in top.x...bottom.x
			if (level[x, y].type != TileType::Empty)
				success = false
			end
		end
	end

	return success
end