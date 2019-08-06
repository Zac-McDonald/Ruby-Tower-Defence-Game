module BuildingOperation
	None, Fence, Crop, Turret = *(0...4)
end

class BuildAction
	# For fence operations: data = { id => new_state }
	# For crop operations: data = { Vector2 => crop_type }
	# For turret operations: data = { Vector2 => turret_type }
	attr_accessor :operation, :data, :type

	def initialize (operation, data, type)
		@operation = operation
		@data = data
		@type = type
	end
end

class BuildableObject
	attr_accessor :name, :type, :sprite

	def initialize (name, type, sprite)
		@name = name
		@type = type
		@sprite = sprite
	end
end

class BuildVariables
	attr_accessor :selecting_area, :select_start, :select_end, :removing, :operation, :fence_x_first, :build_catalogue, :selected_index, :mouse_over_index, :scroll_index, :warning_text, :warning_text_prev, :warning_timer, :current_cost, :mouse_over_start_round, :mouse_over_power_upgrade

	def initialize (resources)
		@selecting_area = false
		@select_start = nil
		@select_end = nil
		@removing = removing
		@operation = BuildingOperation::Fence
		@fence_x_first = false

		@selected_index = 0
		@mouse_over_index = nil
		@scroll_index = 0

		@mouse_over_start_round = false
		@mouse_over_power_upgrade = false

		@warning_text = ""
		@warning_text_prev = ""
		@warning_timer = 0

		@current_cost = nil

		@build_catalogue = [BuildableObject.new("Fence", BuildingOperation::Fence, "fence_preview")]
		resources.turrets.each { |key, value|
			@build_catalogue.push(BuildableObject.new(key, BuildingOperation::Turret, value.sprites[:east]))
		}
		resources.crops.each { |key, value|
			@build_catalogue.push(BuildableObject.new(key, BuildingOperation::Crop, value.sprites.last[:east]))
		}
	end
end

def building_button_down (build_vars, id, mouse_vector_world, gamestate)
	if (id == Gosu::MsLeft || id == Gosu::MsRight)
		# If we are not moused over the selection pane
		if (build_vars.mouse_over_index == nil)
			if (build_vars.mouse_over_start_round)
				# Start Next Round
				puts "Start Round" if DEBUG
				gamestate.phase = GamePhase::Simulation
			elsif (build_vars.mouse_over_power_upgrade)
				# Attempt Upgrade Power
				puts "Upgrade Power" if DEBUG
				upgrade_cost = gamestate_power_upgrade_cost(gamestate)
				can_afford_update = gamestate_can_afford?(gamestate, upgrade_cost, 0)

				if (can_afford_update)
					gamestate_update_currency(gamestate, upgrade_cost, 0)
					gamestate_upgrade_power(gamestate, 2)
				else
					build_vars.warning_text = "Cannot afford to upgrade"
				end
			else
				# If mouse left - begin drag operation
				build_vars.selecting_area = true
				build_vars.removing = (id == Gosu::MsRight)
				build_vars.select_start = mouse_vector_world
				build_vars.current_cost = nil
				puts "Started Drag at [#{build_vars.select_start.x}, #{build_vars.select_start.y}]" if DEBUG
			end
		elsif (id == Gosu::MsLeft)
			build_vars.selected_index = build_vars.mouse_over_index
		end
	elsif (id == Gosu::KbLeftAlt)
		# If left alt - flip fence drawing
		build_vars.fence_x_first = !build_vars.fence_x_first
	elsif (id == Gosu::KbSpace && DEBUG)
		#gamestate_do_crop_growth(gamestate)
		gamestate_update_currency(gamestate, -10000, 0)
	end
end

def building_button_up (build_vars, id, mouse_vector_world)
	if ((id == Gosu::MsLeft  || id == Gosu::MsRight) && build_vars.selecting_area)
		build_vars.selecting_area = false
		build_vars.select_end = mouse_vector_world
		puts "Finished Drag at [#{build_vars.select_end.x}, #{build_vars.select_end.y}]" if DEBUG
	end
end

def building_fence_operation (start_point, end_point, x_first, removing, level)
	map_bounds = Vector2.new(level.width, level.height)
	start_point = start_point.round.clamp(Vector2.zero, map_bounds)
	end_point = end_point.round.clamp(Vector2.zero, map_bounds)

	modified_fences = {}
	fence_path = building_fence_path(start_point, end_point, x_first)

	for x in fence_path[:range_x]
		y = fence_path[:set_y]
		fence = nil
		# Get fence index
		if (fence_path[:set_y] == level.height)
			y -= 1
			fence = level_fences(x, y, level)[:south]
		else
			fence = level_fences(x, y, level)[:north]
		end

		# Check we can build here
		if (level_can_build_fence?(x, y, fence, level))
			modified_fences[fence] = !removing
		end
	end
	for y in fence_path[:range_y]
		x = fence_path[:set_x]
		fence = nil
		# Get fence index
		if (fence_path[:set_x] == level.width)
			x -= 1
			fence = level_fences(x, y, level)[:east]
		else
			fence = level_fences(x, y, level)[:west]
		end

		# Check we can build here
		if (level_can_build_fence?(x, y, fence, level))
			modified_fences[fence] = !removing
		end
	end

	return BuildAction.new(BuildingOperation::Fence, modified_fences, "edge")
end

def building_tile_operation (build_vars, start_point, end_point, level, density = 1)
	map_bounds = Vector2.new(level.width - 1, level.height - 1)
	# Offset the points to centre on tiles, not junctions
	start_point = (start_point + Vector2.one * 0.5).floor.clamp(Vector2.zero, map_bounds)
	end_point = (end_point + Vector2.one * 0.5).floor.clamp(Vector2.zero, map_bounds)

	modified_objects = {}
	top = Vector2.min(start_point, end_point)
	bottom = Vector2.max(start_point, end_point)

	for y in top.y...bottom.y
		for x in top.x...bottom.x
			if (level_can_build_tile?(x, y, level))
				modified_objects[Vector2.new(x,y)] = build_vars.build_catalogue[build_vars.selected_index].name
			end
		end
	end

	return BuildAction.new(build_vars.operation, modified_objects, "tile")
end

def building_rect_operation (build_vars, start_point, end_point, level)
	map_bounds = Vector2.new(level.width - 1, level.height - 1)
	# Offset the points to centre on tiles, not junctions
	start_point = (start_point + Vector2.one * 0.5).floor.clamp(Vector2.zero, map_bounds)
	end_point = (end_point + Vector2.one * 0.5).floor.clamp(Vector2.zero, map_bounds)

	top = Vector2.min(start_point, end_point)
	bottom = Vector2.max(start_point, end_point)

	modification = nil
	if (level_can_build_rect?(top, bottom, level))
		modification = { :type => "rect", :top => top, :bottom => bottom, :object => build_vars.build_catalogue[build_vars.selected_index].name }
	end
	return BuildAction.new(build_vars.operation, modification, "rect")
end

def building_removal_operation (build_vars, start_point, end_point, level)
	map_bounds = Vector2.new(level.width - 1, level.height - 1)
	# Offset the points to centre on tiles, not junctions
	start_point = (start_point + Vector2.one * 0.5).floor.clamp(Vector2.zero, map_bounds)
	end_point = (end_point + Vector2.one * 0.5).floor.clamp(Vector2.zero, map_bounds)

	top = Vector2.min(start_point, end_point)
	bottom = Vector2.max(start_point, end_point)

	modification = { :top => top, :bottom => bottom }
	return BuildAction.new(build_vars.operation, modification, "tile")
end

def building_update (build_vars, gamestate, resources, mouse_vector_world)
	level = gamestate.level

	# Update Operation
	if (build_vars.selected_index == nil)
		build_vars.operation = BuildingOperation::None
	else
		build_vars.operation = build_vars.build_catalogue[build_vars.selected_index].type
	end

	# If we are dragging
	if (build_vars.operation != BuildingOperation::None && build_vars.select_start != nil)
		start_point = build_vars.select_start
		end_point = build_vars.select_end
		end_point ||= mouse_vector_world

		# Get build action
		action = nil
		if (build_vars.operation == BuildingOperation::Fence)
			action = building_fence_operation(start_point, end_point, build_vars.fence_x_first, build_vars.removing, level)
		elsif (!build_vars.removing)
			if (build_vars.operation ==  BuildingOperation::Turret)
				action = building_tile_operation(build_vars, start_point, end_point, level)
			elsif (build_vars.operation ==  BuildingOperation::Crop)
				action = building_tile_operation(build_vars, start_point, end_point, level)
			end
		else (build_vars.removing)
			action = building_removal_operation(build_vars, start_point, end_point, level)
		end

		build_vars.current_cost = building_get_cost_of_build(action, build_vars.removing, level, resources)

		# Only on finished drag do we try to build it
		if (!build_vars.selecting_area && build_vars.select_end != nil)
			# If valid build action
			if (action != nil && building_try_action(action, build_vars.removing, level, resources))
				if (build_vars.removing || gamestate_can_afford?(gamestate, build_vars.current_cost[:cost], build_vars.current_cost[:power_cost]))
					puts "Succeeded Build Operation" if DEBUG

					# Succeeded, so do the thing
					building_do_build_action(action, build_vars.removing, level, resources)

					# Remove/Add Costs
					if (!build_vars.removing)
						gamestate_update_currency(gamestate, build_vars.current_cost[:cost], build_vars.current_cost[:power_cost])
					else
						gamestate_update_currency(gamestate, -build_vars.current_cost[:cost], -build_vars.current_cost[:power_cost])
					end
				else
					puts "Cannot Afford Build Operation" if DEBUG

					build_vars.warning_text = "Cannot afford this build"
				end
			else
				puts "Failed Build Operation" if DEBUG

				# Failed, so buzz them
				build_vars.warning_text = "Cannot block access to tiles"
			end

			build_vars.select_start = nil
			build_vars.select_end = nil
			build_vars.removing = false
			build_vars.current_cost = nil
		end
	end

	# Update the warning text timer
	if (build_vars.warning_text != build_vars.warning_text_prev)
		build_vars.warning_timer = Gosu.milliseconds + 2000
		build_vars.warning_text_prev = build_vars.warning_text
	elsif (build_vars.warning_timer < Gosu.milliseconds)
		build_vars.warning_text = ""
		build_vars.warning_text_prev = ""
	end
end

def building_draw_cost_panel (power_cost, cost, resources, can_afford_power = true, can_afford_cost = true)
	font_name = resources.fonts["BULKYPIX16"].name
	currency = resources.sprites["currency"]
	power = resources.sprites["energy_full"]

	power_cost_text = "x#{power_cost / 2}" + ((power_cost % 2 > 0) ? ".5" : "")
	power_cost_img = Gosu::Image.from_text(power_cost_text, 16, options = { :font => font_name, :align => :left })

	cost_text = "#{cost}"
	cost_img = Gosu::Image.from_text(cost_text, 16, options = { :font => font_name, :align => :left })

	border = 3
	width = 5 + currency.image.width + 3 + [power_cost_img.width, cost_img.width].max + 5 + border * 2
	height = 5 + currency.image.height + 5 + border * 2

	if (power_cost != 0)
		height += currency.image.height + 5
	end

	return Gosu.render(width, height) {
		Gosu.draw_rect(0, 0, width, height, 0xff_2e2e2e, ZOrder::UI + 10)
		Gosu.draw_rect(border, border, width - border * 2, height - border * 2, 0xff_505050, ZOrder::UI + 10)

		# Draw Power Cost
		if (power_cost != 0)
			power.image.draw(border + 5, border + 5, ZOrder::UI + 10)
			color = (can_afford_power) ? 0xff_ffffff : 0xff_ff0000
			power_cost_img.draw(border + 5 + currency.image.width + 3, border + 7 + 5, ZOrder::UI + 10, 1, 1, color)
		end

		# Draw Money Cost
		currency.image.draw(border + 5, border + 5 + ((power_cost != 0) ? currency.image.height + 5 : 0), ZOrder::UI + 10)
		color = (can_afford_cost) ? 0xff_ffffff : 0xff_ff0000
		cost_img.draw(border + 5 + currency.image.width + 3, border + 7 + 5 + ((power_cost != 0) ? currency.image.height + 5 : 0), ZOrder::UI + 10, 1, 1, color)
	}
end

def building_draw_ui (build_vars, resources, gamestate, mouse_vector, render_offset)
	level = gamestate.level

	# Draw current selection
	if (build_vars.selecting_area && build_vars.select_start != nil)
		map_bounds = Vector2.new(level.width, level.height)
		start_point = build_vars.select_start.clamp(Vector2.zero, map_bounds)
		current_point = screen_to_world(mouse_vector, render_offset).clamp(Vector2.zero, map_bounds)

		start_point_screen = world_to_screen(start_point)
		current_point_screen = world_to_screen(current_point)

		if (DEBUG)
			Gosu.draw_line(start_point_screen.x, start_point_screen.y, 0xff_ff0000, current_point_screen.x, current_point_screen.y, 0xff_ff0000, ZOrder::UI)
		end

		# Draw appropriate selection (line or rect)
		case build_vars.operation
		when BuildingOperation::Fence
			building_draw_selection(start_point, current_point, build_vars.fence_x_first, build_vars.removing, resources)
		when BuildingOperation::Crop, BuildingOperation::Turret
			building_draw_selection(start_point, current_point, true, build_vars.removing, resources)
			building_draw_selection(start_point, current_point, false, build_vars.removing, resources)
		end

		# Draw Cost of build operation
		if (build_vars.current_cost != nil)
			power_cost = build_vars.current_cost[:power_cost]
			cost = build_vars.current_cost[:cost]

			can_afford_power = true
			can_afford_cost = true
			if (!build_vars.removing)
				can_afford_power = gamestate_can_afford?(gamestate, 0, power_cost)
				can_afford_cost = gamestate_can_afford?(gamestate, cost, 0)
			end

			panel = building_draw_cost_panel(power_cost, cost, resources, can_afford_power, can_afford_cost)
			draw_point = start_point_screen + (current_point_screen - start_point_screen) / 2
			panel.draw((draw_point.x - panel.width / 2).round, (draw_point.y - panel.height / 2).round, ZOrder::UI + 10)
		end
	end

	# Draw building UI
	Gosu.translate(-render_offset.x, -render_offset.y) {
		left = (WIN_WIDTH - 720) / 2
		right = WIN_WIDTH - left
		top = WIN_HEIGHT - 180
		bottom = WIN_HEIGHT

		build_vars.mouse_over_index = nil
		build_vars.mouse_over_start_round = false
		build_vars.mouse_over_power_upgrade = false

		Gosu.draw_rect(left, top, 720, 180, 0xff_2e2e2e, ZOrder::UI + 5)

		# Draw placables
		for i in 0...5
			index = (build_vars.scroll_index + i) % build_vars.build_catalogue.length

			rel_left = left + 10 + i * 140
			rel_top = top + 10
			rel_width = 137
			rel_height = 169

			font_name = resources.fonts["BULKYPIX16"].name
			buildable_name_img = Gosu::Image.from_text(build_vars.build_catalogue[index].name, 16, options = { :font => font_name, :align => :center, :width => rel_width })
			buildable_name_img.draw(rel_left, rel_top + 10, ZOrder::UI + 9)

			sprite_name = build_vars.build_catalogue[index].sprite
			sprite = resources.sprites[sprite_name]
			sprite.image.draw(rel_left + 68 - sprite.ox, rel_top + 96 - sprite.oy, ZOrder::UI + 8)
			Gosu.draw_rect(rel_left, rel_top, rel_width, rel_height, 0xff_505050, ZOrder::UI + 7)

			# If mouse over this pane, set mouse over index
			if (mouse_vector.x > rel_left && mouse_vector.x < rel_left + rel_width && mouse_vector.y > rel_top && mouse_vector.y < rel_top + rel_height)
				build_vars.mouse_over_index = index
			end
		end

		# Draw scrolling arrows ?

		# Draw Start Round Button
		Gosu.draw_rect(right, WIN_HEIGHT - 50, left, 50, 0xff_2e2e2e, ZOrder::UI + 5)	
		start_round_button = Gosu.render(left - 10, 50 - 10) {
			Gosu.draw_rect(5, 5, left - 10, 50 - 10, 0xff_505050, ZOrder::UI + 6)

			font_name = resources.fonts["BULKYPIX16"].name
			enemy_icon = resources.sprites["enemy_icon"]

			button_text = Gosu::Image.from_text("Start Round", 14, options = { :font => font_name, :align => :left })

			button_text_x = (5 + left - 10 - enemy_icon.image.width) / 2 - button_text.width / 2
			button_text.draw(button_text_x, 15, ZOrder::UI + 7)
			enemy_icon.image.draw(button_text_x + button_text.width, 7, ZOrder::UI + 7)
		}
		start_round_pos = Vector2.new(right + 5, WIN_HEIGHT - 50 + 5)
		start_round_button.draw(start_round_pos.x, start_round_pos.y, ZOrder::UI + 7)
		# If mouse over the start round button
		if (mouse_vector.x > start_round_pos.x && mouse_vector.x < start_round_pos.x + start_round_button.width && mouse_vector.y > start_round_pos.y && mouse_vector.y < start_round_pos.y + start_round_button.height)
			build_vars.mouse_over_start_round = true
		end

		# Draw Increase Power Button
		Gosu.draw_rect(0, WIN_HEIGHT - 50, left, 50, 0xff_2e2e2e, ZOrder::UI + 5)
		increase_power_button = Gosu.render(left - 10, 50 - 10) {
			Gosu.draw_rect(5, 3, left - 10, 50 - 10, 0xff_505050, ZOrder::UI + 6)

			font_name = resources.fonts["BULKYPIX16"].name
			currency = resources.sprites["currency"]
			power = resources.sprites["energy_full"]

			upgrade_cost = gamestate_power_upgrade_cost(gamestate)
			can_afford_update = gamestate_can_afford?(gamestate, upgrade_cost, 0)
			cost_color = (can_afford_update) ? 0xff_ffffff : 0xff_ff0000

			pre_text = Gosu::Image.from_text("Increase ", 14, options = { :font => font_name, :align => :left })
			mid_text = Gosu::Image.from_text(" for", 14, options = { :font => font_name, :align => :left })
			post_text = Gosu::Image.from_text(upgrade_cost, 14, options = { :font => font_name, :align => :left })

			pre_text.draw(10, 15, ZOrder::UI + 7)
			power.image.draw(10 + pre_text.width, 7, ZOrder::UI + 7)
			mid_text.draw(10 + pre_text.width + power.image.width, 15, ZOrder::UI + 7)
			currency.image.draw(10 + pre_text.width + power.image.width + mid_text.width, 7, ZOrder::UI + 7)
			post_text.draw(10 + pre_text.width + power.image.width + mid_text.width + currency.image.width, 15, ZOrder::UI + 7, 1, 1, cost_color)
		}
		increase_power_pos = Vector2.new(0, WIN_HEIGHT - 50 + 5)
		increase_power_button.draw(increase_power_pos.x, increase_power_pos.y, ZOrder::UI + 7)
		# If mouse over the increase power button
		if (mouse_vector.x > increase_power_pos.x && mouse_vector.x < increase_power_pos.x + increase_power_button.width && mouse_vector.y > increase_power_pos.y && mouse_vector.y < increase_power_pos.y + increase_power_button.height)
			build_vars.mouse_over_power_upgrade = true
		end

		# Draw Warning Text
		if (Gosu.milliseconds < build_vars.warning_timer)
			fadeout_duration = 500
			delta_time = build_vars.warning_timer - Gosu.milliseconds

			in_fadeout = (delta_time) < fadeout_duration
			alpha = (in_fadeout) ? lerp(255, 0, (fadeout_duration.to_f - delta_time.to_f) / fadeout_duration.to_f) : 255
			color = Gosu::Color.rgba(255, 0, 0, alpha)

			font_name = resources.fonts["BULKYPIX16"].name
			warning_text_img = Gosu::Image.from_text(build_vars.warning_text, 28, options = { :font => font_name, :align => :center, :width => WIN_WIDTH / 2 })
			warning_text_img.draw(WIN_WIDTH / 4, (WIN_HEIGHT / 2) - (warning_text_img.height / 2), ZOrder::UI + 10, 1, 1, color)
		end
	}
end

def building_fence_path (cornerA, cornerB, x_first)
	# Get points for each corner of the selection
	top_point = Vector2.min(cornerA, cornerB).round
	bot_point = Vector2.max(cornerA, cornerB).round
	left_point = Vector2.new(top_point.x, bot_point.y)
	right_point = Vector2.new(bot_point.x, top_point.y)

	range_x = top_point.x...bot_point.x
	range_y = top_point.y...bot_point.y

	# The set x and y are the ones that stay constant when drawing the opposite side
	set_x = (x_first) ? bot_point.x : top_point.x
	set_y = (x_first) ? top_point.y : bot_point.y

	cornerA_rounded = cornerA.round
	# Is the seletion being drawn horizontally? If so - we need to fix to go left to right (not up to down)
	if (cornerA_rounded != top_point && cornerA_rounded != bot_point)
		set_x = (x_first) ? left_point.x : right_point.x
		set_y = (x_first) ? right_point.y : left_point.y
	end

	# Return the borders
	return { :range_x => range_x, :range_y => range_y, :set_x => set_x, :set_y => set_y, :top_point => top_point, :bot_point => bot_point, :left_point => left_point, :right_point => right_point }
end

def building_draw_selection (cornerA, cornerB, x_first, removing, resources)
	# Setup drawing function
	select_ns = resources.sprites["select_line_NS"]
	select_ew = resources.sprites["select_line_EW"]
	draw_select_line = -> (x, y, ns) {
		pos = world_to_screen(Vector2.new(x, y))
		z_order = ZOrder::UI

		color = (removing) ? 0xff_ff0000 : 0xff_ffffff

		if (ns)
			select_ns.image.draw(pos.x - select_ns.ox, pos.y - select_ns.oy, z_order, 1, 1, color)
		else
			select_ew.image.draw(pos.x - select_ew.ox, pos.y - select_ew.oy, z_order, 1, 1, color)
		end
	}

	# Get the fence path in the correct direction
	fence_path = building_fence_path(cornerA, cornerB, x_first)

	for x in fence_path[:range_x]
		draw_select_line.call(x, fence_path[:set_y], false)
	end
	for y in fence_path[:range_y]
		draw_select_line.call(fence_path[:set_x], y, true)
	end

	# Debug lines red = drag, blue = top->bottom, green = left->right
	if (DEBUG)
		top_point = world_to_screen(fence_path[:top_point])
		bot_point = world_to_screen(fence_path[:bot_point])
		left_point = world_to_screen(fence_path[:left_point])
		right_point = world_to_screen(fence_path[:right_point])

		Gosu.draw_line(top_point.x, top_point.y, 0xff_0000ff, bot_point.x, bot_point.y, 0xff_ffffff, ZOrder::UI)
		Gosu.draw_line(left_point.x, left_point.y, 0xff_00ff00, right_point.x, right_point.y, 0xff_ffffff, ZOrder::UI)
	end
end

def building_do_build_action (build_action, removing, level, resources)
	# If we are not deleting and not doing fences - place turret/crop as needed
	if (!removing && build_action.operation != BuildingOperation::Fence)
		if (build_action.type == "tile")
			# For each new object
			build_action.data.each { |key, value|
				if (build_action.operation == BuildingOperation::Turret)
					level[key.x, key.y].type = TileType::Turret

					# Create new turret
					turret = resources.turrets[value].dup
					turret.position = Vector2.new(key.x, key.y)
					turret.dir = 2
					level.turrets.push(turret)

					level[key.x, key.y].reference = level.turrets.length - 1
				elsif (build_action.operation == BuildingOperation::Crop)
					level[key.x, key.y].type = TileType::Crop

					# Create new crop plot
					cropplot = resources.crops[value].dup
					cropplot.position = Vector2.new(key.x, key.y)
					cropplot.dir = rand(4)
					level.crops.push(cropplot)

					level[key.x, key.y].reference = level.crops.length - 1
				end
			}
		elsif (build_action.type == "rect" && build_action.data != nil)
			# REMOVED CROP RECTANGLE REQUIREMENT
			# Create new crop plot
			#cropplot = resources.crops[build_action.data[:crop_name]].dup
			#cropplot.dir = 0
			#cropplot.size = 0
			#level.crops.push(cropplot)

			## Assign each tile
			#top = build_action.data[:top]
			#bottom = build_action.data[:bottom]
			#for y in top.y...bottom.y
			#	for x in top.x...bottom.x
			#		level[x, y].type = TileType::Crop

			#		cropplot.size += 1

			#		level[x, y].reference = level.crops.length - 1
			#	end
			#end
		end
	# If building or removing fence
	elsif (build_action.operation == BuildingOperation::Fence)
		build_action.data.each { |key, value|
			level.fences[key] = value
		}
	# If removing crop/turret
	elsif (removing)
		top = build_action.data[:top]
		bottom = build_action.data[:bottom]
		for y in top.y...bottom.y
			for x in top.x...bottom.x
				if (level[x, y].type == TileType::Crop)
					level.crops[level[x, y].reference] = nil

					level[x, y].type = TileType::Empty
					level[x, y].ground_sprite = "empty"
					level[x, y].reference = nil
				elsif (level[x, y].type == TileType::Turret)
					level.turrets[level[x, y].reference] = nil

					level[x, y].type = TileType::Empty
					level[x, y].ground_sprite = "empty"
					level[x, y].reference = nil
				end	
			end
		end

		level_cleanup(level)
	end
end

def building_try_action (build_action, removing, level, resources)
	# Check for full level connectivity in the case that build action is completed
	success = true

	# If we are removing, we don't need to check connectivity
	if (!removing)
		# Note that ONLY the array is duplicated, not it's elements
		# Make occupancy grid [(true = can't walk, false = empty), (visited?)]
		test_tiles = level.tiles.map.with_index { |tile, i|
			{ :solid => [TileType::Base].include?(tile.type), :visited => false, :index => i }
		}

		# Fence array will duplicate elements because they are just booleans
		test_fences = level.fences.dup

		# Update with hypothetical build
		if (build_action.operation == BuildingOperation::Fence)
			build_action.data.each { |key, value|
				test_fences[key] = value
			}
		end
		
		# Breadth first search for connectivity check
		queue = []
		test_tiles[0][:visited] = true
		queue.push(test_tiles[0])
		while queue.length > 0
			v = queue.shift
			
			n = v[:index]
			x = n % level.width
			y = n / level.width

			fences = level_fences_n(n, level)
			neighbours = []

			# Check walkability to neighbours
			if (!test_fences[fences[:north]] && y > 0 && !test_tiles[n - level.width][:solid])
				neighbours.push(test_tiles[n - level.width])
			end
			if (!test_fences[fences[:south]] && y < level.height - 1 && !test_tiles[n + level.width][:solid])
				neighbours.push(test_tiles[n + level.width])
			end
			if (!test_fences[fences[:west]] && x > 0 && !test_tiles[n - 1][:solid])
				neighbours.push(test_tiles[n - 1])
			end
			if (!test_fences[fences[:east]] && x < level.width - 1 && !test_tiles[n + 1][:solid])
				neighbours.push(test_tiles[n + 1])
			end

			for i in 0...neighbours.length
				if (!neighbours[i][:visited])
					neighbours[i][:visited] = true
					queue.push(neighbours[i])
				end
			end
		end

		# Check for any non visited nodes
		for i in 0...test_tiles.length
			if (!test_tiles[i][:visited] && !test_tiles[i][:solid])
				puts "Did not reach tile #{i}" if DEBUG
				success = false
			end
		end
	end

	return success
end

def building_get_cost_of_build (build_action, removing, level, resources)
	power_cost = 0
	cost = 0

	recoup = 0.3
	fence_cost = 100

	if (!removing && build_action.operation == BuildingOperation::Turret)
		# Calculate cost of turrets
		build_action.data.each { |key, value|
			turret = resources.turrets[value]
			power_cost += turret.power_cost
			cost += turret.cost
		}
	elsif (!removing && build_action.operation == BuildingOperation::Crop)
		# Calculate cost of crops
		build_action.data.each { |key, value|
			crop = resources.crops[value]
			cost += crop.cost
		}
	elsif (build_action.operation == BuildingOperation::Fence)
		# Calculate cost of fence
		build_action.data.each { |key, value|
			# Only increment cost if we are building, or are removing where a fence exists
			if (!removing || (removing && level.fences[key]))
				cost += fence_cost
			end
		}
	elsif (removing)
		# Calculate cost to buy the removing tiles - will convert to remove price later
		top = build_action.data[:top]
		bottom = build_action.data[:bottom]
		for y in top.y...bottom.y
			for x in top.x...bottom.x
				if (level[x, y].type == TileType::Crop)
					crop = level.crops[level[x, y].reference]
					if (crop != nil)
						cost += crop.cost
					end
				elsif (level[x, y].type == TileType::Turret)
					turret = level.turrets[level[x, y].reference]
					if (turret != nil)
						power_cost += turret.power_cost
						cost += turret.cost
					end
				end	
			end
		end
	end

	# If we are destroying stuff, recoup some of the cost
	if (removing)
		cost *= recoup
	end

	cost = cost.floor

	return { :cost => cost, :power_cost => power_cost }
end