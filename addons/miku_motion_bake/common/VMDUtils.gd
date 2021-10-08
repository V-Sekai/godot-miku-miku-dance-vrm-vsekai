class_name VMDUtilsBake

static func sj2utf(input: PoolByteArray) -> PoolByteArray:
	var output = PoolByteArray()
	output.resize(input.size()*3)
	
	var index_input = 0
	var index_output = 0
	
	while index_input < input.size():
		var array_section = input[index_input] >> 4
		
		var array_offset
		if array_section == 0x8:
			array_offset = 0x100
		elif array_section == 0x9:
			array_offset = 0x1100
		elif array_section == 0xE:
			array_offset = 0x2100
		else:
			array_offset = 0
		
		if array_offset:
			array_offset += (input[index_input] & 0xF) << 8
			index_input += 1
			if index_input >= input.size():
				break
		
		array_offset += input[index_input]
		index_input += 1
		array_offset = array_offset << 1
		
		var unicode_value = (ShiftJISTableBake.conv_table[array_offset] << 8) | ShiftJISTableBake.conv_table[array_offset + 1]

		if unicode_value < 0x80:
			output[index_output] = unicode_value
			index_output += 1
		elif unicode_value < 0x800:
			output[index_output] = 0xC0 | (unicode_value >> 6)
			index_output += 1
			output[index_output] = 0x80 | (unicode_value & 0x3F)
			index_output += 1
		else:
			output[index_output] = 0xE0 | (unicode_value >> 12)
			index_output += 1
			output[index_output] = 0x80 | ((unicode_value & 0xFFF) >> 6)
			index_output += 1
			output[index_output] = 0x80 | (unicode_value & 0x3F)
			index_output += 1
	output.resize(index_output)
	return output

static func trim_end(source: PoolByteArray, to_trim: int) -> PoolByteArray:
	if source.size() > 0:
		if source[source.size()-1] == to_trim:
			source.remove(source.size() - 1)
	return source
	
const MAX_31B = 1 << 31
const MAX_32B = 1 << 32
	
static func unsigned32_to_signed(unsigned):
	return (unsigned + MAX_31B) % MAX_32B - MAX_31B

class BezierInterpolator:
	var X0: float
	var Y0: float
	var X1: float
	var Y1: float
	
	func inv_lerp(a: float, b: float, x: float) -> float:
		x = inverse_lerp(a, b, x)
		var t: float = 0.5
		
		var p = 0.25
		
		while p > 1e-6:
			t -= p * sign(t*(3*(1-t)*(X0 + t*(X1-X0)) + t*t) - x)
			p *= 0.5
		return t*(3*(1-t)*(Y0 + t*(Y1-Y0)) + t*t)
	
	func is_linear() -> bool:
		return X0 == Y0 and X1 == Y1
		
	func _to_string() -> String:
		return str(Quat(X0, Y0, X1, Y1))

static func read_string(file: File, length: int) -> String:
	var string = file.get_buffer(length)
	string = sj2utf(string)
	string = trim_end(string, 0x00)
	string = trim_end(string, ord("?"))
	string = trim_end(string, 0x00)
	return string.get_string_from_utf8()
	
static func read_vector3(file: File) -> Vector3:
	var x = file.get_float()
	var y = file.get_float()
	var z = file.get_float()
	return Vector3(x, y, z)

static func read_quat(file: File) -> Quat:
	var x = file.get_float()
	var y = file.get_float()
	var z = file.get_float()
	var w = file.get_float()
	return Quat(x, y, z, w)

static func read_bezier(file: File, stride: int) -> BezierInterpolator:
	var binterp = BezierInterpolator.new()
	binterp.X0 = file.get_buffer(stride)[0]/127.0
	binterp.Y0 = file.get_buffer(stride)[0]/127.0
	binterp.X1 = file.get_buffer(stride)[0]/127.0
	binterp.Y1 = file.get_buffer(stride)[0]/127.0
	return binterp

# Camera frames bezier order is XXYY instead of XYXY
static func read_bezier_camera(file: File, stride: int) -> BezierInterpolator:
	var binterp = BezierInterpolator.new()
	binterp.X0 = file.get_buffer(stride)[0]/127.0
	binterp.X1 = file.get_buffer(stride)[0]/127.0
	binterp.Y0 = file.get_buffer(stride)[0]/127.0
	binterp.Y1 = file.get_buffer(stride)[0]/127.0
	return binterp

static func binary_split(list: Array, pred: FuncRef) -> Dictionary:
	var i = 0
	var j = list.size()
	while i < j:
		var k = (i+j)/2
		if pred.call_func(list[k]):
			j = k
		else:
			i = k + 1
	var result = {}
	
	if i < list.size():
		result["first_true"] = list[i]
	if i > 0:
		result["last_false"] = list[i-1]
	return result
		
static func get_bone_global_rest(skel: Skeleton, bone_i: int) -> Transform:
	if bone_i == -1:
		return Transform()
	var final_transform := skel.get_bone_rest(bone_i)
	var bone_parent = skel.get_bone_parent(bone_i)
	while bone_parent != -1:
		final_transform = skel.get_bone_rest(bone_parent) * final_transform
		bone_parent = skel.get_bone_parent(bone_parent)
	return final_transform

