# Sourced from https://gist.github.com/gre/1650294

def lerp (a, b, t)
	return (1 - t) * a + t * b
end

def ease_linear (t)
	return t
end

def ease_in_quad (t)
	return t * t
end

def ease_out_quad (t)
	return t * (2 - t)
end

def ease_inout_quad (t)
	return (t < 0.5) ? 2 * t * t : -1 + (4 - 2 * t) * t
end