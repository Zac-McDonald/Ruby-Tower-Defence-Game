class GameWindow < Gosu::Window
	def initialize
		super(WIN_WIDTH, WIN_HEIGHT, false)
		self.caption = "Tower Defence Game - Zac McDonald"

		@resources = Resources.new()

		level_name = @resources.maps.keys.sample
		level = level_from_map(@resources.maps[level_name])
		@game_state = GameState.new(level, GamePhase::Building)

		@build_vars = BuildVariables.new(@resources)
		@sim_vars = SimulationVariables.new(@game_state)

		@camera_move_amount = 2
		@camera_pos = Vector2.new(0,0)
		@render_offset = Vector2.zero

		@mouse_vector = Vector2.zero
		@mouse_vector_world = Vector2.zero
	end

	def needs_cursor?
		true
	end

	def fullscreen?
		false
	end

	def update
		@render_offset = Vector2.new(-@camera_pos.x + (WIN_WIDTH / 2), -@camera_pos.y)
		@mouse_vector = Vector2.new(mouse_x, mouse_y)
		@mouse_vector_world = screen_to_world(@mouse_vector, @render_offset)

		case @game_state.phase
		when GamePhase::Menu
			#
		when GamePhase::Tutorial
			#
		when GamePhase::Building
			building_update(@build_vars, @game_state, @resources, @mouse_vector_world)
		when GamePhase::Simulation
			simulation_update(@game_state, @sim_vars, @resources)
		end

		gamestate_update(@game_state, @sim_vars, @resources, @mouse_vector)
	end

	def draw
		Gosu.translate(@render_offset.x, @render_offset.y) {
			level_draw(@game_state.level, @resources)

			case @game_state.phase
			when GamePhase::Menu
				#
			when GamePhase::Tutorial
				#
			when GamePhase::Building
				building_draw_ui(@build_vars, @resources, @game_state, @mouse_vector, @render_offset)
			when GamePhase::Simulation
				#
			end

			gamestate_draw(@game_state, @resources, @mouse_vector, @render_offset)
		}
	end

	def button_down (id)
		move = Vector2.new(0,0)

		move.y = (id == Gosu::KbUp) ? -1 : (id == Gosu::KbDown) ? 1 : 0
		move.x = (id == Gosu::KbLeft) ? -1 : (id == Gosu::KbRight) ? 1 : 0

		move_camera(move)

		case @game_state.phase
		when GamePhase::Menu
			#
		when GamePhase::Tutorial
			#
		when GamePhase::Building
			building_button_down(@build_vars, id, @mouse_vector_world, @game_state)
		when GamePhase::Simulation
			#
		end
	end

	def button_up (id)
		case @game_state.phase
		when GamePhase::Menu
			#
		when GamePhase::Tutorial
			#
		when GamePhase::Building
			building_button_up(@build_vars, id, @mouse_vector_world)
		when GamePhase::Simulation
			#
		end
	end

	def drop (filename)
		# Called when a file is dropped on the window
	end

	def close
		# If this function is defined, the windows exit button won't work
		exit()
	end

	def move_camera (move)
		new_camera_pos = @camera_pos.dup

		# Move on World Coord
		new_camera_pos.x += move.x * 64 * @camera_move_amount - move.y * 64 * @camera_move_amount
		new_camera_pos.y += move.y * 64 * @camera_move_amount / 2 + move.x * 64 * @camera_move_amount / 2

		# Clamp top corner to not go out-of-bounds
		new_top_corner = screen_to_world(new_camera_pos, Vector2.zero)
		min_top_corner = Vector2.new(-6, -6)
		max_top_corner = Vector2.new(@game_state.level.width - 6, @game_state.level.height - 6)

		new_top_corner = new_top_corner.clamp(min_top_corner, max_top_corner)
		@camera_pos = world_to_screen(new_top_corner)
	end
end