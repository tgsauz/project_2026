extends SkeletonModifier3D
class_name SpineLookAtController

# ============================================================
#  EXPORTS
# ============================================================

@export var character_controller_path: NodePath
@export var aim_controller_path: NodePath
@export var look_at_target_path: NodePath
@export var weapon_root_path: NodePath

## Distance from pelvis to IK target. Tune for desired spine bend.
@export var arc_radius: float = 1.5

# ============================================================
#  CONSTANTS
# ============================================================

const INFLUENCE_UNARMED: float = 0.0
const INFLUENCE_ARMED: float = 0.15
const INFLUENCE_AIMING: float = 1.0
const INFLUENCE_BLEND_SPEED: float = 6.0
const INFLUENCE_EPSILON: float = 0.001

# ============================================================
#  STATE
# ============================================================

var _skeleton: Skeleton3D
var _character_controller: CharacterController
var _aim_controller: AimController
var _look_at_target: Node3D
var _weapon_root: Node3D

var _pelvis_idx: int = -1
var _spine01_idx: int = -1
var _spine02_idx: int = -1
var _gun_bone_idx: int = -1

var _current_influence: float = 0.0

var _debug_spine_weapon_align_pressed: bool = false
# Temp debug: prints spine bone eulers on P
var _debug_f8_pressed: bool = false

# ============================================================
#  LIFECYCLE
# ============================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spine_track"):
		_debug_f8_pressed = true
	if event.is_action_pressed("debug_spine_weapon_align"):
		_debug_spine_weapon_align_pressed = true

func _ready() -> void:
	_skeleton = get_skeleton()
	if _skeleton == null:
		push_error("SpineLookAtController must be a direct child of Skeleton3D.")
		return
	_resolve_dependencies()
	_cache_bone_indices()

	# Escritura directa en _process (sin diferir: el diferido rompe las
	# lecturas cruzadas del frame, ver T02). El orden contra el mezclador se
	# fija por prioridad de proceso mas abajo.
	process_priority = 100
	set_process(true)

func _process(delta: float) -> void:
	if _skeleton == null or _aim_controller == null or _look_at_target == null:
		return
	if _pelvis_idx == -1 or _spine02_idx == -1:
		return

	_update_look_at_target_pose()
	_blend_influence(delta, _compute_target_influence())
	_write_spine_pose()

func _update_look_at_target_pose() -> void:
	var aim_state: AimState = _aim_controller.get_aim_state()
	if aim_state == null or not aim_state.is_valid:
		return

	var aim_direction: Vector3 = aim_state.aim_direction.normalized()
	if aim_direction.is_zero_approx():
		return

	var pelvis_pose: Transform3D = _skeleton.get_bone_global_pose(_pelvis_idx)
	var pelvis_world: Vector3 = _skeleton.global_transform * pelvis_pose.origin
	var aim_target_world: Vector3 = pelvis_world + aim_direction * arc_radius

	# El punto de mirada es ancla visual y de debug (T01 lo exige). Ya no
	# alimenta ningun solver: el neutral "arriba" se fue con el.
	_look_at_target.global_position = aim_target_world

## Escritura procedural de la columna (ADR-0008).
## Lee la base animada del frame, suma el offset de apuntado (pitch sobre el
## eje X local del esqueleto, pesado por influencia) y escribe. Corre diferida
## para aterrizar despues del mezclador. Alcance T02: solo spine_02, solo
## pitch. El reparto por eje y spine_01 son T03 / trabajo futuro.
##
## QUE SE MIDE DEPENDE DEL ESTADO DE APUNTADO (issue 12). Son dos metas
## distintas, asi que necesitan medir cosas distintas:
##
## - Apuntando: la boca tiene que llegar a la mira, asi que se mide la boca.
##   Sensor: el forward del hueso del arma es su -Y, NO su -Z. Medido en ARMED
##   y en AIMING, con el escritor apagado: el marcador MUZZLE del asset (la
##   boca real) coincide con el -Y del hueso ik_hand_gun a 0.00 deg, y con el
##   -Z a 90.00 deg. El -Z del hueso apunta al piso, asi que leerlo hacia al
##   escritor a "corregir" un error de 90 grados que no existe y dobla el torso
##   hacia atras en cada fotograma.
##
## - Armado: el rifle va en la cadera y NO esta apuntado a proposito, con el
##   canon unos 21 grados hacia abajo. Esa inclinacion es la postura, no un
##   error. Medir la boca ahi hacia a inventar un error de 21 grados constante
##   y a pelear con una postura que esta bien. Ademas la camara no puede ser la
##   medida: medido con el escritor activo y rotando spine_02 +20 grados a
##   mano, la boca se movia 13.83 deg y la direccion de la camara 0.00. Lo que
##   un servo mide tiene que depender de lo que el servo mueve. Por eso en
##   ARMED se mide el eje del propio spine_02 y la camara queda de destino.
func _write_spine_pose() -> void:
	if _skeleton == null or _aim_controller == null:
		return
	if _spine02_idx == -1 or _gun_bone_idx == -1:
		return
	if _current_influence < INFLUENCE_EPSILON:
		return

	var state: AimState = _aim_controller.get_aim_state()
	if state == null or not state.is_valid:
		return

	var pitch_delta: float = 0.0
	if _is_aiming():
		pitch_delta = _aiming_pitch_delta(state)
	else:
		pitch_delta = _armed_pitch_delta(state)
	if absf(pitch_delta) < 0.0001:
		return

	var spine_pose: Transform3D = _skeleton.get_bone_global_pose(_spine02_idx)
	# La base global incluye los ancestros; la escritura es local. Conjugar
	# para no contar los ancestros dos veces (el sesgo constante vino de ahi).
	var local_q: Quaternion = _skeleton.get_bone_pose_rotation(_spine02_idx)
	var to_local: Quaternion = (spine_pose.basis.get_rotation_quaternion() * local_q.inverse()).inverse()
	var rotated: Quaternion = to_local * Quaternion(Vector3.RIGHT, pitch_delta) * to_local.inverse() * local_q
	_skeleton.set_bone_pose_rotation(_spine02_idx, rotated)

## Sensor de APUNTADO: la boca del arma contra la direccion de apuntado. Pitch
## en el plano YZ local: ignora el yaw (T03), ignora el roll.
func _aiming_pitch_delta(state: AimState) -> float:
	var aim_local: Vector3 = (_skeleton.global_transform.basis.inverse() * state.aim_direction).normalized()
	if aim_local.is_zero_approx():
		return 0.0

	var gun_pose: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx)
	var gun_fwd: Vector3 = -gun_pose.basis.y.normalized()
	var a := Vector3(0.0, gun_fwd.y, gun_fwd.z)
	var b := Vector3(0.0, aim_local.y, aim_local.z)
	if a.length() < 0.001 or b.length() < 0.001:
		return 0.0
	a = a.normalized()
	b = b.normalized()
	var sin_t: float = (a.cross(b)).x
	var cos_t: float = a.dot(b)
	return atan2(sin_t, cos_t) * _current_influence

## Sensor de ARMADO: cuanto esta el eje de spine_02 levantado o bajada, contra
## cuanto esta levantada o bajada la camara. La pose que se lee aqui es la que
## acaba de dejar el mezclador: el escritor escribe despues, asi que la lectura
## no incluye su propia correccion. Por eso la magnitud medida SI depende de la
## columna, que es lo que un servo necesita para poder converger.
func _armed_pitch_delta(state: AimState) -> float:
	var aim_world: Vector3 = state.aim_direction.normalized()
	if aim_world.is_zero_approx():
		return 0.0

	var spine_pose: Transform3D = _skeleton.get_bone_global_pose(_spine02_idx)
	var spine_fwd: Vector3 = -(_skeleton.global_transform.basis * spine_pose.basis).z.normalized()

	# Solo el canal de pitch, como en el sensor de apuntado: se ignoran el yaw
	# y el roll (alcance T02/T03) y con ellos la diferencia de 180 grados que hay
	# entre el eje del hueso y la direccion de apuntado en el mismo eje de yaw.
	# Medido en este esqueleto: el eje del hueso mira hacia atras en espacio
	# global, asi que el angulo entre los dos vectores da ~176 grados y no dice
	# nada. Lo que si dice es cuanto esta el eje levantado o bajado.
	var aim_pitch: float = asin(clampf(aim_world.y, -1.0, 1.0))
	var spine_pitch: float = asin(clampf(spine_fwd.y, -1.0, 1.0))

	# POR QUE EL SIGNO ES LA SUMA Y NO LA RESTA (issue 13).
	#
	# spine_fwd es el -Z del hueso, y ese eje MIRA HACIA ATRAS: su elevacion
	# es la negativa de la elevacion del frente real de la columna. Escribir
	# (aim_pitch - spine_pitch) comparaba la camara con un vector invertido y
	# por eso la correccion salia al reves: con la camara abajo el torso se
	# inclinaba atras. Medido con la metrica con signo (angulo del vector
	# spine_02 -> cuello contra el frente del personaje, positivo = inclinado
	# adelante), el regimen invertido daba -7.52 deg mirando al suelo y +1.50
	# mirando al cielo, y el el usuario lo vio jugando antes de esa medicion.
	#
	# La suma corrige lo mismo y deja el porque explicito: si E es la
	# elevacion del frente real de la columna, entonces spine_pitch = -E, y
	# el residuo E - aim_pitch que hay que anular es exactamente
	# -(aim_pitch + spine_pitch). No es un signo suelto: lo que esconde el
	# error es justamente el -Z que mira atras, y por eso queda escrito.
	var lean_residual: float = -(aim_pitch + spine_pitch)
	return lean_residual * _current_influence

func _process_modification_with_delta(_delta: float) -> void:
	if _skeleton == null or _spine01_idx == -1 or _spine02_idx == -1:
		return

	# Sin escrituras: en esta version del motor no aterrizan (ADR-0008).
	# Solo reintento de dependencias para el caso de montaje diferido.
	_resolve_dependencies()

	if _debug_f8_pressed:
		_debug_f8_pressed = false
		var _dbg_pitch := _get_camera_pitch()
		var _dbg_target := _look_at_target.position if _look_at_target != null else Vector3.ZERO
		prints("[SPINE_CTX] camera_pitch(deg):", rad_to_deg(_dbg_pitch),
			"  yaw(deg):", 0.0,
			"  influence:", _current_influence,
			"  target_pos:", _dbg_target)

	if _debug_spine_weapon_align_pressed:
		_debug_spine_weapon_align_pressed = false
		_debug_spine_weapon_align()
		var s1_idx: int = _spine01_idx
		var s2_idx: int = _spine02_idx
		if s1_idx != -1:
			var q1: Quaternion = _skeleton.get_bone_pose_rotation(s1_idx)
			var e1: Vector3 = q1.get_euler()
			prints("[SPINE] spine_01  q:", q1, "  euler(deg):",
				rad_to_deg(e1.x), rad_to_deg(e1.y), rad_to_deg(e1.z))
		if s2_idx != -1:
			var q2: Quaternion = _skeleton.get_bone_pose_rotation(s2_idx)
			var e2: Vector3 = q2.get_euler()
			prints("[SPINE] spine_02  q:", q2, "  euler(deg):",
				rad_to_deg(e2.x), rad_to_deg(e2.y), rad_to_deg(e2.z))

		if _look_at_target != null:
			var tip_global: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(s2_idx).origin if s2_idx != -1 else Vector3.ZERO
			prints("[TARGET_POS] look_at_target.global:", _look_at_target.global_position,
				"  spine_02_tip_world:", tip_global,
				"  tip→target_dist:", tip_global.distance_to(_look_at_target.global_position))

		# DIAGNOSTIC: skeleton-local target direction
		if _look_at_target != null and s2_idx != -1:
			var spine_pos_skel: Vector3 = _skeleton.get_bone_global_pose(s2_idx).origin
			var spine_pos_world: Vector3 = _skeleton.global_transform * spine_pos_skel
			var to_target_world: Vector3 = (_look_at_target.global_position - spine_pos_world).normalized()
			var local_dir: Vector3 = (_skeleton.global_basis.inverse() * to_target_world).normalized()
			prints("[DIAG_LOCAL_DIR] spine_02_pos(skel):", spine_pos_skel,
				"  to_target_world:", to_target_world,
				"  local_dir:", local_dir,
				"  local_dir.x:", local_dir.x,
				"  skel_basis:", _skeleton.global_basis)

		# DIAGNOSTIC: weapon-to-camera alignment
		var cc: CameraController = _aim_controller.camera_controller if _aim_controller != null else null
		if cc != null:
			var cam: Camera3D = cc.fps_camera if cc.using_fps else cc.tps_camera
			if cam != null and _gun_bone_idx != -1 and s2_idx != -1:
				var cam_pitch_deg := rad_to_deg(_get_camera_pitch())

				var spine_gpose: Transform3D = _skeleton.get_bone_global_pose(s2_idx)
				var spine_fwd: Vector3 = -spine_gpose.basis.z.normalized()
				var spine_pitch_deg := rad_to_deg(asin(clampf(spine_fwd.y, -1.0, 1.0)))

				# El forward del arma es el -Y del hueso, el mismo que usa el
				# sensor de arriba. Con -Z este readout reportaba el piso.
				var gun_gpose: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx)
				var gun_fwd: Vector3 = -gun_gpose.basis.y.normalized()
				var gun_pitch_deg := rad_to_deg(asin(clampf(gun_fwd.y, -1.0, 1.0)))

				prints("[PITCH_CHAIN]  cam: %+.2f°  spine02: %+.2f°  (Δ: %+.2f°)  weapon: %+.2f°  (Δspine: %+.2f°)" % [
					cam_pitch_deg, spine_pitch_deg, spine_pitch_deg - cam_pitch_deg,
					gun_pitch_deg, gun_pitch_deg - spine_pitch_deg])

				var gun_world: Vector3 = _skeleton.global_transform * gun_gpose.origin
				var gun_screen: Vector2 = cam.unproject_position(gun_world)
				var vp_size: Vector2 = get_viewport().get_visible_rect().size
				var center: Vector2 = vp_size / 2.0
				var screen_offset: Vector2 = gun_screen - center
				prints("[GUN_SCREEN]  pos: (%.0f, %.0f)  center: (%.0f, %.0f)  offset: (%.0f, %.0f)  dist: %.0f px" % [
					gun_screen.x, gun_screen.y, center.x, center.y,
					screen_offset.x, screen_offset.y, screen_offset.length()])

				var cam_fwd: Vector3 = -cam.global_transform.basis.z.normalized()
				var dot_wpn_cam: float = gun_fwd.dot(cam_fwd)
				prints("[WEAPON·CAM]  dot: %+.4f  angle: %+.2f°" % [
					dot_wpn_cam, rad_to_deg(acos(clampf(dot_wpn_cam, -1.0, 1.0)))])

# ============================================================
#  RESOLVE
# ============================================================

## Injects the player-owned external dependencies (composition root).
func configure(character: CharacterController, aim: AimController) -> void:
	_character_controller = character
	_aim_controller = aim

func _resolve_dependencies() -> void:
	if _character_controller == null and not character_controller_path.is_empty():
		_character_controller = get_node_or_null(character_controller_path) as CharacterController
	if _aim_controller == null and not aim_controller_path.is_empty():
		_aim_controller = get_node_or_null(aim_controller_path) as AimController
	if _look_at_target == null and not look_at_target_path.is_empty():
		_look_at_target = get_node_or_null(look_at_target_path) as Node3D
	if _weapon_root == null and not weapon_root_path.is_empty():
		_weapon_root = get_node_or_null(weapon_root_path) as Node3D

func _cache_bone_indices() -> void:
	_pelvis_idx = _skeleton.find_bone("pelvis")
	_spine01_idx = _skeleton.find_bone("spine_01")
	_spine02_idx = _skeleton.find_bone("spine_02")
	_gun_bone_idx = _skeleton.find_bone("ik_hand_gun")

# ============================================================
#  INFLUENCE
# ============================================================

func _compute_target_influence() -> float:
	if _character_controller == null:
		return 0.0
	if not _character_controller.has_main_hand_weapon():
		return INFLUENCE_UNARMED
	if _character_controller.is_effectively_aiming():
		return INFLUENCE_AIMING
	return INFLUENCE_ARMED

## Estado de apuntado real, no la influencia mezclada: decide que sensor se
## usa. Durante el traspaso manda el estado al que se va, no al que se venia.
func _is_aiming() -> bool:
	if _character_controller == null:
		return false
	return _character_controller.is_effectively_aiming()

func _blend_influence(delta: float, target: float) -> void:
	if delta <= 0.0:
		_current_influence = target
		return
	var alpha: float = 1.0 - exp(-INFLUENCE_BLEND_SPEED * delta)
	_current_influence = lerpf(_current_influence, target, alpha)
	if absf(_current_influence - target) <= INFLUENCE_EPSILON:
		_current_influence = target

# ============================================================
#  AIM
# ============================================================

func _get_camera_pitch() -> float:
	if _aim_controller == null:
		return 0.0
	var state: AimState = _aim_controller.get_aim_state()
	if state == null or not state.is_valid:
		return 0.0
	return state.look_pitch

func _get_aim_direction_local() -> Vector3:
	if _aim_controller == null:
		return Vector3(0.0, 0.0, -1.0)
	var dir: Vector3 = _aim_controller.aim_direction
	if dir == Vector3.ZERO:
		return Vector3(0.0, 0.0, -1.0)
	return (_skeleton.global_transform.basis.inverse() * dir).normalized()

# ============================================================
#  DIAGNOSTIC — Spine-Weapon Alignment
# ============================================================

func _debug_spine_weapon_align() -> void:
	if _aim_controller == null or _skeleton == null:
		return

	var state: AimState = _aim_controller.get_aim_state()
	if state == null or not state.is_valid:
		return

	var aim_dir_local: Vector3 = _get_aim_direction_local()

	var spine_fwd: Vector3 = Vector3.ZERO
	if _spine02_idx != -1:
		var spine_gpose: Transform3D = _skeleton.get_bone_global_pose(_spine02_idx)
		spine_fwd = -(_skeleton.global_transform.basis * spine_gpose.basis).z.normalized()

	var weapon_fwd: Vector3 = Vector3.FORWARD
	if _weapon_root != null:
		weapon_fwd = -_weapon_root.global_transform.basis.z.normalized()

	var body_yaw: float = 0.0
	if _character_controller != null:
		body_yaw = _character_controller.rotation.y

	var spine_dot: float = spine_fwd.dot(weapon_fwd)
	var spine_angle: float = rad_to_deg(acos(clampf(spine_dot, -1.0, 1.0)))

	prints("")
	prints("===== SPINE-WEAPON ALIGN =====")
	prints("[aim_dir_local] (%.4f, %.4f, %.4f)" % [aim_dir_local.x, aim_dir_local.y, aim_dir_local.z])
	if _look_at_target != null:
		prints("[lookat_target] (%.4f, %.4f, %.4f)" % [_look_at_target.position.x, _look_at_target.position.y, _look_at_target.position.z])
	else:
		prints("[lookat_target] NULL")
	prints("[spine_fwd]     (%.4f, %.4f, %.4f)" % [spine_fwd.x, spine_fwd.y, spine_fwd.z])
	prints("[weapon_fwd]    (%.4f, %.4f, %.4f)" % [weapon_fwd.x, weapon_fwd.y, weapon_fwd.z])
	prints("[body_yaw]      %.4f rad (%.2f deg)" % [body_yaw, rad_to_deg(body_yaw)])
	prints("[cam_pitch]     %.4f rad (%.2f deg)" % [state.look_pitch, rad_to_deg(state.look_pitch)])
	prints("[spine·weapon]  dot: %.6f  angle: %.2f deg" % [spine_dot, spine_angle])
	prints("================================")
	prints("")
