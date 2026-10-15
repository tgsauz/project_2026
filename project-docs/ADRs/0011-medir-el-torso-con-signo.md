# 0011: Medir el torso con signo, y las trampas que ya nos costaron tiempo

**Estado:** vigente
**Fecha:** 2026-10-15

## Decision

Toda medicion de inclinacion de un hueso del rig se hace con **componente con
signo**, nunca con elevacion sola. Y antes de dar por buena cualquier
afirmacion sobre este rig, se comprueban las trampas de la seccion siguiente.

## Por que: la elevacion es ciega al signo

Una inclinacion medida como `asin(vector.y)` (la elevacion) **no distingue
inclinarse adelante de inclinarse atras** cuando el vector esta cerca de la
vertical. Las dos dan numeros parecidos.

Esto no es teorico. Pasó dos veces en este trabajo:

1. Se concluyo que "el torso esta recto, +2.1 grados" midiendo el segmento
   `pelvis -> spine_02`. Ese segmento es **invariante por construccion** a la
   rotacion de `spine_02`: no puede detectar lo que se le pedia medir.
2. Se concluyo que "el signo no esta invertido, el torso responde bien" midiendo
   la elevacion de `spine_02 -> cuello`. **Estaba invertido.** El usuario lo vio
   jugando: mirando al suelo, el personaje se inclinaba atras.

La metrica correcta es el angulo con signo respecto al frente del personaje:

```gdscript
var v: Vector3 = (cuello_global - spine02_global).normalized()
var frente: Vector3 = -player.global_basis.z
var inclinacion: float = rad_to_deg(atan2(v.dot(frente), v.dot(Vector3.UP)))
# positivo = inclinado adelante, negativo = inclinado atras
```

## Trampas del rig, todas medidas

| Trampa | Sintoma | Regla |
|---|---|---|
| Forward del arma | El `-Z` del hueso esta a **90 grados** del cañón | El forward es el **`-Y`** de `ik_hand_gun` (ADR-0009). Comparar siempre contra el marcador `MUZZLE` del asset, nunca contra un eje del hueso |
| Los solvers no escriben | Configurados, con peso, `active=true`, y no mueven nada | Ningun `SkeletonModifier3D` escribe huesos en esta version del motor (ADR-0008). Medido: mover el objetivo 1 m produce `0.000000 m` |
| `set_bone_pose` completo | El arma se va **1.17 m** de sitio | Invalida los globales del subarbol. Usar solo el setter granular de rotacion |
| Base global escrita como local | Sesgo constante de **-2.67 grados** | La base global incluye los ancestros. Conjugar los espacios antes de escribir |
| `call_deferred` | Rompe las lecturas cruzadas del frame | Escribir directo en `_process`, con `process_priority` para ordenar contra el mezclador |
| Rotacion 180 en Y del Rig | Conjugada con cualquier rotacion sobre X, **invierte el signo** (ADR-0002) | Medir en un solo espacio. Si se mezclan espacio del esqueleto y global, el pitch sale con el signo cambiado |

## Un test circular no es un test

`spine_pitch_response.gd` comparaba el pitch del hueso contra el apuntado, que
es exactamente la magnitud que el escritor optimiza: pasaba por construccion
con el torso doblado 90 grados. Y `spine_armed_follow.gd` compruebo monotonia, que
una inversion tambien cumple.

Regla que se sigue de ahi: **un test no puede medir la premisa que el codigo
asume.** La medida de referencia tiene que venir de una fuente independiente
(un marcador del asset, un hueso hijo, la geometria del mundo), nunca del mismo
eje que usa el escritor.

## Consecuencias

- Las correcciones se verifican con dos metricas: magnitud y sentido. Falta una
  de las dos, no esta verificado.
- Cuando una cifra sale distinta de la esperada, **el primer sospechoso es la
  metrica**, no el codigo. Se escribe el porque de la correccion en un
  comentario: un signo suelto es justo lo que esconde un error de regimen.

## Lo que sigue abierto

Con influencia 1.0, la rama de apuntado lleva el torso 1:1 con la camara: mirando
30 grados abajo se inclina **41 grados adelante**, y mirando 30 arriba, 19 atras.
No se considera incorrecto (es el metodo que el usuario dio por bueno), pero
ningun test lo vigila hoy. Registrar un fallo asi necesita una asercion de
rango maximo, no solo de monotonía.