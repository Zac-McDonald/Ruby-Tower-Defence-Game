# Load common requirements - specific requirements in other files
require 'rubygems'
require 'gosu'
require 'json'

# Set working directory to project dir so we can run from anywhere
Dir.chdir(File.expand_path("../..", __FILE__))

# Require Game Files
$LOAD_PATH.unshift File.expand_path("..", __FILE__)
require 'td_game/vector2'
require 'td_game/potential_field'
require 'td_game/easing'

require 'td_game/constants'
require 'td_game/resources'

require 'td_game/cropplot'
require 'td_game/turret'
require 'td_game/enemy'
require 'td_game/level'

require 'td_game/gamestate'
require 'td_game/building'
require 'td_game/simulation'

require 'td_game/window'