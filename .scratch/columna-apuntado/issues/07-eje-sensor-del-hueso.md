# 07: Corregir el eje sensor del escritor (-Z → -Y)

**What to build:** una corrección de una línea en el escritor de columna. Hoy
lee el eje equivocado del hueso de soporte y por eso dobla el torso 90° hacia
atrás cada frame mientras apunta.

Causa raíz medida, no supuesta. La boca del rifle coincide con el **-Y** del
hueso `ik_hand_gun` a **0.0°**, y con el **-Z** a **90.0°**, tanto en ARMED
como en AIMING (mismo hecho, dos estados). El escritor usa `-Z`:

`Player/Scripts/SpineLookAtController.gd`, en `_write_spine_pose`:

```gdscript
var gun_pose: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx)
var gun_fwd: Vector3 = -gun_pose.basis.z.normalized()
```

`-gun_pose.basis.z` apunta al piso. El sensor queda 90° desviado del alvo, así
que el escritor "corrige" un error que no existe. Medido:

```
escritor ON : pitch_delta = -90.0 deg cada frame | spine_02 a reposo 83.6 deg
escritor OFF: (no escribe)                     | spine_02 a reposo 51.0 deg
```

Es decir: el clip del artista está **correcto**. En `holding_aim` la boca está
horizontal (`-Y` a 0.0°) y los brazos en posición de apuntado. El defecto es
100% del sensor.

Consecuencia de arrastre, medida (A/B escritor ON vs OFF):

```
            spine_02   clavicle_r   neck    head
OFF (clip)    51.0        51.0       46.6    30.1
ON  (+bug)    83.6        83.6       72.4    71.5
```

`clavicle_r` es hijo directo de `spine_02` (el hueso lo tiene 0 vértices
asignados y no se escribe): hereda la rotación exacta. De ahí los hombros,
brazos, cuello y cabeza girados ~90° que se ven en pantalla.

**Ojo — rotación 180° del Rig.** El nodo `Rig` lleva 180° sobre Y (ADR-0002,
legítimo, **no tocar**). El cambio de eje NO requiere compensarlo: solo cambia
qué eje del hueso se lee, y el signo del pitch no depende de esa rotación. Pero
sí exige que la aserción nueva mida en **espacio global**, o el test dará el
error con el signo invertido.

**How to verify:**
1. Correr el test de T06: debe pasar a **verde**.
2. `weapon_coupling_acceptance`: 20/20.
3. Suite de humo: verde.
4. `spine_yaw_head_stillness` y `spine_visual_rays`: verdes.
5. **Medición nueva obligatoria:** el `pitch_delta` que imprime el escritor
   debe ser ≈0 en la horizontal (el clip ya apunta bien). Si sigue dando
   ≈-90°, el eje está mal cambiado otra vez.
6. **Medición del torso:** anotar el ángulo de `spine_02` a reposo con el
   escritor activo. Volver a T06 y fijar ahí la tolerancia con el dato real.
7. Anotar también cuánto queda de pitch en cuello y cabeza con el escritor
   corregido — determina si el resto del complaint de cuello/cabeza es del
   clip y necesita reautoría en Blender.

**Ojo — no arreglar de más.** Solo el eje. No tocar el conjugation de espacios,
ni las prioridades de proceso, ni el setter granular: los tres están medidos y
funcionan (convergencia -0.00° en la pasada anterior). Si el torso queda
dentro de un rango razonable pero el cuello sigue doblado, eso es otro ticket
(reautoría de clips), no parte de este.

**Blocked by:** 06 (necesita el test rojo para probar el verde).

**Status:** ready-for-agent

- [ ] El sensor pasa de `-basis.z` a `-basis.y` del hueso de soporte
- [ ] T06 en verde
- [ ] `pitch_delta` ≈0 en la horizontal (medido, no supuesto)
- [ ] `spine_02` sin el pliegue de 90° (medido)
- [ ] Las cinco suites en verde
- [ ] Tolerancia de torso fijada en T06 con el dato medido
- [ ] ADR posterior que registre el eje correcto del hueso (ADR-0002 sigue vigente)