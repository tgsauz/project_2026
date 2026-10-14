# Se retira el sistema de disparo y recoil hasta que exista decisión de hitreg

## Estado

Aceptado — 2026-10-14.

## Contexto

El sistema de disparo estaba vivo y era alcanzable jugando: con un arma en la
mano principal, el click izquierdo pasaba `_can_fire()` y disparaba.

Medido antes de retirar nada, 30 clicks con el arma equipada, headless:

```
  fps_pitch antes:              +0.00 deg
  fps_pitch tras 30 disparos:   +31.85 deg
  fps_pitch +3 s sin tocar nada:+32.81 deg   <- no vuelve
```

Cada disparo sumaba `randf_range(0.015, 0.025)` rad de pitch (+0.86° a
+1.43°) y **no existía recuperación**: el error se acumulaba para siempre
hasta el tope de `max_pitch` (+80°).

Por qué importa más allá del annoyance: con la columna siguiendo a la cámara
(ADR-0008), +32° de error de cámara se convierten en torso doblado. Era el
amplificador del defecto visual de ADR-0009, no un annoyance independiente.

## Procedencia

No lo escribimos nosotros. Commit `62dfad7`, rama `weapon_system`.
`git diff weapon_system..HEAD` sobre `WeaponActionController.gd` y sobre
`CameraController.gd` sale vacío.

## Decisión

1. Se borra `Player/Scripts/WeaponActionController.gd` completo: `_request_fire`,
   `server_process_fire` (RPC de hitreg con `pass` de placeholder),
   `client_play_fire_effects` (acción de muzzle flash sin uso) y
   `_apply_local_recoil`.
2. Se borra `apply_recoil` de `CameraController.gd`. `fps_pitch` y `fps_yaw`
   vuelven a ser solo la entrada del ratón, sin otras fuentes que los muevan.
3. Se retiran el nodo `WeaponActionController` y su `ext_resource` de
   `Player/PlayerCharacter.tscn`.
4. Se retira la acción `primary_action` de `project.godot`. Se queda **sin
   reservas**: no la hereda nadie, el click izquierdo no hace nada en el
   juego y dejarla declarada sería un input map que miente sobre lo que el
   juego hace. Se re-declara cuando exista el sistema de disparo nuevo, con
   su nombre definitivo.

El disparo no se conserva "para hitreg futuro". Un RPC vacío con un
`apply_damage(10.0)` de placeholder no es hitreg: es una forma de tener código
muerto pareciendo código vivo, y cualquier puntería de columna futura
heredaría su error.

## Verificación

Medido después de retirar, mismo guion de 30 clicks con arma equipada:

```
  fps_pitch antes:              +0.00 deg
  fps_pitch tras 30 disparos:   +0.00 deg
  fps_pitch +3 s sin tocar nada:+0.00 deg
```

`grep -rn "recoil\|_request_fire\|server_process_fire\|primary_action\|WeaponActionController" --include=*.gd --include=*.tscn --include=*.godot Player World project.godot`
devuelve vacío. Las seis suites de aceptación y de humo en verde.

## Consecuencias

- No hay forma de disparar en el juego. Es intencional: el sistema vuelve con
  hitreg, tasa de fuego, munición y feedback de impacto, que son decisiones
  de diseño que todavía no existen.
- El click izquierdo queda libre para otra acción futura sin quedar atado a un
  controlador retirado.

## Por qué es un ADR

Borrar código que funciona (o que finge funcionar) es una decisión que otro
lector va a revertir sin contexto, igual que la del eje del hueso en ADR-0009.
Sin este registro, el próximo ve un arma sin disparo y lo arregla.

## Evidencia

`.scratch/columna-apuntado/issues/08-retirar-disparo-y-recoil.md`, commit
`62dfad7`, mediciones de fps_pitch antes y después registradas arriba.
