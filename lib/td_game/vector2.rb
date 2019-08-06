class Vector2
	attr_accessor :x, :y

	def initialize (x, y)
		@x = x
		@y = y
	end

	def self.zero ()
		return Vector2.new(0,0)
	end

	def self.one ()
		return Vector2.new(1,1)
	end

	def self.max (a, b)
		return Vector2.new([a.x, b.x].max, [a.y, b.y].max)
	end

	def self.min (a, b)
		return Vector2.new([a.x, b.x].min, [a.y, b.y].min)
	end

	def floor ()
		return Vector2.new(self.x.floor, self.y.floor)
	end

	def ceil ()
		return Vector2.new(self.x.ceil, self.y.ceil)
	end

	def round ()
		return Vector2.new(self.x.round, self.y.round)
	end

	def clamp (min, max)
		return Vector2.new(self.x.clamp(min.x, max.x), self.y.clamp(min.y, max.y))
	end

	def self.angle (a, b)
		angle = Math.acos(Vector2.dot(a, b) / (a.magnitude * b.magnitude))
	end

	def self.dot (a, b)
		return (a.x * b.x + a.y * b.y)
	end

	def self.manhatten_distance (a, b)
		c = a - b
		return c.x.abs + c.y.abs
	end

	def self.square_distance (a, b)
		return (a - b).square_magnitude
	end

	def self.distance (a, b)
		return Math.sqrt(self.square_distance(a, b))
	end

	def normalise ()
		return (Vector2.new(self.x, self.y) * (1.0 / self.magnitude)).round
	end

	def set_magnitude (mag)
		return (self.normalise * mag)
	end

	def square_magnitude ()
		return (self.x * self.x) + (self.y * self.y)
	end

	def magnitude ()
		return Math.sqrt(self.square_magnitude)
	end

	def +(b)
		return Vector2.new(self.x + b.x, self.y + b.y)
	end

	def -(b)
		return Vector2.new(self.x - b.x, self.y - b.y)
	end

	def *(s)
		return Vector2.new(s * self.x, s * self.y)
	end

	def /(s)
		return Vector2.new(self.x / s, self.y / s)
	end

	def ==(other)
		return (other != nil && self.x == other.x && self.y == other.y)
	end
end