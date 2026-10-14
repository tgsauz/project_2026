extends SceneTree

# ============================================================
# INMUNIDAD AL YAW + CABEZA QUIETA (T03)
# El cuerpo es dueño del yaw (ADR-0005): el torso no lo toma y a la cabeza
# no se le escribe nada. Redes de regresión (verdes por construcción).
# ============================================================

const PLAYER_SCENE := "res://Player/PlayerCharacter.tscn"
const TEST_WEAPON := "res://World/Items/TestWeaponItem.tres"

const YAW_SWEEP_DEG: Array[float] = [-90.0, -45.0, 0.0, 45.0, 90.0]
const MAX_TORSO_YAW_VAR_DEG := 1.0
const MAX_HEAD_VAR_DEG := 1.0

var _player: Node3D
var _failures: Array[String] = []
var _t := 0.0
var _stage := 0
var _queue: Array = []
var _torso_yaws: Array[float] = []
var _head_rots: Array[Quaternion] = []
var _body_yaws: Array[float] = []

func _initialize() -> void:
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(_player)
	var floor_body := StaticBody3D.new()
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
		_queue = YAW_SWEEP_DEG.duplicate()
		_stage = 2
		_t = 0.0
	elif _stage == 2 and _t > 0.8:
		if _queue.is_empty():
			_check()
			_report()
			return true
		_player.get_node("CAMERARIG").fps_yaw = deg_to_rad(_queue.pop_front())
		_stage = 3
		_t = 0.0
	elif _stage == 3 and _t > 0.8:
		_measure()
		_stage = 2
		_t = 0.0
	return false

func _measure() -> void:
	var skel: Skeleton3D = _player.get_node_or_null("VisualsComponent/Rig/ImportedModel/Armature/Skeleton3D")
	var spose: Transform3D = skel.get_bone_global_pose(skel.find_bone("spine_02"))
	var fwd: Vector3 = (-spose.basis.z).normalized()
	_torso_yaws.append(rad_to_deg(atan2(fwd.x, -fwd.z)))
	_head_rots.append(skel.get_bone_pose_rotation(skel.find_bone("head")))
	_body_yaws.append(rad_to_deg(_player.rotation.y))

func _check() -> void:
	# El cuerpo sí debe haber girado (si no, la prueba es quietud falsa).
	var body_span: float = _body_yaws.max() - _body_yaws.min()
	if body_span < 45.0:
		_fail("El cuerpo no giró en el barrido (span %.1f): medición inválida." % body_span)
		return
	var torso_span: float = _torso_yaws.max() - _torso_yaws.min()
	if torso_span > MAX_TORSO_YAW_VAR_DEG:
		_fail("El torso tomó yaw: variación %.2f deg (máx %.2f)." % [torso_span, MAX_TORSO_YAW_VAR_DEG])
	var ref: Quaternion = _head_rots[0]
	for i in range(1, _head_rots.size()):
		var ang: float = rad_to_deg(acos(clampf(ref.dot(_head_rots[i]), -1.0, 1.0))) * 2.0
		if ang > MAX_HEAD_VAR_DEG:
			_fail("La cabeza se movió en el paso %d: %.2f deg (máx %.2f)." % [i, ang, MAX_HEAD_VAR_DEG])
			break

func _report() -> void:
	print("=========== YAW-INMUNIDAD + CABEZA QUIETA ===========")
	print("  torso yaw: ", _torso_yaws)
	print("  cuerpo yaw span: %.1f" % (_body_yaws.max() - _body_yaws.min()))
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
