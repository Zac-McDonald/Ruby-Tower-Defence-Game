class PotentialField
	attr_reader :width, :height
	attr_accessor :tiles

	def initialize (width, height, default_value = 0)
		@width = width
		@height = height
		@tiles = Array.new(width * height) { default_value }
	end

	def [](x, y)
		if (x < 0 || y < 0 || x >= @width || y >= @height)
			raise RangeError, "Field index [#{x},#{y}] is out of bounds"
			return nil
		else
			return @tiles[x + y * @height]
		end
	end

	def []=(x, y, value)
		if (x < 0 || y < 0 || x >= @width || y >= @height)
			raise RangeError, "Field index [#{x},#{y}] is out of bounds"
			return nil
		else
			@tiles[x + y * @height] = value
		end
	end

	def +(b)
		if (b.width != self.width || b.height != self.height)
			raise RangeError, "Field dimension missmatch, cannot add"
			return nil
		end

		result = PotentialField.new(self.width, self.height)
		for i in 0...self.tiles.length
			result.tiles[i] = self.tiles[i] + b.tiles[i]
		end

		return result
	end

	def -(b)
		if (b.width != self.width || b.height != self.height)
			raise RangeError, "Field dimension missmatch, cannot subtract"
			return nil
		end

		result = PotentialField.new(self.width, self.height)
		for i in 0...self.tiles.length
			result.tiles[i] = self.tiles[i] - b.tiles[i]
		end

		return result
	end
end