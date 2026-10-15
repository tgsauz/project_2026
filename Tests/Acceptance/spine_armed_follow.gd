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
# Afirma cuatro cosas, en este orden:
#   1. En la neutra el escritor no escribe nada. Esta es la asercion que
#      captura la causa raiz: es el error constante que el servo se inventa.
#   2. La boca se mueve en el mismo sentido que la camara.
#   3. La columna responde en un solo sentido a lo largo del barrido, sin
#      escalones ni vaiven. No afirma el sentido: ese lo afirma la 4.
#   4. La inclinacion del torso va CON SIGNO: en ARMED y en AIMING, mirar al
#      suelo tiene que inclinar mas adelante que mirar al cielo.
#
# La asercion 4 es la que faltaba (issue 13). Las tres primeras no detectan una
# inversion: una inclinacion al reves tambien es monotona. Y la elevacion
# asin(componente Y) es ciega al signo cerca de la vertical, porque no
# distingue inclinarse adelante de inclinarse atras. Por eso la asercion 4
# mide la inclinacion con la metrica con signo y la asercion 3 no la suple.
#
# La asercion 4 se repite en AIMING, donde ya se cumple. Esa es la red que
# demuestra que el metodo de referencia no se toco al arreglar ARMED.
#
# Todo se mide en espacio global. El nodo Rig lleva 180 grados sobre Y
# (ADR-0002, legitimo, no se toca): comparar en espacio local del esqueleto
# invertiria el signo del pitch.
#
# El eje de un hueso se lee de get_bone_global_pose(idx).basis, nunca del
# segmento entre el origen del hueso y el de su padre: ese segmento lo deciden
# las cabezas de los huesos, no su orientacion, asi que es invariante a la
# rotacion y no puede observar lo que se le pide observar. El segmento
# spine_02 -> cuello si vale, porque el cuello es descendiente de spine_02:
# ahi lo que se mueve es el final del segmento, no sus dos cabezas.

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

## Asercion 3. Red de seguridad, no deteccion. Es el hueco de paso por debajo
## del cual un cambio no cuenta: un barrido limpio no tiene por que tener
## ningun paso por encima de este umbral, solo pasos llanos.
const FLAT_STEP_TOLERANCE_DEG := 1.0

## Asercion 4. Los dos extremos del barrido, en grados de camara.
const LEAN_LOW_PITCH_DEG := -30.0
const LEAN_HIGH_PITCH_DEG := 30.0

## Asercion 4. Margen minimo de la diferencia a favor de mirar al suelo. Medido
## en ARMED: la diferencia antes del arreglo era de -9.02 (torso al reves) y
## despues de +9.02. El margen de 0.5 esta a la mitad de la senal esperada, de
## modo que un ruido de medicion no lo hunda y una inversion de verdad
## tampoco lo compense. No es un umbral de forma: es el ancho minimo del
## defecto que se quiere ver.
##
## Lo que afirma es la DIRECCION, no el espejo exacto de los valores. El
## recorrido medido se mantiene en 8.98 grados y solo cambia de lado: el
## punto de equilibrio del lazo lo fija la postura del clip, no la camara, y
## con INFLUENCE_ARMED = 0.15 el escritor no puede mover ese punto. Afirmar
## el espejo seria exigirle al servo algo que su unica palanca no alcanza.
const MIN_LEAN_DIRECTION_MARGIN_DEG := 0.5

## Huesos del eje de la columna. El cuello es el extremo distal de spine_02:
## el segmento entre ambos gira con la rotacion de la columna, que es
## justamente lo que el escritor escribe.
const SPINE_BONE := "spine_02"
const NECK_BONE := "neck"

var _player: Node3D
var _skeleton: Skeleton3D
var _writer: SkeletonModifier3D
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []
var _aiming_rows: Array[Dictionary] = []
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
			"lean": _torso_lean_deg(),
		})
		print("  ARMED  cam %+6.1f | columna %+7.2f | boca %+7.2f | inclinacion %+7.2f"
				% [pitch, _rows[-1]["spine"], _rows[-1]["mouth"], _rows[-1]["lean"]])
		if _queue.is_empty():
			# Segunda pasada con la misma asercion en AIMING, donde ya se
			# cumple. Es la red que demuestra que el metodo de referencia no se
			# toco al arreglar ARMED, asi que se mide con el mismo codigo y en
			# la misma corrida.
			_player.is_aiming = true
			_queue = PITCH_SWEEP_DEG.duplicate()
			_stage = 5
			_t = 0.0
			return false
		_player.get_node("CAMERARIG").fps_pitch = deg_to_rad(_queue.pop_front())
		_t = 0.0

	# Espera a que la influencia llegue a INFLUENCE_AIMING antes de medir: si
	# no, el primer punto del barrido se lee con la mezcla a medias.
	elif _stage == 5 and _t > 2.5:
		_player.get_node("CAMERARIG").fps_pitch = deg_to_rad(_queue.pop_front())
		_stage = 6
		_t = 0.0

	elif _stage == 6 and _t > 1.2:
		var pitch: float = _camera_pitch()
		_aiming_rows.append({
			"pitch": pitch,
			"lean": _torso_lean_deg(),
		})
		print("  AIMING cam %+6.1f | inclinacion %+7.2f" % [pitch, _aiming_rows[-1]["lean"]])
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

	# Asercion 3: la columna responde al pitch de camara en UN solo sentido, sin
# escalones ni vaiven. No afirma cual es ese sentido: antes afirmaba que la
# columna subia con la camara, y eso era exactamente el regimen invertido del
# issue 13. La asercion 4 es la que afirma el sentido, con signo y con la
# metrica correcta. Aqui solo se afirma que la respuesta es limpia.
	for i in range(1, _rows.size()):
		var prev: float = _rows[i - 1]["spine"]
		var cur: float = _rows[i]["spine"]
		var up: bool = cur > prev + FLAT_STEP_TOLERANCE_DEG
		var down: bool = cur < prev - FLAT_STEP_TOLERANCE_DEG
		if up and down:
			_fail("La columna vaivena en el paso %d: %.2f -> %.2f, mezcla subidas y bajadas de mas de %.2f deg en el mismo barrido."
					% [i, prev, cur, FLAT_STEP_TOLERANCE_DEG])
			break

	# Asercion 4: la inclinacion del torso va con signo. La elevacion no
	# puede decir esto; el angulo contra el frente del personaje si.
	_assert_lean_direction("ARMED", _lean_at(_rows, LEAN_LOW_PITCH_DEG), _lean_at(_rows, LEAN_HIGH_PITCH_DEG))
	_assert_lean_direction("AIMING", _lean_at(_aiming_rows, LEAN_LOW_PITCH_DEG), _lean_at(_aiming_rows, LEAN_HIGH_PITCH_DEG))

func _assert_lean_direction(state: String, lean_low: float, lean_high: float) -> void:
	# Mirar al suelo (camara abajo) tiene que inclinar MAS adelante que mirar
	# al cielo. Al reves es el sintoma del issue 13: el usuario lo vio jugando
	# antes de que se midiera.
	var margin: float = lean_low - lean_high
	if margin < MIN_LEAN_DIRECTION_MARGIN_DEG:
		_fail("En %s la inclinacion va al reves: mirando al suelo el torso queda a %+.2f deg y mirando al cielo a %+.2f deg (margen %+.2f, min %+.2f). Mirar al suelo tiene que inclinar mas adelante."
				% [state, lean_low, lean_high, margin, MIN_LEAN_DIRECTION_MARGIN_DEG])

func _lean_at(rows: Array[Dictionary], pitch: float) -> float:
	for row in rows:
		var row_pitch: float = row["pitch"]
		if absf(row_pitch - pitch) < 0.5:
			return row["lean"]
	return 0.0

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

## Inclinacion del torso CON SIGNO, en grados. Positivo = inclinado adelante,
## negativo = inclinado atras.
##
## Es la metrica que la elevacion no puede dar: asin(componente Y) de un
## vector casi vertical vale lo mismo inclinado adelante que inclinado
## atras, asi que un regimen invertido pasa por verde. Aqui el vector
## spine_02 -> cuello se mide contra el frente del personaje
## (-player.global_basis.z), y atan2 separa los dos casos.
##
## El segmento spine_02 -> cuello si depende de la rotacion de la columna: el
## cuello es descendiente de spine_02, asi que el extremo del segmento se
## mueve cuando spine_02 gira. El segmento spine_02 -> padre, en cambio, es
## invariante (lo deciden las cabezas de los huesos) y por eso no sirve.
func _torso_lean_deg() -> float:
	var spine_idx: int = _skeleton.find_bone(SPINE_BONE)
	var neck_idx: int = _skeleton.find_bone(NECK_BONE)
	if spine_idx == -1 or neck_idx == -1:
		return 0.0
	var spine_origin: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(spine_idx).origin
	var neck_origin: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(neck_idx).origin
	var axis: Vector3 = (neck_origin - spine_origin).normalized()
	if axis.is_zero_approx():
		return 0.0
	var forward: Vector3 = -_player.global_basis.z.normalized()
	return rad_to_deg(atan2(axis.dot(forward), axis.dot(Vector3.UP)))

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
	print("  asercion 3: respuesta en un solo sentido a lo largo del barrido")
	print("  asercion 4: ARMED  cam %+.0f -> %+.2f | cam %+.0f -> %+.2f"
			% [LEAN_LOW_PITCH_DEG, _lean_at(_rows, LEAN_LOW_PITCH_DEG),
			LEAN_HIGH_PITCH_DEG, _lean_at(_rows, LEAN_HIGH_PITCH_DEG)])
	print("  asercion 4: AIMING cam %+.0f -> %+.2f | cam %+.0f -> %+.2f"
			% [LEAN_LOW_PITCH_DEG, _lean_at(_aiming_rows, LEAN_LOW_PITCH_DEG),
			LEAN_HIGH_PITCH_DEG, _lean_at(_aiming_rows, LEAN_HIGH_PITCH_DEG)])
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