WIN_WIDTH = 1280
WIN_HEIGHT = 800

DEBUG = false || ARGV.include?("DEBUG") || ARGV.include?("debug")

module TileType
	Empty, Restricted, Base, Crop, Turret, Disabled, Spawn = *(0...7)
end

module ZOrder
	Background = 0.0
	Ground = 100.0
	Objects = 5000.0
	UI = 10000.0
end

def screen_to_world (pos, render_offset)
	pos = pos - render_offset

	world_x = (pos.x / 64 + pos.y / 32) / 2
	world_y = (pos.y / 32 - pos.x / 64) / 2

	return Vector2.new(world_x, world_y)
end

def world_to_screen (pos)
	screen_x = (pos.x - pos.y) * 64
	screen_y = (pos.x + pos.y) * 32

	return Vector2.new(screen_x, screen_y)
end