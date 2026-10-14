# Especificación — Acoplamiento arma ↔ personaje: estado y pendientes

Síntesis de la sesión de diseño (grilling) y del trabajo ejecutado en la rama
`weapon_system`. Registra lo decidido con evidencia, lo pendiente con dueño, y
lo explícitamente fuera de alcance. Vocabulario según `GLOSSARY.md`.

## Problem Statement

El arma no se mantenía acoplada al hueso de soporte: se desplazaba hasta
46 cm y giraba más de 100° fuera del hueso al apuntar. Además, el sistema que
la posicionaba mezclaba tres fuentes distintas (animación, heurística
anatómica, capa de cámara), el IK de brazo no producía ningún efecto medible,
la consola acumulaba miles de errores por acciones de entrada perdidas, y la
documentación describía sistemas ya eliminados.

Desde el punto de vista del jugador: el arma flotaba, se torcía al apuntar, y
la mano izquierda no llegaba al guardamanos en apuntado.

## Solution

Un solo dueño para la pose del arma (el hueso de soporte), un solo canal para
el apuntado (la columna), cero cálculos intermedios, y un criterio de
aceptación numérico que falla en rojo si el acoplamiento se rompe. El trabajo
de Blender pendiente es autorizar la rotación del hueso en los clips de
apuntado y exportar limpio; el trabajo de código está completo y verificado.

## User Stories

### Acoplamiento (núcleo)

1. Como jugador, quiero que el arma esté exactamente donde dice el hueso de
   soporte, para que nunca flote ni se desplace.
2. Como jugador, quiero que el arma siga al torso al hacer pitch y yaw, para
   que apuntar mueva el arma con el cuerpo.
3. Como jugador, quiero que al pasar de cadera a apuntado el arma conserve su
   posición relativa al cuerpo, para que la transición no dé saltos.
4. Como jugador, quiero que el forward del arma coincida con el del hueso
   (máx. 2° en cadera), para que disparar de cadera vaya a donde apunta.
5. Como jugador, quiero recoger el arma del mundo y verla en la mano sin
   offsets invisibles, para que equipar sea predecible.
6. Como jugador, quiero desequipar el arma sin que queden restos del arma
   anterior, para que cambiar de arma no arrastre datos viejos.

### Autoría en Blender

7. Como animador, quiero que la orientación que autorizo en el hueso sea la
   que sale en el exportado, para que lo que veo sea lo que juega.
8. Como animador, quiero que los clips de apuntado tengan rotación propia del
   hueso, distinta de la de reposo, para que el arma se oriente al apuntar.
9. Como animador, quiero exportar solo armature + malla del cuerpo, para que
   el personaje no traiga un rifle congelado adentro.
10. Como animador, quiero una referencia visible de "recto" (vacío de
    referencia), para autorizar orientaciones exactas sin calcular contra el
    padre.
11. Como animador, quiero que no existan canales muertos que parezcan vivos,
    para no autorizar sobre el canal equivocado.

### Robustez del sistema

12. Como desarrollador, quiero un criterio de aceptación numérico que falle
    antes del rediseño y pase después, para no depender de afirmaciones.
13. Como desarrollador, quiero que ningún perfil de mano pueda escribir sobre
    la pose del arma, para que un dato futuro no reintroduzca el conflicto.
14. Como desarrollador, quiero una sola búsqueda de marcadores de agarre, para
    que no haya dos lecturas que puedan discrepar.
15. Como desarrollador, quiero que el arranque del juego tenga cero errores,
    para que el depurador muestre solo problemas reales.
16. Como desarrollador, quiero escenarios de prueba separados del contenido
    del juego, para probar sin riesgo de romper escenas.
17. Como desarrollador, quiero que la documentación vigente describa el código
    vigente, para decidir sobre hechos y no sobre ficción.

### Alcance futuro (no activo)

18. Como jugador, querré que en apuntado con mira la precisión sea mayor que
    en cadera, cuando se mida ese estado por separado.
19. Como jugador, querré ver ambas manos en los agarres al apuntar
    (RGRIP a 9.6 cm, LGRIP a 56 cm el 2026-10-13), cuando se reautorice ese
    clip.
20. ~~Como jugador, querré que el brazo corrija pequeñas desviaciones por IK,
    cuando el IK de brazo funcione.~~ *Reformulado 2026-10-14 (T10):* el IK de
    brazos no se va a reparar ni reimplementar tal cual. El problema de las
    manos se resuelve en Blender (re-autoría de los clips) y, si algún día se
    quiere IK, se diseña de nuevo sabiendo que los `SkeletonModifier3D` no
    escriben huesos en esta versión del motor.
21. ~~Como desarrollador, querré que el disparo use el estado de apuntado y no
    el pivote de cámara, cuando se toque el camino de disparo.~~
    *Retirada 2026-10-14 (T08):* el sistema de disparo y su recoil se borraron
    por completo. Esta historia queda sin objeto hasta que exista un camino de
    disparo nuevo, que se diseñará con hitreg desde cero (ADR-0010).

## Implementation Decisions

Decisiones tomadas (todas con evidencia medida, ver ADRs y diagnósticos):

- **El hueso de soporte es la autoridad de la pose del arma.** Transform
  completo, sin offsets ni constantes. Alternativas descartadas: runtime como
  autoridad (exigía reanimar) e híbrido (mantenía dos escritores).
- **El apuntado viene solo de la columna.** El ajuste vive en la escritura
  procedural de columna desde `_process` (ver ADR-0008); no hay capa de arma
  que lo duplique. Heredar la rotación del padre no es contaminación: es el
  canal por el que llega el apuntado.
  *Corrección 2026-10-14:* una versión anterior de este punto decía «el ajuste
  vive en el CCDIK de columna». Medición posterior (ADR-0008) demostró que
  ningún `SkeletonModifier3D` escribe huesos en esta versión del motor y que
  las cuatro rutas resuelven; la vía vigente es escritura procedural.
- **Sin IK de brazo por ahora.** Medido sin efecto (influencia 0 = 1); la
  animación es autoritativa, incluido entre clips.
- **Los clips de cadera no se tocan.** Verificados funcionando (marcador a
  ~6 mm de la mano); rehacerlos sería riesgo sin beneficio.
- **El 180° del asset del arma es corrección legítima.** No se corrige.
- **Montaje limpio por construcción:** el visual cuelga del nodo del arma con
  transformada identidad; ningún perfil de mano puede escribir encima
  (invariante en código, no dato configurable).
- **Búsqueda única de marcadores** de agarre; se eliminó la duplicada.
- **El arma no depende del controlador de apuntado ni escribe su estado.**
- **Documentación en español** bajo `project-docs/` (glosario, ADRs, docs);
  planificación vieja y artefactos regenerables fuera del índice.
- **Lo marcado legacy y documentado se elimina** con sus artefactos asociados,
  en commits separados del rediseño.
- **Limpieza antes que rediseño**, y mensajes de commit históricos corregidos
  cuando describían algo falso.

## Testing Decisions

Qué hace bueno un test en este sistema: **numérico, headless, y que falle
primero**. Ninguna afirmación sin número; ningún número sin test que lo exija.

- **Criterio de aceptación del acoplamiento** (arte previo: este mismo test).
  Compara arma contra hueso en posición (máx. 1 mm) y ángulo (máx. 2°) sobre
  pitch ±30° y yaw ±90°, conduciendo la fuente real (no el pivote). Fallaba
  10/20; pasa 20/20.
- **Suite de humo de dependencias** (arte previo). Contratos estructurales:
  ruta del esqueleto, orden de modificadores, flujo de estados de animación.
- **Verificación binaria del exportado** (arte previo: sondas de lectura
  directa del `.glb`). Compara rotaciones por clip entre exportados; detectó
  la rotación de reposo compartida y los objetos intrusos. Propuesto como
  protocolo fijo en cada reexportación.
- **Costuras propuestas** (a confirmar):
  1. El criterio de aceptación como única costura del acoplamiento (ya
     existe; no abrir costuras nuevas por debajo).
  2. ~~Boca del cañón contra dirección de apuntado al disparar (máx. 2° en
     cadera) — costura a la altura del evento de disparo, cuando se toque
     ese camino.~~ *Retirada 2026-10-14 (T08):* no hay evento de disparo.
     **Equivalente ya cubierto:** `spine_muzzle_convergence.gd` afirma la
     convergencia boca-vs-apuntado (0.00° medidos) sin necesitar disparar.
  3. Diferencial influencia-0-contra-1 del IK de brazo — el test que habría
     atrapado el IK muerto hace meses, para cuando se reconstruya.
     *Actualización 2026-10-14:* el IK muerto **ya está medido** (mover el
     objetivo 1 m produce 0.000000 m de movimiento en la mano). Falta el test
     que lo vigile; la costura sigue pendiente.

## Out of Scope

- Precisión en apuntado con mira (el criterio de 2° es solo cadera).
- Mano izquierda flotante en apuntado (aceptado como menor).
- Reconstrucción del IK de brazo: la causa **quedó aislada** (T10). Los solvers no escriben huesos en esta versión del motor, igual que la columna (ADR-0008). Se borró la cadena en vez de repararla.
- Replicación en red del estado de apuntado, agarre y arma.
- ~~Camino de disparo (sigue anclado a cámara; su migración es trabajo aparte).~~
  *Retirado 2026-10-14 (T08).* No queda nada ancorado: el camino de disparo se
  borró entero, incluido el recoil sin recuperación.
- Tuner de personaje, UI/inventario, y cualquier sistema no-arma.
- Guardar la fuente `.blend` en el repo (vive fuera; decisión no tomada).

## Further Notes

### Pendiente del usuario (Blender)

1. Reexportar excluyendo 5 objetos intrusos: la malla del rifle, sus 3
   vacíos de marcadores y el vacío de referencia. Es lo que hoy se ve como
   arma fantasma. **Hecho 2026-10-13**: export limpio verificado (51 nodos,
   1 malla, 12 animaciones) y rotaciones de apuntado autorizadas (51°/49°/43°
   distintas de reposo). Instalado y verificado.
2. **Reautorizar las MANOS en los 3 clips de apuntado.** Al rotar el hueso
   51° sin mover las manos al mismo nivel, los agarres se alejaron:
   RGRIP 7.5→9.6 cm, LGRIP 25→56 cm (medido en estado Aiming real). El hueso
   está bien; las manos quedaron obsoletas respecto a él. En Blender las
   manos se sostienen por IK (no se exporta): hay que bakear la pose de las
   manos a keys FK en esos 3 clips y reexportar. Criterio: RGRIP/LGRIP a
   <2 cm de su mano, como en cadera (~6 mm).
3. Confirmar si los cambios colaterales en clips no pedidos (p. ej. un clip
   desarmado con rotación de cadera) fueron intencionales. Sin impacto en
   juego (sin arma equipada no hay visual), solo higiene.
4. (Opcional) Borrar las curvas muertas de quaternion del hueso en todos los
   clips; se verifica como no-op desde el binario.

### Pendiente del agente (código), tras el reexport limpio

4. Verificar binario (rotación ≠ reposo, nombres intactos) + aceptación +
   humo, instalar el modelo y commitear.
5. Corregir el documento de causa raíz con los números finales.

### Deuda registrada, sin acción

- Brecha de ~6 líneas en el componente visual (versión previa al trabajo en
  el baseline; la función se reescribe en el rediseño de todos modos).
- Acoplamiento por nombre al ancestro del rig + rutas literales profundas en
  el ensamblador del rig.
- Resto sin efecto medible del IK de brazo, causa sin aislar.
