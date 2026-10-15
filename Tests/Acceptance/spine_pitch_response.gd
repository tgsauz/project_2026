extends SceneTree

# ============================================================
# RESPUESTA DE COLUMNA AL PITCH (T02)
# La columna debe variar de forma monótona con el pitch del ratón, y no
# derivar con el ratón quieto. Conductual: no depende del mecanismo.
#
# Eje del hueso: -Y (T07). La convergencia con la boca real se afirma en
# spine_muzzle_convergence.gd; aquí solo la monotonicidad y la deriva.
# ============================================================

const PLAYER_SCENE := "res://Player/PlayerCharacter.tscn"
const TEST_WEAPON := "res://World/Items/TestWeaponItem.tres"

const PITCH_SWEEP_DEG: Array[float] = [-30.0, -15.0, 0.0, 15.0, 30.0]
const MIN_SWEEP_VARIATION_DEG := 5.0
const MAX_STILL_DRIFT_DEG := 0.5
const MAX_TRACK_ERROR_DEG := 1.0

var _player: Node3D
var _failures: Array[String] = []
var _t := 0.0
var _stage := 0
var _queue: Array = []
var _pitches: Array[float] = []
var _still_samples: Array[float] = []

func _initialize() -> void:
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(_player)
	# Suelo: hoy este test no lo necesita porque mide solo angulos
	# (invariantes a la traslacion), pero es la misma trampa latente que
	# rompia spine_visual_rays: sin suelo el cuerpo cae y cualquier medicion
	# de posicion pasaria a fallar al azar.
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
		if inventory == null or not inventory.attach_item(ItemInstance.create_from_definition(load(TEST_WEAPON), 1), "right_hand"):
			_fail("No se pudo equipar.")
			return true
		_player.is_aiming = true
		_stage = 1
		_t = 0.0
	elif _stage == 1 and _t > 3.0:
		_queue = PITCH_SWEEP_DEG.duplicate()
		_stage = 2
		_t = 0.0
	elif _stage == 2 and _t > 0.8:
		if _queue.is_empty():
			_check_sweep()
			_stage = 4
			_t = 0.0
			return false
		_player.get_node("CAMERARIG").fps_pitch = deg_to_rad(_queue.pop_front())
		_stage = 3
		_t = 0.0
	elif _stage == 3 and _t > 0.8:
		_pitches.append(_spine_pitch())
		var err: float = absf(_last_gun_pitch - _last_aim_pitch)
		if err > MAX_TRACK_ERROR_DEG:
			_fail("En %s el arma difiere %.2f deg del apuntado (max %.2f)." % [_current_label(), err, MAX_TRACK_ERROR_DEG])
		_stage = 2
		_t = 0.0
	elif _stage == 4 and _t > 0.4:
		# Ratón quieto: 5 muestras en ~2s, sin deriva.
		_still_samples.append(_spine_pitch())
		if _still_samples.size() >= 5:
			var lo: float = _still_samples.min()
			var hi: float = _still_samples.max()
			if hi - lo > MAX_STILL_DRIFT_DEG:
				_fail("Con ratón quieto la columna derivó %.2f deg (máx %.2f)." % [hi - lo, MAX_STILL_DRIFT_DEG])
			_report()
			return true
		_t = 0.0
	return false

var _last_aim := 0.0

var _last_gun_pitch := 0.0
var _last_aim_pitch := 0.0

func _current_label() -> String:
	var cam: Node = _player.get_node_or_null("CAMERARIG")
	return "pitch %+.0f" % rad_to_deg(cam.fps_pitch)

func _spine_pitch() -> float:
	var skel: Skeleton3D = _player.get_node_or_null("VisualsComponent/Rig/ImportedModel/Armature/Skeleton3D")
	var gun: int = skel.find_bone("ik_hand_gun")
	var gpose: Transform3D = skel.get_bone_global_pose(gun)
	# El forward del hueso del arma es su -Y, medido contra el marcador MUZZLE
	# del asset (coinciden a 0.00 deg, con el -Z quedan a 90.00 deg). Antes se
	# leia el -Z: el escritor procedural lo empujaba contra la direccion de
	# apuntado, asi que este test pasaba por construccion mientras el torso
	# estaba doblado 90 grados. Ver Tests/Acceptance/spine_muzzle_convergence.gd
	# para la medida no circular.
	var gun_fwd: Vector3 = (-(skel.global_transform.basis * gpose.basis).y).normalized()
	var gun_pitch: float = rad_to_deg(asin(clampf(gun_fwd.y, -1.0, 1.0)))
	var cam: Node = _player.get_node_or_null("CAMERARIG")
	_last_aim = rad_to_deg(cam.fps_pitch)
	var skel2: Skeleton3D = _player.get_node_or_null("VisualsComponent/Rig/ImportedModel/Armature/Skeleton3D")
	var slac: Node = skel2.get_node_or_null("SpineLookAtController")
	var aimc: Node = _player.get_node_or_null("AimController")
	var st: AimState = aimc.get_aim_state()
	var aim_pitch: float = rad_to_deg(asin(clampf(st.aim_direction.normalized().y, -1.0, 1.0)))
	_last_gun_pitch = gun_pitch
	_last_aim_pitch = aim_pitch
	return gun_pitch

func _check_sweep() -> void:
	var lo: float = _pitches.min()
	var hi: float = _pitches.max()
	if hi - lo < MIN_SWEEP_VARIATION_DEG:
		_fail("Barrido de pitch sin respuesta: variación %.2f deg (mín %.2f)." % [hi - lo, MIN_SWEEP_VARIATION_DEG])
	# Monotonía no decreciente con el pitch de entrada.
	for i in range(1, _pitches.size()):
		if _pitches[i] < _pitches[i - 1] - 1.0:
			_fail("No monotonía en el paso %d: %.2f -> %.2f." % [i, _pitches[i - 1], _pitches[i]])
			break

func _report() -> void:
	print("=========== RESPUESTA DE COLUMNA ===========")
	print("  barrido: ", _pitches)
	print("  fallos: %d" % _failures.size())
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
