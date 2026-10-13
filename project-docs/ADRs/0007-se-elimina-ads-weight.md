# Se elimina ads_weight; el estado de apuntado es discreto

## Estado

Aceptado — 2026-10-13.

## Contexto

El sector de apuntado tiene **dos sistemas paralelos y desconectados** que
responden a la misma pregunta ("¿cuánto sigue la mirada?"):

1. **`ads_weight`** — continuo, 0→1, con amortiguación exponencial
   (`ads_enter_speed` 8.0, `ads_exit_speed` 10.0). Producido por
   `AimController`, viajando en `AimState`.
2. **`INFLUENCE_ARMED` / `INFLUENCE_AIMING`** — discreto, por estado, con su
   propia amortiguación (`INFLUENCE_BLEND_SPEED` 6.0). Vive solo en
   `SpineLookAtController`.

Medido tras el rediseño del arma: `ads_weight` tiene **un solo consumidor**,
en `FullBodyIKController.gd:313`:

```gdscript
_weight_targets["HeadCCDIK"] = lerpf(WEIGHTS_AIMING["HeadCCDIK"], 0.0, _aim_controller.get_ads_weight())
```

Y ese consumidor desaparece con ADR-0005 (la cabeza queda en influence 0).

Los otros consumidores potenciales ya no existen: `CameraController` lo dejó de
usar cuando se retiró el desplazamiento de cámara en ADS, y `WeaponController`
lo dejó de usar al reescribirse el posicionamiento.

`ads_weight` es plumbing de una generación anterior. ADR-0005 decide que el
comportamiento por estado de la cabeza no lo necesita, así que el sistema
continuo se va con él.

## Decisión

Se elimina `ads_weight` por completo: su campo en el estado de apuntado, su
producción en el controlador de apuntado, sus constantes de velocidad de
entrada y salida, y su único consumidor.

El estado de apuntado pasa a ser **discreto**: unarmed, armed, aiming. La
continuidad la aporta la amortiguación de cada sistema que reacciona al
cambio, no un peso compartido.

## Por qué el continuo sobra

Un peso continuo entre dos estadoswhose behaviors difieren solo cualitativamente
(no "un poco más de lo mismo") no aporta nada que la amortiguación por sistema
no dé mejor. Y su coste es una segunda fuente de verdad para "cuánto estamos
apuntando", que hoy vive en dos sitios con dos amortiguaciones distintas.

## Consecuencias

- Un solo lugar responde "cuánto sigue la mirada": la influence del sistema que
  rota ese hueso.
- La transición armed→aiming se mide en el comportamiento (el torso se dobla)
  y no en un número intermedio.
- Si algún día hace falta un ADS continuo (FOV, curva de puntería), se
  reintroduce **con un consumidor claro**, no por inercia.

## Relación con ADR-0005

Este ADR es la consecuencia de aquel: al dejar la cabeza sin influence, el
único consumidor de `ads_weight` deja de existir.

## Nota sobre el alcance

Esto no toca el FOV. `CameraController` aplica `state.fov_target`, que es otro
campo del estado de apuntado y no tiene relación con `ads_weight`. Si en el
futuro el FOV pasa a ser continuo con el mismo significado, se decide aparte.