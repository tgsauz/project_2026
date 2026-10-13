---
title: Cambios — Retirada de ADSProfile y passthrough RMB experimental
type: changelog
status: aplicado
date: 2026-10-02
engine: Godot 4.7.2
scope: retirar capa ADS no conectada y permitir RMB en el banco experimental
tags:
  - weapon
  - aim
  - input
---

# Cambios — Retirada de ADSProfile y passthrough RMB experimental

## Cambios

- Eliminados `WeaponADSProfile`, `WeaponLayerADS`, el recurso de prueba vacío `TestWeaponADSProfile.tres` y `ADSBlendState`.
- Retirados el campo `ItemDefinition.weapon_ads_profile` y los setters/getters de perfil que no tenían consumidores.
- Conservados `AimController` (peso de apuntado, dirección y FOV), `WeaponLayerAim` y la ruta de entrada existente.
- Solo al ejecutar `weapon_ik_test_experimental.tscn`, se marca el árbol de controles del crosshair como `MOUSE_FILTER_IGNORE`; el banco normal y el UIRoot del juego no se modifican.

## Justificación

La capa de perfil no estaba conectada desde los items y el recurso de perfil de prueba estaba vacío. Su retirada no elimina la ruta base de apuntado ni el cambio de FOV, que ya pertenecen a `AimController`/`CameraController`. `ADSBlendState` duplicaba interpolación ya realizada por `AimController` y no tenía consumidores después de retirar `WeaponLayerADS`.

Los controles decorativos del centro del crosshair tenían `MOUSE_FILTER_STOP` por defecto. Como el juego captura el cursor al centro y el apuntado se procesa en `_unhandled_input`, podían consumir el RMB antes del personaje. El cambio de filtro es deliberadamente local al arnés experimental para que el test aísle esa hipótesis sin alterar las escenas de juego.

## Fuera de alcance

No se cambió la orientación ni la desviación del arma, su base forward, los offsets de montaje, la animación, el IK ni la alineación al crosshair. La escena experimental sigue siendo un test visual, no una decisión de producción.

## Validación

- Búsqueda en `.gd`, `.tscn` y `.tres`: sin referencias a `WeaponADSProfile`, `WeaponLayerADS`, `ADSBlendState`, `weapon_ads_profile` ni sus APIs.
- Smoke runner `godot --headless --script res://Tests/Smoke/dependency_smoke_runner.gd`: `Dependency smoke tests passed.` (reporta fugas de objetos/RID al terminar, existentes en el runner de teardown; no hubo fallo del test).
- `weapon_ik_test_experimental.tscn`: carga/equipa sin errores; RMB entregado por `run_scene` y cambio visible de pose.
- Prueba de input en el centro de viewport vía `Input.parse_input_event`: RMB press → `is_aiming=true`, `aim_orientation_weight=0.974`, `ads_weight=0.913`; release → `is_aiming=false` y ambos pesos vuelven hacia cero.
- No se modificó el forward/orientación del arma.
