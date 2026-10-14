# 08: Retirar el sistema de disparo y recoil

**What to build:** borrar el disparo y su recoil. Hoy están vivos, son
alcanzables desde el juego, y el recoil **no se recupera nunca**.

**Procedencia — no lo agregamos nosotros.** Commit `62dfad7`, autor `tgsauz`,
2026-06-25, rama `weapon_system`. `WeaponActionController.gd` **no existe en
`main`**. `git diff weapon_system..HEAD` sobre ese archivo y sobre
`CameraController.gd` sale vacío: cero cambios de nuestra parte. Se reporta
aquí para que conste, no para adjudicarlo.

**Alcance, verificado:**

| Qué | Dónde | Estado |
|---|---|---|
| `WeaponActionController.gd` (99 líneas) | `Player/Scripts/` | instanciado en `PlayerCharacter.tscn:67` |
| `_request_fire` → `_apply_local_recoil` | ídem | llama en cada disparo |
| `apply_recoil(pitch, yaw)` | `CameraController.gd:235` | suma directo a `fps_pitch` |
| Acción `primary_action` | `project.godot:93` | enlazada a click izquierdo |
| Acción de muzzle flash | `client_play_fire_effects` | sin usar |

**El bug medido:** cada disparo suma `randf_range(0.015, 0.025)` rad de pitch
(≈**+0.86° a +1.43°**) y el tope es `max_pitch` (+80°). **No hay ninguna
recuperación**: el ángulo se acumula para siempre.

```
antes de disparar:  cam_pitch = +0.0
tras 30 disparos:   cam_pitch = +34.4
+3 s sin tocar nada: cam_pitch = +34.4   <- no vuelve
```

`_can_fire()` pasa con cualquier arma equipada en la mano principal, así que
es alcanzable jugando: con un arma en mano, click izquierdo sube la cámara de
forma irreversible hasta +80°. Verificado que el path se dispara.

**Por qué importa más allá del annoyance:** cualquier puntería de columna
—esta o futura— hereda ese error. Con el torso siguiendo al cámara, +34° de
error se convierten en torso doblado. Es la amplifiedor del defecto visual que
se investigó en T07, no un annoyance aparte.

**Decisión pendiente para el chat nuevo — NO decidir aquí:** el pedido original
era "borrar disparo y recoil". Este ticket propone borrar **los dos** porque
el recoil no tiene consumidor una vez borrado el disparo, y `server_process_fire`
es RPC vacío de hitreg con un `pass` de placeholder. Si se quiere conservar el
disparo sin recoil (para hitreg futuro), eso es un ticket distinto: en ese caso
esta ticket se limita a `_apply_local_recoil` + `apply_recoil`. **Preguntar
antes de borrar el disparo.**

**Ojo — rotación 180° del Rig.** No aplica a este ticket. Se deja anotado solo
para que no se infiera que el recoil se compensa con la rotación: son sistemas
independientes (cámara vs. esqueleto).

**How to verify:**
1. Click izquierdo con arma equipada **no** mueve el `fps_pitch` (medir antes y
   después, no asumir).
2. `grep -rn "recoil\|_request_fire\|server_process_fire" --include=*.gd Player World`
   devuelve vacío.
3. La acción `primary_action` de `project.godot`: decidir si se retira también o
   se deja reservada. Si se deja, documentar por qué en el mensaje del commit.
4. Las cinco suites en verde (el disparo no participa en ninguna, pero
   `PlayerCharacter.tscn` se edita y hay que confirmar que no se rompió la
   escena).
5. `WeaponActionController.gd` borrado también de `PlayerCharacter.tscn:67`
   y de la lista `ext_resource` en `PlayerCharacter.tscn:9`.

**Blocked by:** nada. Independiente de T06/T07 — puede ir en paralelo.

**Status:** ready-for-agent

- [ ] Decisión tomada y anotada: borrar disparo, o solo recoil
- [ ] Click izquierdo con arma no altera `fps_pitch` (medido)
- [ ] `grep` de `recoil` / `_request_fire` / `server_process_fire` vacío
- [ ] Nodo y `ext_resource` retirados de `PlayerCharacter.tscn`
- [ ] `project.godot` revisado: acción `primary_action` retirada o documentada
- [ ] Las cinco suites en verde
- [ ] ADR posterior que registre la retirada (el sistema de disparo se
      reimplementará con hitreg cuando haya decisión de diseño)