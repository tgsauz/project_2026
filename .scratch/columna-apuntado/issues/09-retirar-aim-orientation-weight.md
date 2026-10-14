# 09: Retirar `aim_orientation_weight` (cero consumidores)

**What to build:** eliminar un valor que se calcula, se mezcla y se publica cada
frame, y que **nadie lee**. No es una funcionalidad a medias: es carga sin
consumidor.

Evidencia (grep sobre todo el repo, `.gd` y `.tscn`, excluyendo addons):

```
AimController.gd:28   var _aim_orientation_weight: float = 0.0
AimController.gd:65   _update_aim_orientation_weight(delta, is_ads)
AimController.gd:83-88  func _update_aim_orientation_weight(...)
AimController.gd:145  state.aim_orientation_weight = _aim_orientation_weight
AimState.gd:19        var aim_orientation_weight: float = 0.0
```

**Cuatro de esas cinco lineas son produccion; la quinta es el campo publicado.
No hay ni un solo lector.** No existe getter publico.

Es el mismo patron que `ads_weight`, que se retiro en T05 por exactamente esto
y quedo documentado en ADR-0007. Este salio como efecto colateral de T05 y nadie
lo reviso.

**Alcance:** solo `Player/Scripts/AimController.gd` y
`Player/Scripts/AimState.gd`. Nada mas. Si descubres que hace falta tocar otro
archivo, para y reportalo antes de editar.

**Que eliminar:**
- El campo `_aim_orientation_weight` de `AimController`.
- La funcion `_update_aim_orientation_weight()` y su llamada en `_process`.
- La asignacion `state.aim_orientation_weight = ...` dentro de `_build_aim_state`.
- El campo `aim_orientation_weight` de `AimState`.
- Los exports `aim_orient_enter_speed` y `aim_orient_exit_speed`, **junto con
  su `@export_category("Orientation Blend")`** si esa categoria queda vacia.

**Ojo, exports borrados y escenas.** Quitar un `@export` deja huerfana cualquier
propiedad que una escena tenga serializada. Antes de borrar, busca en los `.tscn`
del repo si `aim_orient_enter_speed` o `aim_orient_exit_speed` aparecen
serializados; si aparecen, hay que quitarlas tambien de esos archivos. Si no
aparecen en ninguna escena, dilo explicitamente en el mensaje del commit.

**Ojo, el comentario de cabecera de `AimState`.** Lista los consumidores del
estado. Verifica que la lista siga siendo cierta despues del cambio y ajustala
solo si el cambio afecta a esa lista (no deberia: `aim_orientation_weight` no
cambia quien consume `AimState`).

**How to verify:**
1. `grep -rn "aim_orientation_weight\|aim_orient_" --include=*.gd --include=*.tscn .`
   devuelve vacio.
2. Las seis suites en verde. La de humo es la que detecta contratos de nodos.
3. **Comportamiento intacto:** el FOV sigue transitando igual. Antes de editar,
   anota el valor del FOV sin apuntar y apuntando; debe ser 75.0 y 55.0. Es la
   comprobacion de que no rompiste nada colateral.
4. `AimState` sigue siendo `RefCounted` inmutable y con los campos que si se
   consumen (`look_pitch`, `look_yaw`, `aim_direction`, `fov_target`, etc.).

**Blocked by:** nada. Archivos disjuntos con T10, se pueden hacer en paralelo.

**Status:** ready-for-agent

- [ ] Los 4 puntos de eliminacion aplicados
- [ ] `grep` de `aim_orientation_weight` y `aim_orient_` vacio en `.gd` y `.tscn`
- [ ] Propiedades serializadas huerfanas: buscadas y reportadas (existan o no)
- [ ] FOV verificado identico antes y despues (75.0 / 55.0)
- [ ] 6/6 suites en verde
- [ ] Commit con mensaje que diga que no habia consumidores, con el grep como evidencia