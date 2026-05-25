extends Node

func _ready():
	# --- CONFIGURACIÓN ---
	var batch_size = 1
	var in_features = 1024
	var out_features = 1024
	var activation = 1 # 1: ReLU
	var has_bias = 1   # 1: Si
	
	var rounds = 10      # Cuántas rondas de prueba
	var iterations = 10  # Cuántas ejecuciones por ronda

	print("--- Iniciando Benchmarking de Estabilidad (10 rondas x 10 iteraciones) ---")
	print("Config: %d in -> %d out, Batch: %d\n" % [in_features, out_features, batch_size])

	var rd = RenderingServer.create_local_rendering_device()
	if not rd:
		print("ERROR: No se pudo crear el Rendering Device.")
		return

	# --- CARGAR SHADER ---
	var shader_file = load("res://linear_layer.glsl")
	var shader_spirv = shader_file.get_spirv()
	var shader = rd.shader_create_from_spirv(shader_spirv)
	
	# --- PREPARAR DATOS ---
	var x_data = PackedFloat32Array()
	for i in range(batch_size * in_features): x_data.append(randf_range(-1.0, 1.0))

	var w_data = PackedFloat32Array()
	for i in range(out_features * in_features): w_data.append(randf_range(-0.1, 0.1))

	var b_data = PackedFloat32Array()
	for i in range(out_features): b_data.append(randf_range(-0.01, 0.01))

	var x_buffer = rd.storage_buffer_create(x_data.size() * 4, x_data.to_byte_array())
	var w_buffer = rd.storage_buffer_create(w_data.size() * 4, w_data.to_byte_array())
	var b_buffer = rd.storage_buffer_create(b_data.size() * 4, b_data.to_byte_array())
	var y_buffer = rd.storage_buffer_create(batch_size * out_features * 4)

	var uniform_x = RDUniform.new(); uniform_x.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; uniform_x.binding = 0; uniform_x.add_id(x_buffer)
	var uniform_w = RDUniform.new(); uniform_w.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; uniform_w.binding = 1; uniform_w.add_id(w_buffer)
	var uniform_b = RDUniform.new(); uniform_b.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; uniform_b.binding = 2; uniform_b.add_id(b_buffer)
	var uniform_y = RDUniform.new(); uniform_y.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; uniform_y.binding = 3; uniform_y.add_id(y_buffer)

	var uniform_set = rd.uniform_set_create([uniform_x, uniform_w, uniform_b, uniform_y], shader, 0)
	var pipeline = rd.compute_pipeline_create(shader)

	var push_constants = PackedInt32Array([batch_size, in_features, out_features, activation, has_bias, 0, 0, 0]).to_byte_array()

	# --- EJECUCIÓN POR RONDAS ---
	var round_results = []
	
	for r in range(rounds):
		var start_time = Time.get_ticks_usec()
		
		for i in range(iterations):
			var compute_list = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
			rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
			rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
			
			var x_groups = ceil(out_features / 8.0)
			var y_groups = ceil(batch_size / 8.0)
			rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
			rd.compute_list_end()
			
			rd.submit()
			rd.sync()
		
		var end_time = Time.get_ticks_usec()
		var round_time_ms = (end_time - start_time) / 1000.0
		var avg_round_ms = round_time_ms / iterations
		round_results.append(avg_round_ms)
		
		print("Ronda %d: %.3f ms/inf (Total: %.2f ms)" % [r + 1, avg_round_ms, round_time_ms])

	# --- RESUMEN FINAL ---
	var sum_avg = 0.0
	var min_val = 999999.0
	var max_val = 0.0
	for val in round_results:
		sum_avg += val
		min_val = min(min_val, val)
		max_val = max(max_val, val)
	
	var final_avg = sum_avg / rounds
	var tokens_per_min = (1000.0 / final_avg) * 60.0
	
	print("\n--- RESUMEN DE ESTABILIDAD ---")
	print("Promedio Global: %.3f ms" % final_avg)
	print("Mínimo (Best):   %.3f ms" % min_val)
	print("Máximo (Worst):  %.3f ms" % max_val)
	print("Desviación (Max-Min): %.3f ms" % (max_val - min_val))
	print("Estadística: %.2f Tokens/Minuto" % tokens_per_min)
	
	print("\nPrueba finalizada.")
