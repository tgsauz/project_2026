extends SceneTree

# ============================================================
# T04 — VISUALIZADOR CON RAYO DE CÁMARA Y RAYO DE BOCA
# ============================================================
# Afirma, en headless y sin escena de prueba manual:
#   1. Con el visualizador activo existen ambas líneas
#      (rayo de cámara y rayo de boca).
#   2. Sus direcciones coinciden con sus fuentes:
#      cámara FPS (CAMERARIG/FPSPIVOT/FPSCAMERA, -Z global) y
#      marcador de boca MUZZLE del visual equipado (-Z global).
#   3. Ambas viven en el mismo espacio (orígenes globales coinciden
#      con las fuentes dentro de tolerancia).
# ============================================================

const PLAYER_SCENE := "res://Player/PlayerCharacter.tscn"
const TEST_WEAPON := "res://World/Items/TestWeaponItem.tres"

const MAX_ORIGIN_ERROR := 0.005
const MAX_ANGLE_ERROR_DEG := 1.0

var _player: Node3D
var _viz: DebugIKVisualizer
var _failures: Array[String] = []
var _checks: int = 0
var _t: float = 0.0
var _stage: int = 0

func _initialize() -> void:
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(_player)
	# Suelo: sin el, el cuerpo cae en caida libre. Este test compara el origen
	# cacheado del rayo contra el origen global de su fuente, asi que la caida
	# se cuela como error de posicion (mismo motivo que en weapon_coupling_acceptance).
	var floor_body := StaticBody3D.new()
	floor_body.name = "AcceptanceFloor"
	root.add_child(floor_body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 0.5, 10)
	col.shape = shape
	col.position = Vector3(0, -0.25, 0)
	floor_body.add_child(col)

func _process(_delta: float) -> bool:
	_t += _delta

	if _stage == 0 and _t > 0.6:
		var inventory: Node = _player.get_node_or_null("InventoryComponent")
		if inventory == null:
			_fail("El jugador no tiene InventoryComponent.")
			return true
		if not inventory.attach_item(ItemInstance.create_from_definition(load(TEST_WEAPON), 1), "right_hand"):
			_fail("No se pudo equipar el arma en right_hand.")
			return true
		_stage = 1
		_t = 0.0

	elif _stage == 1 and _t > 2.0:
		var spine := _player.get("spine_look_at") as SkeletonModifier3D
		if spine == null:
			_fail("CharacterController no resolvió SpineLookAtController.")
			return true
		_viz = DebugIKVisualizer.new()
		_viz.name = "DebugIKVisualizer"
		_viz.set_skeleton(spine.get_skeleton())
		_player.add_child(_viz)
		_stage = 2
		_t = 0.0

	elif _stage == 2 and _t > 0.7:
		_measure()
		_report()
		return true

	return false

func _measure() -> void:
	if _viz == null or not is_instance_valid(_viz):
		_fail("No existe el visualizador.")
		return

	_checks += 1
	if not _viz.has_camera_ray():
		_fail("Con el visualizador activo no existe el rayo de cámara.")
	else:
		var cam: Camera3D = _player.get_node_or_null("CAMERARIG/FPSPIVOT/FPSCAMERA") as Camera3D
		if cam == null:
			_fail("No se encontró CAMERARIG/FPSPIVOT/FPSCAMERA.")
		else:
			_compare_ray("cámara", _viz.get_camera_ray_origin(), _viz.get_camera_ray_direction(),
					cam.global_transform.origin, -cam.global_transform.basis.z.normalized())

	_checks += 1
	if not _viz.has_muzzle_ray():
		_fail("Con el visualizador activo no existe el rayo de boca.")
	else:
		var wc: Node = _player.get_node_or_null("WeaponRoot/WeaponController")
		if wc == null:
			_fail("No existe WeaponRoot/WeaponController.")
		elif not wc.has_method("get_weapon_visual"):
			_fail("WeaponController no expone get_weapon_visual().")
		else:
			var visual: Node3D = wc.get_weapon_visual() as Node3D
			if visual == null:
				_fail("No hay visual de arma equipado en right_hand.")
			else:
				var muzzle: Node3D = visual.find_child("MUZZLE", true, false) as Node3D
				if visual.name == "MUZZLE":
					muzzle = visual
				if muzzle == null:
					_fail("El visual equipado no tiene marcador MUZZLE.")
				else:
					_compare_ray("boca", _viz.get_muzzle_ray_origin(), _viz.get_muzzle_ray_direction(),
							muzzle.global_transform.origin, -muzzle.global_transform.basis.z.normalized())

func _compare_ray(label: String, got_origin: Vector3, got_dir: Vector3, want_origin: Vector3, want_dir: Vector3) -> void:
	_checks += 2
	var pos_err: float = got_origin.distance_to(want_origin)
	var angle_err: float = rad_to_deg(acos(clampf(got_dir.normalized().dot(want_dir.normalized()), -1.0, 1.0)))
	print("  rayo %-6s | origen %8.4f m | ángulo %8.2f deg" % [label, pos_err, angle_err])
	if pos_err > MAX_ORIGIN_ERROR:
		_fail("Rayo de %s: origen a %.4f m de su fuente (máx %.4f)" % [label, pos_err, MAX_ORIGIN_ERROR])
	if angle_err > MAX_ANGLE_ERROR_DEG:
		_fail("Rayo de %s: dirección difiere %.2f deg de su fuente (máx %.2f)" % [label, angle_err, MAX_ANGLE_ERROR_DEG])

func _report() -> void:
	print("=========== T04: RAYOS DEL VISUALIZADOR ===========")
	print("  tolerancias: origen <= %.4f m   ángulo <= %.1f deg" % [MAX_ORIGIN_ERROR, MAX_ANGLE_ERROR_DEG])
	print("----------------------------------------------------------------")
	print("  comprobaciones: %d   fallos: %d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("RESULTADO: PASA")
		quit(0)
		return
	print("RESULTADO: FALLA")
	for f in _failures:
		print("  - %s" % f)
	quit(1)

func _fail(msg: String) -> void:
	_failures.append(msg)
