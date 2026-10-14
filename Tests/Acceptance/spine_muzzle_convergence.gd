extends SceneTree

# ============================================================
# CONVERGENCIA DE LA BOCA REAL (T06)
# ============================================================
# Mide hacia dónde apunta el arma con el marcador MUZZLE del visual
# equipado, no con el eje del hueso que el escritor procedural usa como
# sensor.
#
# Por qué este test y no el anterior (spine_pitch_response): aquel compara
# el -Z del hueso ik_hand_gun contra la dirección de apuntado, que es
# exactamente la magnitud que el escritor optimiza. Verifica la premisa
# del escritor con la premisa del escritor, así que pasa por construcción.
# weapon_coupling_acceptance compara el WeaponRoot contra la pose del mismo
# hueso, así que un error de convención de eje se cancela en los dos lados.
# Los dos pueden estar verdes con el torso doblado 90 grados.
#
# La boca real no comparte esa circularidad: es un nodo del asset del arma,
# y el escritor no lo toca.
#
# Todo se mide en espacio global. El nodo Rig lleva 180 grados sobre Y
# (ADR-0002, legitimo, no se toca), y esa rotacion ya esta aplicada en las
# coordenadas globales. Comparar en espacio local del esqueleto invertiria
# el signo del pitch y daria el error contrario al real.

const PLAYER_SCENE := "res://Player/PlayerCharacter.tscn"
const TEST_WEAPON := "res://World/Items/TestWeaponItem.tres"
const SKELETON_PATH := "VisualsComponent/Rig/ImportedModel/Armature/Skeleton3D"
const MUZZLE_MARKER := "MUZZLE"

## Criterio de cadera, el mismo que ya usa weapon_coupling_acceptance.
const MAX_AIM_ERROR_DEG := 2.0

## Pliegue del torso en la articulacion spine_02: angulo entre el forward
## de spine_01 y el forward de spine_02, ambos globales.
##
## Se mide el EJE del hueso, no el segmento pelvis -> spine_02. El segmento
## es invariante por construccion a la rotacion de spine_02 (la decide la
## posicion de sus cabezas, no su orientacion), asi que da verde con el
## torso doblado. El eje si responde a esa rotacion.
##
## Tolerancia medida, no inventada. Con el escritor procedural apagado
## (pose pura del clip, en horizontal) el pliegue da 16.99 deg; con el
## escritor corregido da 16.99 deg tambien, porque el sensor ya no inventa
## error y la escritura es no-op en horizontal. Se admiten 20.0 deg, es
## decir 3.01 deg de margen. El bug de T07 lo llevaba a 63.55 deg en el
## mismo estado.
const MAX_TORSO_FOLD_DEG := 20.0

## El pliegue se afirma en horizontal: es el estado a reposo, el unico en el
## que el clip esta authored para apuntar bien (medido: con el escritor
## apagado, el error de la boca es 0.00 deg en horizontal y crece hasta
## 30 deg al separar la camara 30 grados). Afirmarlo en todo el barrido
## mediria al escritor corrigiendo, no al torso doblado.
const REST_PITCH_DEG := 0.0

const PITCH_SWEEP_DEG: Array[float] = [-30.0, -15.0, 0.0, 15.0, 30.0]

var _player: Node3D
var _skeleton: Skeleton3D
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []
var _torso_checked: bool = false
var _t: float = 0.0
var _stage: int = 0
var _queue: Array = []

# ============================================================
#  SETUP
# ============================================================

func _initialize() -> void:
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(_player)
	# Suelo: sin el, el cuerpo cae en caida libre y la velocidad falsea la
	# medida (mismo motivo que en weapon_coupling_acceptance).
	var floor_body := StaticBody3D.new()
	floor_body.name = "AcceptanceFloor"
	root.add_child(floor_body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 0.5, 10)
	col.shape = shape
	col.position = Vector3(0, -0.25, 0)
	floor_body.add_child(col)

# ============================================================
#  SECUENCIA
# ============================================================

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
		_player.is_aiming = true
		_skeleton = _player.get_node_or_null(SKELETON_PATH) as Skeleton3D
		if _skeleton == null:
			_fail("No se encontro el esqueleto en %s." % SKELETON_PATH)
			return true
		for bone_name in ["spine_01", "spine_02"]:
			if _skeleton.find_bone(bone_name) == -1:
				_fail("El esqueleto no tiene el hueso %s." % bone_name)
				return true
		_queue = PITCH_SWEEP_DEG.duplicate()
		_stage = 1
		_t = 0.0

	elif _stage == 1 and _t > 3.0:
		_stage = 2
		_t = 0.0

	elif _stage == 2 and _t > 0.7:
		if _queue.is_empty():
			if not _torso_checked:
				_fail("El barrido no paso por el estado a reposo (pitch 0).")
			_report()
			return true
		_player.get_node("CAMERARIG").fps_pitch = deg_to_rad(_queue.pop_front())
		_stage = 3
		_t = 0.0

	elif _stage == 3 and _t > 0.9:
		_measure()
		_stage = 2
		_t = 0.0

	return false

# ============================================================
#  MEDICION
# ============================================================

func _measure() -> void:
	var aim: Node = _player.get_node_or_null("AimController")
	if aim == null:
		_fail("El jugador no tiene AimController.")
		return
	var state: AimState = aim.get_aim_state()
	if state == null or not state.is_valid:
		_fail("AimState invalido: no hay direccion de apuntado que medir.")
		return
	var aim_dir: Vector3 = state.aim_direction.normalized()

	var muzzle: Node3D = _find_muzzle()
	if muzzle == null:
		_fail("El visual equipado no tiene marcador %s." % MUZZLE_MARKER)
		return
	var muzzle_fwd: Vector3 = -muzzle.global_transform.basis.z.normalized()

	var aim_err: float = _angle_deg(muzzle_fwd, aim_dir)
	var fold: float = _torso_fold_deg()
	var pitch: float = rad_to_deg(_player.get_node("CAMERARIG").fps_pitch)

	_rows.append({
		"pitch": pitch,
		"aim_err": aim_err,
		"fold": fold,
	})
	print("  pitch %+6.1f | boca vs apuntado %7.2f deg | pliegue spine_02 %7.2f deg"
			% [pitch, aim_err, fold])

	if aim_err > MAX_AIM_ERROR_DEG:
		_fail("En pitch %+.0f la boca difiere %.2f deg de la direccion de apuntado (max %.2f)."
				% [pitch, aim_err, MAX_AIM_ERROR_DEG])

	# El pliegue del torso se afirma solo en horizontal, el estado a reposo.
	if is_equal_approx(pitch, REST_PITCH_DEG):
		_torso_checked = true
		if fold > MAX_TORSO_FOLD_DEG:
			_fail("El torso se dobla: spine_02 queda a %.2f deg de spine_01 en reposo (max %.2f)."
					% [fold, MAX_TORSO_FOLD_DEG])

## Angulo de pliegue en la articulacion spine_02, en espacio global.
## Mide el eje del hueso, no el segmento pelvis -> spine_02 (ver la nota de
## MAX_TORSO_FOLD_DEG).
func _torso_fold_deg() -> float:
	return _angle_deg(_bone_forward("spine_01"), _bone_forward("spine_02"))

func _bone_forward(bone_name: String) -> Vector3:
	var pose: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(bone_name))
	return -pose.basis.z.normalized()

func _find_muzzle() -> Node3D:
	var wc: Node = _player.get_node_or_null("WeaponRoot/WeaponController")
	if wc == null or not wc.has_method("get_weapon_visual"):
		return null
	var visual: Node3D = wc.get_weapon_visual() as Node3D
	if visual == null:
		return null
	if visual.name == MUZZLE_MARKER:
		return visual
	return visual.find_child(MUZZLE_MARKER, true, false) as Node3D

func _angle_deg(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(acos(clampf(a.normalized().dot(b.normalized()), -1.0, 1.0)))

# ============================================================
#  REPORTE
# ============================================================

func _report() -> void:
	print("=========== CONVERGENCIA DE LA BOCA REAL (T06) ===========")
	print("  marcador: %s del visual equipado, en espacio global" % MUZZLE_MARKER)
	print("  tolerancias: boca vs apuntado <= %.2f deg   pliegue spine_02 en reposo <= %.2f deg"
			% [MAX_AIM_ERROR_DEG, MAX_TORSO_FOLD_DEG])
	print("----------------------------------------------------------------")
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
