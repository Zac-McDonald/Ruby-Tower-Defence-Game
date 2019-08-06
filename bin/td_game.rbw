# Main execute to run the Tower Defence Game

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'td_game'

GameWindow.new.show