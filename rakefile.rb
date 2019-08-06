require 'rubygems'
require 'releasy'

Releasy::Project.new do
	name "Tower Defence Game - Zac McDonald"
	version "0.1"

	executable "./bin/td_game.rbw"
	files ['./bin/*', './lib/*', './resources/*']
	files.exclude './rakefile.rb'

	exposed_files []
	
	add_build :windows_folder do
		executable_type :windows
		add_package :exe
	end
end