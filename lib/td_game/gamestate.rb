module GamePhase
	Menu, Tutorial, Building, Simulation = *(0...4)
end

class GameState
	attr_accessor :level, :phase, :enemies, :money, :power_max, :power_used, :base_health_max, :base_health, :round, :gameover, :round_started, :enemy_tokens, :lasers

	def initialize (level, phase, enemies = [], money = 2000, power_max = 8, power_used = 0, base_health_max = 26, base_health = 26, round = 0, enemy_tokens = 0)
		@level = level
		@phase = phase
		@enemies = enemies

		@money = money
		@power_max = power_max
		@power_used = power_used

		@base_health_max = base_health_max
		@base_health = base_health

		@round = round
		@gameover = false
		@round_started = false
		@enemy_tokens = enemy_tokens

		@lasers = []
	end
end

def gamestate_update (gamestate, sim_vars, resources, mouse_vector)
	if (gamestate.base_health <= 0)
		gamestate.gameover = true
	end

	gamestate.level.crops.each.with_index { |crop, i|
		if (crop.health <= 0)
			pos = crop.position
			gamestate.level.crops[i] = nil
			simulation_disable_tile(pos.x.to_i + pos.y.to_i * gamestate.level.width, gamestate, resources)
		end
	}

	gamestate.level.turrets.each.with_index { |turret, i|
		turret_ai_tick(turret, gamestate)

		if (turret.health <= 0)
			pos = turret.position
			gamestate_update_currency(gamestate, 0, turret.power_cost)
			gamestate.level.turrets[i] = nil
			simulation_disable_tile(pos.x.to_i + pos.y.to_i * gamestate.level.width, gamestate, resources)
		end
	}

	gamestate.enemies.each.with_index { |enemy, i|
		enemy_ai_tick(enemy, gamestate, sim_vars, resources)

		if (enemy.health <= 0)
			gamestate.enemies[i] = nil
		end
	}

	gamestate.enemies.compact!
end

def gamestate_draw (gamestate, resources, mouse_vector, render_offset)
	gamestate_draw_ui(gamestate, resources, mouse_vector, render_offset)

	# Draw enemy entities
	gamestate.enemies.each { |enemy|
		enemy_screen_pos = world_to_screen(enemy.position).round
		enemy_tile_pos_screen = world_to_screen(enemy.tile_position)
		enemy_velocity_screen = world_to_screen(enemy.position + enemy.velocity*60).round

		z_order = ZOrder::Objects + enemy.position.x.floor + enemy.position.y.floor + 1.5
		
		if (enemy.animator != nil)
			sprite = animator_get_frame(enemy.animator)
			sprite.image.draw(enemy_screen_pos.x - sprite.ox, enemy_screen_pos.y - sprite.oy, z_order)

			if (DEBUG)
				Gosu.draw_rect(enemy_screen_pos.x, enemy_screen_pos.y, 10, 10, 0xff_ff0000, z_order)
				Gosu.draw_rect(enemy_tile_pos_screen.x, enemy_tile_pos_screen.y, 10, 10, 0xff_0000ff, z_order)
				Gosu.draw_line(enemy_screen_pos.x, enemy_screen_pos.y, 0xff_00ff00, enemy_velocity_screen.x, enemy_velocity_screen.y, 0xff_ffffff, ZOrder::UI)
			end
		end
	}

	# Draw laser entities
	gamestate.lasers.each.with_index { |laser, i|
		laser_start = world_to_screen(laser[:start]).round
		laser_end = world_to_screen(laser[:end]).round
		laser_spawn_time = laser[:time]

		laser_lifetime = 100
		# Destroy the laser after a time
		if (Gosu.milliseconds > laser_spawn_time + 100)
			gamestate.lasers[i] = nil
		# If not destroying, render the laser
		else
			# Replace with a stretched texture later (additive?)
			Gosu.draw_line(laser_start.x, laser_start.y, 0xff_ff0000, laser_end.x, laser_end.y, 0xff_ffffff, ZOrder::UI)
		end
	}

	gamestate.lasers.compact!
end

def gamestate_draw_bar (top_left, top_right, max_value, current_value, sprite_full, sprite_half, sprite_empty)
	offset = Vector2.new(10, 10)
	spacing_x = 2
	spacing_y = 2

	draw_bar = -> (sprite) {
		draw_pos = top_left + offset
		if (draw_pos.x + sprite_full.image.width > top_right.x)
			offset.x = 10
			offset.y += spacing_y + sprite_full.image.height
			draw_pos = top_left + offset
		end

		sprite.image.draw(draw_pos.x, draw_pos.y, ZOrder::UI + 10)
		offset.x += spacing_x + sprite_full.image.width
	}

	for i in 0...(current_value / 2)
		draw_bar.call(sprite_full)
	end
	for i in 0...(current_value % 2)
		draw_bar.call(sprite_half)
	end
	for i in 0...((max_value - current_value) / 2)
		draw_bar.call(sprite_empty)
	end
end

def gamestate_draw_ui (gamestate, resources, mouse_vector, render_offset)
	Gosu.translate(-render_offset.x, -render_offset.y) {
		top_left = Vector2.zero
		top_right = Vector2.new(WIN_WIDTH, 0)

		top_first_third = (top_right * 0.333).round
		top_second_third = (top_right * 0.666).round

		font_name = resources.fonts["BULKYPIX16"].name

		# Draw Power
		power_full = resources.sprites["energy_full"]
		power_half = resources.sprites["energy_half"]
		power_empty = resources.sprites["energy_empty"]

		gamestate_draw_bar(top_left, top_first_third, gamestate.power_max, gamestate.power_max - gamestate.power_used, power_full, power_half, power_empty)

		# Draw Health
		# Draw only base HP, draw entities as "heart x n"
		heart_full = resources.sprites["heart_full"]
		heart_half = resources.sprites["heart_half"]
		heart_empty = resources.sprites["heart_empty"]

		gamestate_draw_bar(top_first_third, top_second_third, gamestate.base_health_max, gamestate.base_health, heart_full, heart_half, heart_empty)

		# Draw Money
		currency = resources.sprites["currency"]

		money_text = Gosu::Image.from_text(gamestate.money, 18, options = { :font => font_name, :align => :left })
		money_text.draw(top_right.x - 10 - money_text.width, 12, ZOrder::UI + 10)
		currency.image.draw(top_right.x - 10 - money_text.width - currency.image.width, 5, ZOrder::UI + 10)

		# Draw Game Over
		if (gamestate.gameover)
			gameover_text = Gosu::Image.from_text("Game Over", 96, options = { :font => font_name, :align => :center })
			gameover_text.draw((WIN_WIDTH / 2) - (gameover_text.width / 2), (WIN_HEIGHT / 2) - (gameover_text.height / 2), ZOrder::UI + 10, 1, 1, 0xff_ff0000)
		
			rounds_survived = "You survived #{gamestate.round} rounds"
			round_text = Gosu::Image.from_text(rounds_survived, 36, options = { :font => font_name, :align => :center })
			round_text.draw((WIN_WIDTH / 2) - (round_text.width / 2), (WIN_HEIGHT / 2) - (round_text.height / 2) + (gameover_text.height / 2) + 50, ZOrder::UI + 10, 1, 1, 0xff_ff0000)
		end
	}
end

def gamestate_can_afford? (gamestate, cost, power_cost)
	return (gamestate.money >= cost && gamestate.power_used + power_cost <= gamestate.power_max)
end

def gamestate_update_currency (gamestate, cost, power_cost)
	gamestate.money -= cost
	gamestate.power_used += power_cost
end

def gamestate_power_upgrade_cost (gamestate)
	x = gamestate.power_max - 8
	return ((1.1**x) * 1000).round(-2)
end

def gamestate_upgrade_power (gamestate, power_upgrade)
	gamestate.power_max += power_upgrade
end

def gamestate_do_crop_growth (gamestate)
	for i in 0...gamestate.level.crops.length
		crop = gamestate.level.crops[i]
		crop.rounds_until_harvest -= 1

		# If we just reset growth time - harvest the crop
		if (crop.rounds_until_harvest == 0)
			gamestate.money += crop.harvest
			crop.rounds_until_harvest = crop.growth_time
		end
	end
end

def gamestate_get_enemy_tokens (round_num)
	x = round_num - 1
	return (1/5.0 * x.pow(2) + 10).ceil
end

def gamestate_damage_base (gamestate, damage)
	gamestate.base_health -= damage

	if (gamestate.base_health < 0)
		gamestate.base_health = 0
	end
end

def gamestate_damage_crop (gamestate, damage, crop_index)
	gamestate.level.crops[crop_index].health -= damage

	if (gamestate.level.crops[crop_index].health < 0)
		gamestate.level.crops[crop_index].health = 0
	end
end

def gamestate_damage_turret (gamestate, damage, turret_index)
	gamestate.level.turrets[turret_index].health -= damage

	if (gamestate.level.turrets[turret_index].health < 0)
		gamestate.level.turrets[turret_index].health = 0
	end
end

def gamestate_damage_enemy (gamestate, damage, enemy_index)
	gamestate.enemies[enemy_index].health -= damage

	if (gamestate.enemies[enemy_index].health < 0)
		gamestate.enemies[enemy_index].health = 0
	end
end