# 13: Corregir la inversion del torso en ARMED

**What to build:** en ARMED el torso se inclina al reves. Hoy se lo corrigio en
T12, pero con el signo invertido. El usuario lo vio jugando antes de que
nosotros lo midieramos: "cuando con la camara miro al suelo, el personaje rota
para mirar hacia arriba".

## La causa raiz

En `SpineLookAtController._armed_pitch_delta`:

```gdscript
var spine_pitch: float = asin(clampf(spine_fwd.y, -1.0, 1.0))
return (aim_pitch - spine_pitch) * _current_influence
```

`spine_fwd` es el **-Z** del hueso, y el propio comentario del archivo admite que
ese eje **mira hacia atras**. Medir la elevacion de un vector que apunta hacia
atras invierte el signo del regimen: cuando el torso se inclina adelante, ese
-Z se levanta; cuando se inclina atras, se baja. La correccion sale al reves.

## La medicion que lo demuestra

Metrica con signo: angulo del vector spine_02 -> cuello, medido contra el frente
del personaje. **Positivo = inclinado adelante, negativo = inclinado atras.**
Esta metrica si distingue los dos casos, a diferencia de la elevacion.

Estado actual (codigo de este ticket, sin tocar):

```
ARMED    cam -30 ->  -7.58  atras
         cam -15 ->  -5.37  atras
         cam   0 ->  -3.16  atras
         cam +15 ->  -0.87  atras
         cam +30 ->  +1.46  adelante      <-- INVERTIDO

AIMING   cam -30 -> +40.98  adelante      <-- correcto
         cam   0 -> +10.98  adelante
         cam +30 -> -19.02  atras         <-- correcto
```

AIMING esta bien y **no se toca**. Es el metodo de referencia.

## Que cambiar

El signo de la correccion en la rama de ARMED. Invierte la resta para que:

- camara abajo  -> torso se inclina **adelante** (mas)
- camara arriba -> torso se inclina **atras** (mas)

Preferible un cambio explicito y comentado antes que un signo suelto. Si
invertir el orden de los operandos no basta, negate el resultado y explica por
que en un comentario: lo que no vale es dejar un `-` sin razon escrita, porque
la razon es justamente el -Z que mira atras.

**Ojo:** invertir el signo tambien invierte el orden de la tabla. El resultado
esperado tras el arreglo es el espejo del actual:

```
ARMED    cam -30 ->  +7.58  adelante
         cam   0 ->  +3.16  adelante
         cam +30 ->  -1.46  atras
```

Es una comprobacion de que quedo bien: los numeros deben salir con el signo
cambiado y la misma magnitud.

## El test que faltaba (esta es la parte importante)

`Tests/Acceptance/spine_armed_follow.gd` **pasa en verde con el comportamiento
invertido**. Su asercion de monotonia no lo puede detectar: una inversion tambien
es monotona. Ese es el agujero.

La asercion que faltaba es la de **direccion con signo**. Anade, ademas de lo que
ya hay:

- Mide el torso con la metrica con signo: angulo del vector `spine_02` -> cuello
  contra el frente del personaje (`-player.global_basis.z`), es decir
  `atan2(v.forward, v.up)`. Positivo = adelante.
- En ARMED, **`lean(cam -30) > lean(cam +30)`**: mirar al suelo tiene que inclinar
  el torso MAS adelante que mirar al cielo.
- El mismo test debe comprobar la misma desigualdad en AIMING, y ahi **ya se
  cumple** (+40.98 contra -19.02). Es la red que demuestra que no rompimos el
  metodo de referencia.

**Esta asercion tiene que dar ROJO contra el codigo actual.** Si das verde sin
tocar el codigo de juego, el test esta mal y hay que rehacerlo. Pega el fallo.

**Ademas:** revisa que ninguna otra asercion del test dependa del signo antiguo.
La asercion 1 (desplazamiento en la neutra ~0) no deberia verse afectada;comprueba
que sigue valiendo.

## How to verify

1. Test ROJO antes de tocar codigo. Pega el numero.
2. Test VERDE despues.
3. **AIMING intacto:** la desigualdad de signo tambien se cumple en AIMING, y el
   error boca-contra-apuntado sigue en 0.00 en los cinco pitches.
4. Las 7 suites en verde.
5. En el mensaje del commit, la tabla ARMED antes/despues con la metrica con
   signo, para que se vea el espejo.

## Lo que NO se toca

- La rama de AIMING. Es el metodo correcto y el usuario lo confirmo.
- `INFLUENCE_ARMED`: sigue en 0.15. La magnitud esta bien; lo que estaba mal era
  el signo. **No cambies el peso en este ticket.**
- La geometria del torso en AIMING, que se inclina 40.98 adelante mirando abajo.
  Es大的 y quizas se vea raro, pero es el comportamiento que el usuario dio por
  bueno. Otro ticket, otro dia.
- Clips, `project-docs/`, escenas.

**Bloqueado por:** nada.

**Status:** ready-for-agent

- [ ] Test ROJO antes de tocar codigo de juego, con el numero pegado
- [ ] Asercion de direccion anadida, con la metrica con signo
- [ ] La asercion se cumple tambien en AIMING
- [ ] Signo corregido, con el PORQUE escrito en un comentario
- [ ] Asercion 1 (neutra ~0) sigue valiendo
- [ ] AIMING: error boca-contra-apuntado 0.00 en los cinco pitches
- [ ] `INFLUENCE_ARMED` sin tocar
- [ ] 7/7 suites en verde
- [ ] Tabla ARMED antes/despues en el mensaje del commit