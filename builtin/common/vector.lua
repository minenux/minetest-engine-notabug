
vector = {}

-- Cache math functions in locals
local vector = vector
local math_sin = math.sin
local math_cos = math.cos
local math_asin = math.asin
local math_atan2 = math.atan2
local math_pi = math.pi
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_hypot = math.hypot
assert(math_hypot, "Wrong loading order")

function vector.new(a, b, c)
	if type(a) == "table" then
		assert(a.x and a.y and a.z, "Invalid vector passed to vector.new()")
		return {x=a.x, y=a.y, z=a.z}
	elseif a then
		assert(b and c, "Invalid arguments for vector.new()")
		return {x=a, y=b, z=c}
	end
	return {x=0, y=0, z=0}
end

function vector.equals(a, b)
	return a.x == b.x and
	       a.y == b.y and
	       a.z == b.z
end

function vector.length(v)
	return math_hypot(v.x, math_hypot(v.y, v.z))
end

function vector.normalize(v)
	local len = vector.length(v)
	if len == 0 then
		return {x=0, y=0, z=0}
	else
		return vector.divide(v, len)
	end
end

function vector.floor(v)
	return {
		x = math_floor(v.x),
		y = math_floor(v.y),
		z = math_floor(v.z)
	}
end

function vector.round(v)
	return {
		x = math_floor(v.x + 0.5),
		y = math_floor(v.y + 0.5),
		z = math_floor(v.z + 0.5)
	}
end

function vector.apply(v, func)
	return {
		x = func(v.x),
		y = func(v.y),
		z = func(v.z)
	}
end

function vector.distance(a, b)
	local x = a.x - b.x
	local y = a.y - b.y
	local z = a.z - b.z
	return math_hypot(x, math_hypot(y, z))
end

function vector.direction(pos1, pos2)
	return vector.normalize({
		x = pos2.x - pos1.x,
		y = pos2.y - pos1.y,
		z = pos2.z - pos1.z
	})
end

function vector.angle(a, b)
	local dotp = vector.dot(a, b)
	local cp = vector.cross(a, b)
	local crossplen = vector.length(cp)
	return math_atan2(crossplen, dotp)
end

function vector.dot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z
end

function vector.cross(a, b)
	return {
		x = a.y * b.z - a.z * b.y,
		y = a.z * b.x - a.x * b.z,
		z = a.x * b.y - a.y * b.x
	}
end

function vector.add(a, b)
	if type(b) == "table" then
		return {x = a.x + b.x,
			y = a.y + b.y,
			z = a.z + b.z}
	else
		return {x = a.x + b,
			y = a.y + b,
			z = a.z + b}
	end
end

function vector.subtract(a, b)
	if type(b) == "table" then
		return {x = a.x - b.x,
			y = a.y - b.y,
			z = a.z - b.z}
	else
		return {x = a.x - b,
			y = a.y - b,
			z = a.z - b}
	end
end

function vector.multiply(a, b)
	if type(b) == "table" then
		return {x = a.x * b.x,
			y = a.y * b.y,
			z = a.z * b.z}
	else
		return {x = a.x * b,
			y = a.y * b,
			z = a.z * b}
	end
end

function vector.divide(a, b)
	if type(b) == "table" then
		return {x = a.x / b.x,
			y = a.y / b.y,
			z = a.z / b.z}
	else
		return {x = a.x / b,
			y = a.y / b,
			z = a.z / b}
	end
end

function vector.sort(a, b)
	return {x = math.min(a.x, b.x), y = math.min(a.y, b.y), z = math.min(a.z, b.z)},
		{x = math.max(a.x, b.x), y = math.max(a.y, b.y), z = math.max(a.z, b.z)}
end

local function sin(x)
	if x % math_pi == 0 then
		return 0
	else
		return math_sin(x)
	end
end

local function cos(x)
	if x % math_pi == math_pi / 2 then
		return 0
	else
		return math_cos(x)
	end
end

function vector.rotate_around_axis(v, axis, angle)
	local cosangle = cos(angle)
	local sinangle = sin(angle)
	axis = vector.normalize(axis)
	-- https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula
	local dot_axis = vector.multiply(axis, vector.dot(axis, v))
	local cross = vector.cross(v, axis)
	return vector.new(
		cross.x * sinangle + (v.x - dot_axis.x) * cosangle + dot_axis.x,
		cross.y * sinangle + (v.y - dot_axis.y) * cosangle + dot_axis.y,
		cross.z * sinangle + (v.z - dot_axis.z) * cosangle + dot_axis.z
	)
end

function vector.rotate(v, rot)
	local sinpitch = sin(-rot.x)
	local sinyaw = sin(-rot.y)
	local sinroll = sin(-rot.z)
	local cospitch = cos(rot.x)
	local cosyaw = cos(rot.y)
	local cosroll = cos(rot.z)
	-- Rotation matrix that applies yaw, pitch and roll
	local matrix = {
		{
			sinyaw * sinpitch * sinroll + cosyaw * cosroll,
			sinyaw * sinpitch * cosroll - cosyaw * sinroll,
			sinyaw * cospitch,
		},
		{
			cospitch * sinroll,
			cospitch * cosroll,
			-sinpitch,
		},
		{
			cosyaw * sinpitch * sinroll - sinyaw * cosroll,
			cosyaw * sinpitch * cosroll + sinyaw * sinroll,
			cosyaw * cospitch,
		},
	}
	-- Compute matrix multiplication: `matrix` * `v`
	return vector.new(
		matrix[1][1] * v.x + matrix[1][2] * v.y + matrix[1][3] * v.z,
		matrix[2][1] * v.x + matrix[2][2] * v.y + matrix[2][3] * v.z,
		matrix[3][1] * v.x + matrix[3][2] * v.y + matrix[3][3] * v.z
	)
end

-- dir_to_rotation implementation

-- Excerpt from PR #8515, converted to specify the matrix as multiple args.
local function m3arg_to_pitch_yaw_roll(m11, m12, m13, m21, m22, m23, m31, m32, m33)
	local y = math_atan2(-m13, m33)
	local c2 = math_sqrt(m21^2 + m22^2)
	local x = math_atan2(m23, c2)
	local s1 = math_sin(y)
	local c1 = math_cos(y)
	local z = math_atan2(s1 * m32 + c1 * m12, s1 * m31 + c1 * m11)
	return x, y, z
end

-- Cross product with one argument per component.
local function v3arg_cross(x1, y1, z1, x2, y2, z2)
	return y1*z2 - z1*y2, z1*x2 - x1*z2, x1*y2 - y1*x2
end

-- Normalization with one argument per component, returning length.
local function v3arg_normalize(x, y, z)
	local len = math_hypot(x, math_hypot(y, z))
	return x / len, y / len, z / len, len
end

function vector.dir_to_rotation(forward, up)
	-- Normalize forward, defaulting to 0,0,1.
	local fx, fy, fz, len = v3arg_normalize(forward.x, forward.y, forward.z)
	if len == 0 then
		-- Zero length
		fx, fy, fz = 0, 0, 1
	end

	if not up then
		return {x = math_asin(fy), y = -math_atan2(fx, fz), z = 0}
	end
	local ux, uy, uz = up.x, up.y, up.z

	-- Synthesize a right vector via cross product of up and forward.
	local rx, ry, rz = v3arg_cross(ux, uy, uz, fx, fy, fz)

	-- Normalize right, defaulting to 1,0,0.
	rx, ry, rz, len = v3arg_normalize(rx, ry, rz)
	if len == 0 then
		-- Zero length
		rx, ry, rz = 1, 0, 0
	end

	-- Calculate a new up vector as cross product of forward and right.
	-- The resulting up vector is guaranteed to be normalized.
	ux, uy, uz = v3arg_cross(fx, fy, fz,  rx, ry, rz)

	-- We have an orthogonal matrix now; convert it to Euler.
	local x, y, z = m3arg_to_pitch_yaw_roll(rx, ux, fx, ry, uy, fy, rz, uz, fz)
	return {x = x, y = y, z = z}
end
