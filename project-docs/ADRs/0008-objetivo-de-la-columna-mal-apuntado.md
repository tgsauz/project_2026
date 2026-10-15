# Los solvers de IK no escriben huesos; la columna se escribe proceduralmente

## Estado

Aceptado — 2026-10-13. Sustituye la versión anterior de este ADR, que
atribuía la columna clavada a la ruta del objetivo. Esa atribución era
incorrecta y se retira.

## Contexto

Medido: la columna no responde al ratón (17.79° idénticos con pitch 0, +30
y −30). La primera hipótesis fue la ruta del objetivo (`../LookAtTarget`).
Falsada por medición:

- Las cuatro rutas de solver del proyecto resuelven desde su propio
  modificador. Ninguna base (propia o del esqueleto) produce movimiento:
  0.6° y 0.02° con el objetivo a 90° y 100 iteraciones.
- Un `TwoBoneIK3D` mínimo no se mueve, con pole o sin él (el pole es requisito
  documentado pero no es la variable operativa: sin él y con él, cero).
- Un modificador custom mínimo que escribe pose vía `set_bone_pose` en su
  callback: **0.00°** con 292 invocaciones/segundo.
- La misma escritura desde `_process` normal: **45.00°**.
- En el proyecto real, con animación activa: escritura `_process` compone
  +30° netos sobre la base animada.

Conclusión: en esta versión del motor, **ningún `SkeletonModifier3D`
escribe huesos** — ni custom ni de motor, ni CCDIK ni TwoBone. La escritura
directa desde `_process` sí funciona, con y sin animación. La animación
escribe huesos con normalidad; solo el camino modifiers→hueso está inerte.

## Decisión

La columna de apuntado se escribe proceduralmente desde `_process`:

1. Leer la base animada del frame.
2. Sumar el offset de apuntado (pitch/yaw con pesos separados).
3. Escribir el resultado.

Se reutiliza el nodo controlador de columna existente como dueño del cálculo;
cambia el mecanismo, no la topología. La fase escritor-vs-mezclador se
determina empíricamente en implementación: la escritura debe aterrizar
después del mezclador cada frame.

Se retira el nodo solver CCDIK de la columna. Se conserva el punto de mirada
como ancla visual (lo usa el visualizador y el debug).

## Por qué no pelear con el solver

Tres rondas de sondas variando base de resolución, iteraciones (hasta 100),
distancia mínima (0.0), topología de target y orden de configuración dieron
todas el mismo resultado: ~0°. El costo de una cuarta hipótesis supera al de
la vía procedural, que ya está medida funcionando (45.00° en mínimo, +30°
netos en proyecto con animación).

## Consecuencias

- El reparto pitch/yaw de ADR-0005 se implementa como dos pesos en matemática
  propia, no como influences de solver. Desaparece la limitación de
  "una sola influencia por cadena".
- Los brazos (TwoBone) quedan para trabajo futuro con la misma técnica
  cuando se activen (hoy fuera de alcance): solver custom en `_process` con
  plano de flexión fijo, sin nodo pole. El requisito documentado de pole
  sigue vigente para quien use el solver del motor.
- El neutral "arriba" desaparece con el solver: offset identidad cuando la
  influencia tiende a 0.
- El test de monotonía de T02 no cambia: es conductual y no depende del
  mecanismo. Sigue siendo el criterio.

## Corrección registrada

La versión anterior de este ADR afirmaba "target mal apuntado" como causa.
Medición posterior demostró rutas válidas y solvers inertes con cualquier
ruta. Se conserva el hallazgo útil (la clase "un nivel de más" existe como
riesgo) pero deja de ser la causa de este incidente.

## Evidencia

Sondas headless (eliminadas tras medir): diferencial influencia 1-vs-0 en
columna 0.0 m; CCDIK mínimo 0.6°/0.02°; TwoBone mínimo 0.0000 m con y sin
pole; escritor custom en callback 0.00° con 292 invocaciones; mismo escritor
desde `_process` 45.00°; en proyecto con animación +30° netos.
## Extensión a los brazos (T10, 2026-10-14)

La medición de este ADR se extiende más allá de la columna. Los `TwoBoneIK3D` de
brazos y el `CCDIK3D` de cabeza **tampoco escriben huesos**, por la misma razón
de motor. Medido: desplazar `RightHandIKTarget` 1 m produce `0.000000 m` de
movimiento en `hand_r`, con `active=true` e `influence=1.00`.

Por eso en T10 se borró la cadena de agarre de brazos entera (IK, `GripTarget`
y objetivos de mano) en vez de repararla: no había nada que reparar.

## Extensión a la cabeza (T12, 2026-10-14)

El mismo hallazgo se confirmó por tercera vez antes de borrar el sector de
cabeza: `HeadCCDIK` (un `CCDIK3D`) no escribe huesos. T12 lo borró junto con su
único objetivo, `AimIKTarget`, y con `FullBodyIKController.gd` entero (305
líneas que ya no tenían ninguna función viva), medido inerte por la misma vía.

Con T10 y T12, el recuento final es:

| Sector | Retirado en | Motivo |
|---|---|---|
| Columna (solver `CCDIK`) | ADR-0008 | ningún `SkeletonModifier3D` escribe huesos |
| Brazos (`RightArmIK`, `LeftArmIK`, `GripTarget`) | T10 | ídem, medido en `hand_r` |
| Cabeza (`HeadCCDIK`, `AimIKTarget`, `FullBodyIKController`) | T12 | ídem |

**Queda un solo escritor sobre el esqueleto:** `SpineLookAtController`, que
escribe `spine_02` desde `_process`. Sobrevive exactamente por eso: su escritura
está fuera del camino modificador→hueso que el motor tiene inerte. Esta es la
regla operativa que se hereda de este ADR para cualquier futuro solver: **si se
va a escribir un hueso, se escribe desde `_process`, no desde un
`SkeletonModifier3D`.**

Comprobación permanente: el test de humo afirma que el esqueleto lleva
exactamente un escritor vivo. Si algún día se cuela un segundo modificador, el
test lo delata sin necesidad de leer el código.
