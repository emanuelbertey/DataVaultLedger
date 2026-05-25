extends Node

func _ready():
	# --- CONFIGURACIÓN ---
	var batch_size = 1
	var in_features = 1024
	var out_features = 1024
	var activation = 1
	var has_bias = 1
	var rounds = 10
	var iterations = 10

	print("--- PRUEBA 2: 16 BITS (FP16) - Estabilidad ---")
	print("Config: %d in -> %d out, Batch: %d\n" % [in_features, out_features, batch_size])

	var rd = RenderingServer.create_local_rendering_device()
	if not rd:
		print("ERROR: No se pudo crear el Rendering Device.")
		return

	# --- CARGAR SHADER ---
	var shader_file = load("res://linear_layer_16.glsl")
	var shader_spirv = shader_file.get_spirv()
	var shader = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		print("ERROR: Shader 16-bit no soportado o inválido: ", shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
		return

	# --- PREPARAR DATOS (CONVERSIÓN A 16 BITS) ---
	print("Convirtiendo datos a FP16... (Esto puede tardar unos segundos en CPU)")
	
	var x_f16 = _f32_to_f16_bytes(_gen_rand_array(batch_size * in_features))
	var w_f16 = _f32_to_f16_bytes(_gen_rand_array(out_features * in_features))
	var b_f16 = _f32_to_f16_bytes(_gen_rand_array(out_features))

	var x_buffer = rd.storage_buffer_create(x_f16.size(), x_f16)
	var w_buffer = rd.storage_buffer_create(w_f16.size(), w_f16)
	var b_buffer = rd.storage_buffer_create(b_f16.size(), b_f16)
	var y_buffer = rd.storage_buffer_create(batch_size * out_features * 2) # *2 porque es 16-bit

	var uniform_x = RDUniform.new(); uniform_x.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; uniform_x.binding = 0; uniform_x.add_id(x_buffer)
	var uniform_w = RDUniform.new(); uniform_w.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; uniform_w.binding = 1; uniform_w.add_id(w_buffer)
	var uniform_b = RDUniform.new(); uniform_b.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; uniform_b.binding = 2; uniform_b.add_id(b_buffer)
	var uniform_y = RDUniform.new(); uniform_y.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; uniform_y.binding = 3; uniform_y.add_id(y_buffer)

	var uniform_set = rd.uniform_set_create([uniform_x, uniform_w, uniform_b, uniform_y], shader, 0)
	var pipeline = rd.compute_pipeline_create(shader)
	var push_constants = PackedInt32Array([batch_size, in_features, out_features, activation, has_bias, 0, 0, 0]).to_byte_array()

	# --- EJECUCIÓN ---
	var round_results = []
	print("Iniciando Benchmark...")

	for r in range(rounds):
		var start_time = Time.get_ticks_usec()
		for i in range(iterations):
			var compute_list = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
			rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
			rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
			rd.compute_list_dispatch(compute_list, ceil(out_features / 8.0), ceil(batch_size / 8.0), 1)
			rd.compute_list_end()
			rd.submit()
			rd.sync()
		
		var avg_round_ms = ((Time.get_ticks_usec() - start_time) / 1000.0) / iterations
		round_results.append(avg_round_ms)
		print("Ronda %d: %.3f ms/inf" % [r + 1, avg_round_ms])

	# --- RESULTADOS ---
	var final_avg = 0.0
	for v in round_results: final_avg += v
	final_avg /= rounds
	
	print("\n--- RESUMEN 16-BIT ---")
	print("Promedio Global: %.3f ms" % final_avg)
	print("Tokens/Min (Est): %.2f" % ((1000.0 / final_avg) * 60.0))

# --- HELPERS ---
func _f32_to_f16_bytes(arr: PackedFloat32Array) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.resize(arr.size() * 2)
	for i in range(arr.size()):
		var f32 = arr[i]
		var f32_bits = PackedFloat32Array([f32]).to_byte_array().decode_u32(0)
		var sign = (f32_bits >> 16) & 0x8000
		var exponent = ((f32_bits >> 23) & 0xff) - 127
		var mantissa = (f32_bits >> 13) & 0x3ff
		
		var f16 = 0
		if exponent == -127: # Zero
			f16 = sign
		elif exponent > 15: # Overflow to infinity
			f16 = sign | 0x7c00
		elif exponent < -14: # Underflow to zero (simplificado)
			f16 = sign
		else:
			f16 = sign | ((exponent + 15) << 10) | mantissa
		
		bytes.encode_u16(i * 2, f16)
	return bytes

func _gen_rand_array(size):
	var a = PackedFloat32Array(); a.resize(size)
	for i in range(size): a[i] = randf_range(-1.0, 1.0)
	return a
