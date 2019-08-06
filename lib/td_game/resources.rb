class Sprite
	attr_accessor :name, :image, :ox, :oy, :span_x, :span_y

	def initialize (name, image, ox, oy, span_x, span_y)
		@name = name
		@image = image
		@ox = ox
		@oy = oy
		@span_x = span_x
		@span_y = span_y
	end
end

class Frame
	attr_accessor :sprite, :duration

	def initialize (sprite, duration)
		@sprite = sprite
		@duration = duration
	end
end

class Animation
	attr_accessor :name, :play_mode, :loop, :frames, :duration

	def initialize (name, play_mode, loop, frames)
		@name = name
		@play_mode = play_mode
		@loop = loop
		@frames = frames

		@duration = 0
		for i in 0...@frames.length
			@duration += @frames[i].duration
		end
	end
end

# For keeping track of an animation
class Animator
	attr_accessor :animation, :start_time

	def initialize (animation, start_time)
		@animation = animation
		@start_time = start_time
	end
end

def animation_get_frame (anim, start_time, current_time = Gosu.milliseconds)
	delta_time = current_time - start_time
	frame = nil

	total = 0
	for i in 0...anim.frames.length
		# If we haven't already found the frame
		if (frame == nil)
			# Check if it is on this frame
			new_total = total + anim.frames[i].duration
			if (delta_time % anim.duration < new_total)
				frame = anim.frames[i].sprite
			end

			total = new_total
		end
	end

	return frame
end

def animator_get_frame (animator, current_time = Gosu.milliseconds)
	return animation_get_frame(animator.animation, animator.start_time, current_time)
end

class Map
	attr_accessor :name, :width, :height, :tiles

	def initialize (name, width, height, tiles)
		@name = name
		@width = width
		@height = height
		@tiles = tiles
	end
end

class Resources
	attr_accessor :textures, :sprites, :animations, :sounds, :maps, :turrets, :enemies, :crops, :fonts

	def initialize ()
		@textures = {}		# Filename => Image
		@sprites = {}		# Sprite Name => Subimage
		@animations = {}	# Animation Name => Animation
		@maps = {}			# Map Name => Map
		@turrets = {}		# Turret Name => Turret
		@enemies = {}		# Enemy Name => Enemy
		@crops = {}			# Crop Name => Crop

		@sounds = {}

		@fonts = {}			# Font Name => Font

		# Load resource files into appropriate locations
		resources = Dir['resources/**/*']

		# Load image related files. Note: '.sheet' and '.anim' are in JSON
		resources_load_textures(@textures, resources.select { |f| f.end_with?(".png", ".jpg", ".jpeg") })
		resources_load_spritesheets(@sprites, @textures, resources.select { |f| f.end_with?(".sheet") })
		resources_load_animations(@animations, @sprites, resources.select { |f| f.end_with?(".anim") })
		resources_load_maps(@maps, resources.select { |f| f.end_with?(".map") })
		resources_load_entities(@turrets, @enemies, @crops, resources.select { |f| f.end_with?(".entity") })

		resources_load_fonts(@fonts, resources.select { |f| f.end_with?(".ttf") })
	end
end

def resources_load_fonts (fonts, files)
	files.each { |f| 
		font_name = File.basename(f, ".ttf")
		sizes = [16, 24]

		for i in 0...sizes.length
			fonts[font_name + sizes[i].to_s] = Gosu::Font.new(sizes[i], options = { :name => f })
		end
	}
end

def resources_load_textures (textures, files)
	files.each { |f| 
		textures[f] = Gosu::Image.new(Dir.pwd + "/" + f, option = {:retro => true})
	}
end

def resources_load_spritesheets (sprites, textures, files)
	files.each { |f|
		# Attempt to read JSON from file
		begin
			spritesheet_text = File.read(Dir.pwd + "/" + f)
			spritesheet = JSON.parse(spritesheet_text)

			for i in 0...spritesheet.length
				# Load Sprite
				sprite = spritesheet[i]

				# Validate the JSON - only add sprite if it contains all required attributes
				if (sprite.key?("name") && sprite.key?("texture") && sprite.key?("x") && sprite.key?("y") && sprite.key?("ox") && sprite.key?("oy") && sprite.key?("width") && sprite.key?("height") && (sprite["x"].is_a? Integer) && (sprite["y"].is_a? Integer) && (sprite["ox"].is_a? Integer) && (sprite["oy"].is_a? Integer) && (sprite["width"].is_a? Integer) && (sprite["height"].is_a? Integer))
					# Get full path (from project) to texture
					texture = File.dirname(f) + "/" + sprite["texture"]

					# Check for duplicate sprites
					if (sprites.key?(sprite["name"]))
						puts "Warning - Duplicate sprite: \"#{sprite["name"]}\" in sheet: \"#{f}\""
					end

					span = (sprite.key?("span_x") && sprite.key?("span_y") && (sprite["span_x"].is_a? Integer) && (sprite["span_y"].is_a? Integer))

					# Check for valid texture
					if (textures.key?(texture))
						image = textures[texture].subimage(sprite["x"], sprite["y"], sprite["width"], sprite["height"])
						sprites[sprite["name"]] = Sprite.new(sprite["name"], image, sprite["ox"], sprite["oy"], (span) ? sprite["span_x"] : 1, (span) ? sprite["span_y"] : 1)
					else
						puts "Failed to load sprite: \"#{sprite["name"]}\" in sheet: \"#{f}\" - Missing Texture"
					end
				else
					puts "Failed to load sprite: index \"#{i}\" in sheet: \"#{f}\" - Fix Attributes"
				end
			end
		rescue => error
			# Failed to read file for some reason
			puts "Failed to read file [spritesheet]: \"#{f}\" with error: #{error}"
		end
	}
end

def resources_load_animations (animations, sprites, files)
	files.each { |f|
		# Attempt to read JSON from file
		begin
			animation_text = File.read(Dir.pwd + "/" + f)
			animation = JSON.parse(animation_text)

			for i in 0...animation.length
				# Load Animation
				anim = animation[i]

				# Validate the JSON - only add animation if it contains all required attributes
				if (anim.key?("name") && anim.key?("play_mode") && anim.key?("loop") && anim.key?("frames"))
					# Check for duplicate animations
					if (animations.key?(anim["name"]))
						puts "Warning - Duplicate anim: \"#{anim["name"]}\" in anim sheet: \"#{f}\""
					end

					# Read each frame
					frames = anim["frames"].map.with_index { |frame, index|
						# Validate frame JSON
						if (frame.key?("sprite") && frame.key?("duration") && (frame["duration"].is_a? Integer) && sprites.key?(frame["sprite"]))
							Frame.new(sprites[frame["sprite"]], frame["duration"])
						else
							puts "Failed to load frame #{index} of animation \"#{anim["name"]}\""
							nil
						end
					}
					# Remove bad frames
					frames.compact!

					animations[anim["name"]] = Animation.new(anim["name"], anim["play_mode"], anim["loop"], frames)
				else
					puts "Failed to load anim: index \"#{i}\" in anim sheet: \"#{f}\" - Fix Attributes"
				end
			end
		rescue => error
			# Failed to read file for some reason
			puts "Failed to read file [animation]: \"#{f}\" with error: #{error}"
		end
	}
end

# Default Symbols + Sprites
# Empty = . = "empty" = 0
# Restricted = x = "restrict" = 1
# Base = B = "base" = 2
# ALSO LOCATED IN level.rb
def resources_load_maps (maps, files)
	files.each { |f|
		# Attempt to read JSON from file
		begin
			map_text = File.read(Dir.pwd + "/" + f)
			map = JSON.parse(map_text)

			# Validate the JSON - only add map if it contains all required attributes
			if (map.key?("name") && map.key?("width") && map.key?("height") && map.key?("tiles") && (map["width"].is_a? Integer) && (map["height"].is_a? Integer))
				# Check for duplicate maps
				if (maps.key?(map["name"]))
					puts "Warning - Duplicate map name: \"#{map["name"]}\" in \"#{f}\""
				end

				tiles = Array.new(map["width"] * map["height"])
				# Note: Using width/height instead of lengths ensures that an error is thrown if there is a missmatch with line lengths
				for i in 0...map["height"]
					chars = map["tiles"][i].split('')
					for c in 0...map["width"]
						value = nil
						case chars[c]
						when "."
							value = TileType::Empty
						when "x"
							value = TileType::Restricted
						when "B"
							value = TileType::Base
						else
							puts "Warning - Unknown Tile Symbol [#{chars[c]}]"
						end

						tiles[c + i * map["height"]] = value
					end
				end

				maps[map["name"]] = Map.new(map["name"], map["width"], map["height"], tiles)
			else
				puts "Failed to load map: \"#{f}\" - Fix Attributes"
			end
		rescue => error
			# Failed to read file for some reason
			puts "Failed to read file [map]: \"#{f}\" with error: #{error}"
		end
	}
end

def resources_load_entities(turrets, enemies, crops, files)
	files.each { |f|
		# Attempt to read JSON from file
		begin
			entities_text = File.read(Dir.pwd + "/" + f)
			entities = JSON.parse(entities_text)

			for i in 0...entities.length
				# Load Entity
				entity = entities[i]

				# Validate the JSON - only add entity if it contains all required attributes
				if (entity.key?("name") && entity.key?("type"))
					case entity["type"]
					when "turret"
						resources_load_turret(turrets, entity, f)
					when "enemy"
						resources_load_enemy(enemies, entity, f)
					when "crop"
						resources_load_crop(crops, entity, f)
					else
						puts "Unknown entity type [\"#{entity["type"]}\"] in entity: \"#{f}\""
					end
				else
					puts "Failed to load entity: \"#{f}\" - Fix Attributes"
				end
			end
		rescue => error
			# Failed to read file for some reason
			puts "Failed to read file [entity]: \"#{f}\" with error: #{error}"
		end
	}
end

def resources_load_turret (turrets, turret, f)
	# Validate the JSON - only add turret if it contains all required attributes
	if (turret.key?("health_max") && turret.key?("power_cost") && turret.key?("cost") && turret.key?("fire_rate")  && turret.key?("damage")  && turret.key?("range") && turret.key?("sprites") && (turret["health_max"].is_a? Integer) && (turret["power_cost"].is_a? Integer) && (turret["cost"].is_a? Integer) &&  (turret["fire_rate"].is_a? Float) && (turret["damage"].is_a? Integer) && (turret["range"].is_a? Integer))
		# Check for duplicate turrets
		if (turrets.key?(turret["name"]))
			puts "Warning - Duplicate turret name: \"#{turret["name"]}\" in \"#{f}\""
		end

		# Process Sprites
		sprites = { :north => turret["sprites"]["north"], :south => turret["sprites"]["south"], :east => turret["sprites"]["east"], :west => turret["sprites"]["west"]}

		turrets[turret["name"]] = Turret.new(turret["health_max"], turret["health_max"], turret["power_cost"], turret["cost"], true, turret["fire_rate"], turret["damage"], turret["range"], nil, sprites)
	else
		puts "Failed to load turret: \"#{f}\" - Fix Attributes"
	end
end



def resources_load_enemy (enemies, enemy, f)
	# Validate the JSON - only add enemy if it contains all required attributes
	if (enemy.key?("health_max") && enemy.key?("speed") && enemy.key?("damage") && enemy.key?("anim_walk") && enemy.key?("anim_attack") && (enemy["health_max"].is_a? Integer) && (enemy["speed"].is_a? Float) && (enemy["damage"].is_a? Integer))
		# Check for duplicate turrets
		if (enemies.key?(enemy["name"]))
			puts "Warning - Duplicate enemy name: \"#{enemy["name"]}\" in \"#{f}\""
		end

		# Process Animation Sprites
		sprites = {}
		for i in 0...enemy["anim_walk"].length
			walk_anim = { :north => enemy["anim_walk"]["north"], :south => enemy["anim_walk"]["south"], :east => enemy["anim_walk"]["east"], :west => enemy["anim_walk"]["west"]}
			sprites[:walk] = walk_anim
		end
		for i in 0...enemy["anim_attack"].length
			attack_anim = { :north => enemy["anim_attack"]["north"], :south => enemy["anim_attack"]["south"], :east => enemy["anim_attack"]["east"], :west => enemy["anim_attack"]["west"]}
			sprites[:attack] = attack_anim
		end

		enemies[enemy["name"]] = Enemy.new(enemy["health_max"], enemy["health_max"], enemy["speed"], enemy["damage"], nil, sprites)
	else
		puts "Failed to load enemy: \"#{f}\" - Fix Attributes"
	end
end

def resources_load_crop (crops, crop, f)
	# Validate the JSON - only add crop if it contains all required attributes
	if (crop.key?("health_max") && crop.key?("cost") && crop.key?("harvest") && crop.key?("growth_time") && crop.key?("growth_sprites") && (crop["harvest"].is_a? Integer) && (crop["health_max"].is_a? Integer) && (crop["cost"].is_a? Integer) && (crop["growth_time"].is_a? Integer))
		# Check for duplicate turrets
		if (crops.key?(crop["name"]))
			puts "Warning - Duplicate crop name: \"#{crop["name"]}\" in \"#{f}\""
		end

		if (crop["growth_sprites"].length != crop["growth_time"])
			puts "Warning - Crop sprites/growth_time mismatch: \"#{crop["name"]}\" in \"#{f}\""
		end

		# Process Growth Sprites
		sprites = []
		for i in 0...crop["growth_sprites"].length
			sprites.push({ :north => crop["growth_sprites"][i]["north"], :south => crop["growth_sprites"][i]["south"], :east => crop["growth_sprites"][i]["east"], :west => crop["growth_sprites"][i]["west"]})
		end

		crops[crop["name"]] = CropPlot.new(crop["health_max"], crop["health_max"], crop["cost"], crop["harvest"], crop["growth_time"], crop["growth_time"], nil, sprites)
	else
		puts "Failed to load crop: \"#{f}\" - Fix Attributes"
	end
end
