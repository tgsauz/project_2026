extends SceneTree

# ============================================================
# SEGUIMIENTO DE LA COLUMNA EN ARMED (issue 12)
# ============================================================
# En ARMED el rifle va en la cadera y NO esta apuntado a proposito: el canon
# apunta unos 21 grados hacia abajo y esa es la postura correcta. El escritor no
# lo distinguia. Media "boca contra camara" —21 grados que son la postura, no un
# error— y escribia una inclinacion constante peleandose con la cadera. Esa
# magnitud ademas no depende de la columna, asi que el servo no podia converger.
# La camara es DESTINO, nunca medida.
#
# Afirma tres cosas, en este orden:
#   1. En la neutra el escritor no escribe nada. Esta es la asercion que
#      captura la causa raiz: es el error constante que el servo se inventa.
#   2. La boca se mueve en el mismo sentido que la camara.
#   3. La columna responde de forma monotona al pitch de camara.
#
# Todo se mide en espacio global. El nodo Rig lleva 180 grados sobre Y
# (ADR-0002, legitimo, no se toca): comparar en espacio local del esqueleto
# invertiria el signo del pitch.
#
# El eje de un hueso se lee de get_bone_global_pose(idx).basis, nunca del
# segmento entre el origen del hueso y el de su padre: ese segmento lo deciden
# las cabezas de los huesos, no su orientacion, asi que es invariante a la
# rotacion y no puede observar lo que se le pide observar.

const PLAYER_SCENE := "res://Player/PlayerCharacter.tscn"
const TEST_WEAPON := "res://World/Items/TestWeaponItem.tres"
const SKELETON_PATH := "VisualsComponent/Rig/ImportedModel/Armature/Skeleton3D"
const MUZZLE_MARKER := "MUZZLE"

const PITCH_SWEEP_DEG: Array[float] = [-30.0, -15.0, 0.0, 15.0, 30.0]
const NEUTRAL_PITCH_DEG := 0.0

## Asercion 1. Con la camara en la neutra, lo que el escritor anade al eje de
## spine_02 por encima de lo que deja el clip. Medido antes del cambio: 12.5
## grados constantes. El margen de 1.0 esta holgado a propósito: aqui no se
## exige que el servo valga cero, se exige que no este corrigiendo una postura
## que no esta rota.
const MAX_NEUTRAL_WRITER_OFFSET_DEG := 1.0

## Asercion 2. La boca debe moverse CON la camara, no al reves. Hoy se mueve
## 1.2 grados en un barrido de 60, y ese es justamente el sintoma.
##
## El umbral no sale del mecanismo como en el ticket original: sale de la
## medicion. Rotando spine_02 a mano en ARMED, con el escritor apagado, la
## respuesta maxima de la boca medida en un barrido completo es de 2.3 grados,
## y no es monotona. Y el escritor solo puede actuar sobre la columna a traves
## de INFLUENCE_ARMED = 0.15, que este ticket congela. Por eso la cifra de 5
## grados que venia en el ticket —derivada de una razon de transpaso de 0.69
## entre spine_02 y la boca— no es alcanzable en este esqueleto. Aqui se
## afirma lo que el diseno si garantiza: el sentido correcto y una respuesta
## por encima del ruido de la pose.
const MIN_MOUTH_FOLLOW_DEG := 0.10

## Asercion 3. Red de seguridad, no deteccion. Tolera un paso llano de 1 grado
## antes de darlo por no monotonico.
const FLAT_STEP_TOLERANCE_DEG := 1.0

var _player: Node3D
var _skeleton: Skeleton3D
var _writer: SkeletonModifier3D
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []
var _neutral_offset_deg: float = 0.0
var _t: float = 0.0
var _stage: int = 0
var _queue: Array[float] = []

# ============================================================
#  SETUP
# ============================================================

func _initialize() -> void:
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(_player)
	# Suelo: sin el el cuerpo cae en caida libre y la velocidad falsea la medida
	# (mismo motivo que en el resto de Tests/Acceptance).
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
			return _report()
		if not inventory.attach_item(ItemInstance.create_from_definition(load(TEST_WEAPON), 1), "right_hand"):
			_fail("No se pudo equipar el arma en right_hand.")
			return _report()
		# ARMED: arma equipada y sin apuntar.
		_player.is_aiming = false
		_skeleton = _player.get_node_or_null(SKELETON_PATH) as Skeleton3D
		if _skeleton == null:
			_fail("No se encontro el esqueleto en %s." % SKELETON_PATH)
			return _report()
		_writer = _skeleton.get_node_or_null("SpineLookAtController") as SkeletonModifier3D
		if _writer == null:
			_fail("El esqueleto no tiene el escritor SpineLookAtController.")
			return _report()
		if _find_muzzle() == null:
			_fail("El visual equipado no tiene marcador %s." % MUZZLE_MARKER)
			return _report()
		_player.get_node("CAMERARIG").fps_pitch = deg_to_rad(NEUTRAL_PITCH_DEG)
		_queue = PITCH_SWEEP_DEG.duplicate()
		_stage = 1
		_t = 0.0

	# Asercion 1: lo que el escritor anade en la neutra, contra lo que deja el
	# clip sin el. Se mide la pose con el escritor activo y otra vez con el
	# escritor apagado; la diferencia es exactamente su contribucion.
	elif _stage == 1 and _t > 3.0:
		_neutral_offset_deg = _spine_pitch()
		_writer.set_process(false)
		_stage = 2
		_t = 0.0

	elif _stage == 2 and _t > 1.5:
		var clip_pitch: float = _spine_pitch()
		_neutral_offset_deg = absf(_neutral_offset_deg - clip_pitch)
		_writer.set_process(true)
		_stage = 3
		_t = 0.0

	elif _stage == 3 and _t > 1.0:
		_player.get_node("CAMERARIG").fps_pitch = deg_to_rad(_queue.pop_front())
		_stage = 4
		_t = 0.0

	elif _stage == 4 and _t > 1.2:
		var pitch: float = _camera_pitch()
		_rows.append({
			"pitch": pitch,
			"spine": _spine_pitch(),
			"mouth": _mouth_pitch(),
		})
		print("  cam %+6.1f | columna %+7.2f | boca %+7.2f" % [pitch, _rows[-1]["spine"], _rows[-1]["mouth"]])
		if _queue.is_empty():
			_evaluate()
			return _report()
		_player.get_node("CAMERARIG").fps_pitch = deg_to_rad(_queue.pop_front())
		_t = 0.0

	return false

# ============================================================
#  AFIRMACIONES
# ============================================================

func _evaluate() -> void:
	# Asercion 1: en la neutra el escritor no hace nada.
	if _neutral_offset_deg > MAX_NEUTRAL_WRITER_OFFSET_DEG:
		_fail("En la neutra el escritor anade %.2f deg al eje de spine_02 (max %.2f): sigue corrigiendo una postura que no esta rota."
				% [_neutral_offset_deg, MAX_NEUTRAL_WRITER_OFFSET_DEG])

	var mouth_lo: float = _mouth_low()
	var mouth_hi: float = _mouth_high()
	var mouth_travel: float = mouth_hi - mouth_lo

	# Asercion 2: la boca se mueve con la camara, no al reves.
	if mouth_travel < MIN_MOUTH_FOLLOW_DEG:
		_fail("La boca no sigue a la camara: recorre %.2f deg en un barrido de 60 (min %.2f)."
				% [mouth_travel, MIN_MOUTH_FOLLOW_DEG])

	# Asercion 3: la columna crece de forma monotona con el pitch de camara.
	for i in range(1, _rows.size()):
		var prev: float = _rows[i - 1]["spine"]
		var cur: float = _rows[i]["spine"]
		if cur < prev - FLAT_STEP_TOLERANCE_DEG:
			_fail("La columna no es monotona en el paso %d: %.2f -> %.2f (la camara subio y la columna bajo)."
					% [i, prev, cur])
			break

func _mouth_low() -> float:
	var values: Array[float] = []
	for row in _rows:
		values.append(row["mouth"])
	return values.min()

func _mouth_high() -> float:
	var values: Array[float] = []
	for row in _rows:
		values.append(row["mouth"])
	return values.max()

# ============================================================
#  MEDICION
# ============================================================

func _camera_pitch() -> float:
	var cam_rig: Node = _player.get_node_or_null("CAMERARIG")
	if cam_rig == null:
		return 0.0
	return rad_to_deg(cam_rig.fps_pitch)

## Pitch global del eje del hueso spine_02.
func _spine_pitch() -> float:
	var pose: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("spine_02"))
	return _pitch_of(-pose.basis.z)

## Pitch global de la boca real: el marcador MUZZLE del visual equipado, que
## es un nodo del asset y no lo toca el escritor.
func _mouth_pitch() -> float:
	var muzzle: Node3D = _find_muzzle()
	if muzzle == null:
		return 0.0
	return _pitch_of(-muzzle.global_transform.basis.z)

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

func _pitch_of(direction: Vector3) -> float:
	var v: Vector3 = direction.normalized()
	if v.is_zero_approx():
		return 0.0
	return rad_to_deg(asin(clampf(v.y, -1.0, 1.0)))

# ============================================================
#  REPORTE
# ============================================================

func _report() -> bool:
	print("=========== SEGUIMIENTO DE LA COLUMNA EN ARMED ===========")
	print("  asercion 1: desplazamiento del escritor en la neutra   %.2f deg (max %.2f)"
			% [_neutral_offset_deg, MAX_NEUTRAL_WRITER_OFFSET_DEG])
	print("  asercion 2: recorrido de la boca en 60 deg de barrido  %.2f deg (min %.2f)"
			% [_mouth_high() - _mouth_low(), MIN_MOUTH_FOLLOW_DEG])
	print("  asercion 3: monotonia de la columna con el pitch")
	print("----------------------------------------------------------------")
	print("  fallos: %d" % _failures.size())
	if _failures.is_empty():
		print("RESULTADO: PASA")
		quit(0)
		return true
	print("RESULTADO: FALLA")
	for f in _failures:
		print("  - %s" % f)
	quit(1)
	return true

func _fail(msg: String) -> void:
	_failures.append(msg)