extends SceneTree

# ============================================================
# CRITERIO DE ACEPTACION — ACOPLAMIENTO ARMA <-> PERSONAJE
# ============================================================
# Define numericamente cuando el arma esta correctamente acoplada al
# personaje. Los valores provienen de una decision del proyecto, no de una
# medicion previa: si el test falla, el sistema todavia no cumple.
#
# Verifica:
#   1. El arma esta donde dice el hueso de soporte. Sin offsets, sin
#      correcciones, sin calculos intermedios.
#   2. El forward del arma coincide con el forward del hueso.
#   3. Ambas cosas se mantienen con pitch y con yaw.
#      Este es el punto: ik_hand_gun cuelga de spine_02, que es lo que mueve
#      el escritor procedural de columna. Si el arma no sigue al torso aqui,
#      la cadena esta rota:
#      camara -> AimState -> SpineLookAtController -> spine_02
#              -> ik_hand_gun -> WeaponRoot
#      El solver CCDIK de columna se retiro en T02 (ADR-0008): ningun
#      SkeletonModifier3D escribe huesos en esta version del motor.
#      Con yaw, el torso no gira (ADR-0005); el que gira es el cuerpo y el
#      arma lo sigue por herencia de pelvis.
# ============================================================

const PLAYER_SCENE := "res://Player/PlayerCharacter.tscn"
const TEST_WEAPON := "res://World/Items/TestWeaponItem.tres"

const MAX_POSITION_ERROR := 0.001     # 1 mm
const MAX_ANGLE_ERROR_DEG := 2.0      # 2 grados, criterio de cadera

const PITCH_ANGLES_DEG: Array[float] = [-30.0, -15.0, 0.0, 15.0, 30.0]
const YAW_ANGLES_DEG: Array[float] = [-90.0, -45.0, 0.0, 45.0, 90.0]

var _player: Node3D
var _failures: Array[String] = []
var _checks: int = 0
var _t: float = 0.0
var _stage: int = 0
var _queue: Array[Dictionary] = []
var _results: Array[Dictionary] = []

func _initialize() -> void:
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(_player)
	# Suelo: sin el, el cuerpo cae en caida libre y la velocidad falsea la
	# comparacion arma-vs-hueso entre lecturas (~1 m de artefacto).
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
		for deg in PITCH_ANGLES_DEG:
			_queue.append({"axis": "pitch", "deg": deg})
		for deg in YAW_ANGLES_DEG:
			_queue.append({"axis": "yaw", "deg": deg})
		_stage = 2
		_t = 0.0

	elif _stage == 2 and _t > 0.7:
		if _queue.is_empty():
			_report()
			return true
		var next: Dictionary = _queue.pop_front()
		_apply(next["axis"], next["deg"])
		_stage = 3
		_t = 0.0

	elif _stage == 3 and _t > 0.7:
		_measure()
		_stage = 2
		_t = 0.0

	return false

## El pivote no se puede escribir directamente: CameraController lo
## sobrescribe cada fotograma desde fps_pitch / fps_yaw. Se conduce la fuente.
## Asi el cambio recorre la cadena real:
##   camara -> AimState -> SpineLookAtController -> spine_02
##           -> ik_hand_gun -> WeaponRoot
func _apply(axis: String, deg: float) -> void:
	var cam: Node = _player.get_node_or_null("CAMERARIG")
	if cam == null:
		_fail("No se encontro CAMERARIG")
		return
	if axis == "pitch":
		cam.fps_pitch = deg_to_rad(deg)
	else:
		cam.fps_yaw = deg_to_rad(deg)

func _current_label() -> String:
	var cam: Node = _player.get_node_or_null("CAMERARIG")
	if cam == null:
		return "?"
	return "pitch %+.0f yaw %+.0f" % [rad_to_deg(cam.fps_pitch), rad_to_deg(cam.fps_yaw)]

func _measure() -> void:
	var wc: Node = _player.get_node_or_null("WeaponRoot/WeaponController")
	if wc == null:
		_fail("No existe WeaponRoot/WeaponController.")
		return
	var skeleton: Skeleton3D = wc._skeleton
	if skeleton == null:
		_fail("WeaponController no tiene esqueleto.")
		return
	var gun: int = skeleton.find_bone("ik_hand_gun")
	if gun == -1:
		_fail("El esqueleto no tiene el hueso ik_hand_gun.")
		return

	var bone_world: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(gun)
	var weapon_world: Transform3D = wc.weapon_root.global_transform
	if _results.size() == 0:
		print("[TDBG] test skelglob=", skeleton.global_transform.origin, " bonelocal=", skeleton.get_bone_global_pose(gun).origin)

	var pos_err: float = bone_world.origin.distance_to(weapon_world.origin)
	var bone_fwd: Vector3 = -bone_world.basis.z.normalized()
	var weapon_fwd: Vector3 = -weapon_world.basis.z.normalized()
	var angle_err: float = rad_to_deg(acos(clampf(bone_fwd.dot(weapon_fwd), -1.0, 1.0)))

	var label: String = _current_label()
	_results.append({
		"label": label,
		"pos_err_m": pos_err,
		"angle_err_deg": angle_err,
		"body_y": _player.global_position.y,
	})
	_checks += 2

	if pos_err > MAX_POSITION_ERROR:
		_fail("%s: el arma esta a %.4f m de la posicion del hueso (max %.4f)"
				% [label, pos_err, MAX_POSITION_ERROR])
	if angle_err > MAX_ANGLE_ERROR_DEG:
		_fail("%s: el forward del arma difiere %.2f deg del hueso (max %.2f)"
				% [label, angle_err, MAX_ANGLE_ERROR_DEG])

func _report() -> void:
	print("=========== CRITERIO DE ACEPTACION: ARMA <-> PERSONAJE ===========")
	print("  tolerancias: posicion <= %.4f m   angulo <= %.1f deg"
			% [MAX_POSITION_ERROR, MAX_ANGLE_ERROR_DEG])
	for r in _results:
		print("  %-10s | posicion %8.4f m | angulo %8.2f deg | body_y %8.2f"
				% [r["label"], r["pos_err_m"], r["angle_err_deg"], r["body_y"]])
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