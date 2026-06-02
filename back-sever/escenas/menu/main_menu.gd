extends Control


var upnp = UPNP.new()
var thread = null
@export var upnp_ip = 0
@export var port = 8888
func _init() -> void:

	self.port = port
	thread = Thread.new()
	thread.start(_upnp_setup.bind(port))
	pass

func _ready() -> void:
	prints("hola desde godot script")
	pass 



func _process(delta: float) -> void:
	pass
	


func _input(event: InputEvent) -> void:
	#if Input.is_key_pressed(KEY_W): nueva_red(8888,"127.0.0.1")
	#if Input.is_key_pressed(KEY_S): nueva_host(8888)
	#if Input.is_key_pressed(KEY_M): nueva_msj()
	
	pass




#func nueva_msj():
#
	#prints("servidor")
	#var player = preload("res://escena/mensaje/mensaje.tscn").instantiate()
	#add_child(player)
	#prints("instancio escena")
	#await get_tree().create_timer(3).timeout
	#pass





func _on_texto_plano_pressed() -> void:


	var menu = preload("res://back-sever/escenas/mode_view/user_admin.tscn").instantiate()
	add_child(menu)
	prints("instancio escena")
	await get_tree().create_timer(3).timeout
	pass # Replace with function body.


func _on_binarios_pressed() -> void:
	

	var menu = preload("res://back-sever/escenas/modo_bin/elserver.tscn").instantiate()
	add_child(menu)
	prints("instancio escena")
	await get_tree().create_timer(3).timeout

	pass # Replace with function body.


func _on_salir_pressed() -> void:
	get_tree().quit()
	pass # Replace with function body.


func _on_prueba_de_bit_pressed() -> void:

	var menu = preload("res://lib/bit-w/byte_bit.tscn").instantiate()
	add_child(menu)
	prints("instancio escena")
	await get_tree().create_timer(3).timeout

	pass # Replace with function body.




func _on_prueba_ram_pressed() -> void:
	var menu = preload("res://back-sever/time_data_ram.tscn").instantiate()
	add_child(menu)
	prints("instancio escena")

	pass # Replace with function body.


func _on_rsa_pressed() -> void:
	var menu = preload("res://lib/rsa/rsas.tscn").instantiate()
	add_child(menu)
	prints("instancio escena")
	await get_tree().create_timer(3).timeout
	pass # Replace with function body.


func _on_rat_pressed() -> void:
	var menu = preload("res://back-sever/escenas/cifre/filesek.tscn").instantiate()
	add_child(menu)
	prints("instancio escena")
	await get_tree().create_timer(3).timeout
	pass # Replace with function body.


func _on_timer_timeout() -> void:
	prints("mi godot timer ")
	pass # Replace with function body.




func _upnp_setup(server_port):
	prints("upnp setup iniciando")
	var err = upnp.discover()
	if err != OK:
		push_error(str(err))
		print("Error al asignar : %s" % port)
		return
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		upnp.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "UDP")
		#upnp.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "TCP")
		upnp_ip = upnp.query_external_address()
		print("Success! Join Address: %s" % upnp_ip)
		
