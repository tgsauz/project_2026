# 11: Arreglar el test flaky de los rayos (`spine_visual_rays`)

**What to build:** que `Tests/Acceptance/spine_visual_rays.gd` deje de fallar al
azar. El defecto es del arnes de prueba, no del juego.

## El sintoma

Falla de forma intermitente. Medido en 6 corridas consecutivas:

```
corrida 1: fallos: 2  FALLA        corrida 4: fallos: 0  PASA
corrida 2: fallos: 0  PASA         corrida 5: fallos: 0  PASA
corrida 3: fallos: 0  PASA         corrida 6: fallos: 2  FALLA

  - Rayo de camara: origen a 0.5390 m de su fuente (max 0.0050)
  - Rayo de boca:   origen a 0.5390 m de su fuente (max 0.0050)
```

## La causa

Dos hechos encadenados:

1. **El test no pone suelo.** Su `_initialize()` solo hace `instantiate()` y
   `add_child()`. Las otras tres suites si crean un `StaticBody3D` con un
   `BoxShape3D` debajo.
2. **Sin suelo, el cuerpo cae.** `CharacterController` es un `CharacterBody3D`:
   su `_physics_process` llama a `_apply_gravity()` y a `move_and_slide()`. Sin
   nada debajo, acelera hacia abajo indefinidamente.

**El test compara posiciones** (origen del rayo contra origen de la camara, con
tolerancia de 5 mm). El visualizador calcula y cachea sus rayos en su
`_process`; el test los lee despues desde el bucle del `SceneTree`. Entre el
calculo y la lectura, **el cuerpo ya se cayo**. La distancia recorrida depende
del momento exacto en que cae cada prueba, de ahi que sea intermitente.

El dato que lo confirma: **los dos rayos fallan con exactamente el mismo error**
(0.5390 m). Un error de orientacion daria dos numeros distintos. Es una
traslacion del cuerpo, no un error de eje.

## Que hacer

Anadir el suelo al `_initialize()` del test, con la misma forma que ya usan las
otras tres suites:

```
Tests/Acceptance/weapon_coupling_acceptance.gd
Tests/Acceptance/spine_yaw_head_stillness.gd
Tests/Acceptance/spine_muzzle_convergence.gd
```

Copia su patron. No inventes uno nuevo: la consistencia es el punto.

**Revisa tambien `Tests/Acceptance/spine_pitch_response.gd`.** Este tampoco
pone suelo. Hoy no falla porque mide angulos (invariantes a la traslacion), pero
es la misma trampa latente: si alguien lo cambia para medir una posicion,
empieza a fallar al azar. Anota el hecho en el commit; no hace falta tocarlo si
no quieres.

**Cuidado con lo que NO es el bug:** el fallo ocurre con el escritor
correcto y con el buggy por igual. No es un regresion de T02 ni de T10. Ya se
caracterizo antes y despues de cada uno de esos tickets con la misma firma
(0.5390 m).

**No "arregles" el visualizador.** El visualizador esta bien: dibuja lo que las
fuentes dicen. Lo que falla es la lectura en un cuerpo que se cae.

## How to verify

1. **10 corridas seguidas del test, todas en verde.** Ese es el criterio de
   aceptacion: si una sola falla, no esta arreglado. Reporta el conteo real.
2. Las otras cinco suites en verde.
3. Ninguna suite cambia de comportamiento: el arma sigue en 0.0000 m y la boca
   contra apuntado en 0.00 grados.

**Blocked by:** nada. Archivos disjuntos de todo lo demas.

**Status:** ready-for-agent

- [ ] Suelo anadido al `_initialize()`, con el patron de las otras tres suites
- [ ] 10/10 corridas en verde (reportar el conteo, no afirmar)
- [ ] Las otras 5 suites en verde
- [ ] `spine_pitch_response.gd` evaluado y anotado en el commit
- [ ] Commit que explique la causa (cuerpo en caida libre) y la prueba del 0.5390