# 12: El torso no sigue a la camara en ARMED

**What to build:** en estado armado, el torso debe inclinarse con la mirada. Hoy
no lo hace, y la sensacion es de algo a medio hacer.

## El sintoma que reporta el usuario

> "el pitch procedural del torso en Armed se ve y siente un poco raro, es como
> que no logra bajar con la camara"

Medido, barrido de pitch de camara de -30 a +30 en estado ARMED:

```
cam  -30 | COLUMNA  -11.7 | BOCA  -22.1 | apuntado  -30 | error  +7.90
cam  -15 | COLUMNA  -14.0 | BOCA  -21.8 | apuntado  -15 | error  -6.85
cam    0 | COLUMNA  -16.2 | BOCA  -21.6 | apuntado    0 | error -21.57
cam  +15 | COLUMNA  -18.3 | BOCA  -21.3 | apuntado  +15 | error -36.26
cam  +30 | COLUMNA  -20.6 | BOCA  -20.9 | apuntado  +30 | error -50.90
```

La camara se movio 60°. **La boca del arma se movio 1.2°.** Y la columna se movio
8.9° en direccion **opuesta** a la boca. Se estan moviendo al reves: eso es un
servo peleandose consigo mismo, y es lo que el ojo lee como glitch.

## La causa raiz

En ARMED el rifle **no esta apuntado a proposito**: se lleva en la cadera, con
el canon unos 21 grados hacia abajo. Eso es correcto.

El escritor no lo distingue. Mide "boca 21 grados abajo, camara al frente" y
concluye que hay un error de 21 grados que corregir. **Esta intentando arreglar
una postura que no esta rota.** Como solo tiene 0.15 de autoridad, no la arregla:
la amortigua. El resultado es que el seguimiento de la camara queda casi anulado.

## Por que la camara NO puede ser la medida (medido)

```
escritor activo, rotando spine_02 +20 grados a mano:
  la BOCA del arma se movio:          13.83 deg
  la DIRECCION DE LA CAMARA se movio:  0.00 deg
```

El escritor mide un error y lo corrige **rotando la columna**. Para converger, lo
que mide tiene que depender de la columna. La boca depende (20 grados de columna
-> 13.83 de boca). **La camara no depende en absoluto.**

Por eso la camara es el **destino**, nunca la medida. Si se usara como medida, el
servo miraria un numero que no cambia por lo que el hace, y aplicaria siempre la
misma rotacion: inclinacion fija, no seguimiento.

## El diseno

Son dos metas distintas y por eso necesitan medir cosas distintas:

| Estado | Que queremos que pase | Que se mide |
|---|---|---|
| Apuntando | que la **boca** llegue a la mira | la **boca** |
| Armado | que la **columna** se incline hacia donde se mira | la **columna en neutro** |

Implementacion: en `SpineLookAtController._write_spine_pose`, **la cantidad medida
depende del estado de apuntado**.

- Apuntando: se mide la boca, como hoy. **No se toca.** Error medido 0.00 en los
  cinco pitches.
- Armado: se mide la columna en su pose neutra (el forward del hueso `spine_02`
  tal como lo deja el clip, sin la correccion), contra la direccion de la camara.

El peso se mantiene en el `INFLUENCE_ARMED` actual (0.15). **No inventes otro
valor**: no hay medicion que justifique cambiarlo, y el usuario va a calibrarlo
jugando. Dejalo como esta y dilo en el mensaje del commit.

## TDD: el test va primero y debe quedar ROJO

Nuevo `Tests/Acceptance/spine_armed_follow.gd`. Debe fallar contra el codigo
actual. Si queda verde, esta mal escrito.

Asercion 1 — **el escritor no debe hacer nada en la neutra.** En ARMED, con la
camara en pitch 0, el delta que escribe debe ser ~0. Hoy escribe ~3.2 grados
constantes peleandose con la postura de cadera. **Esta es la asercion que
captura la causa raiz**, no un sintoma: es exactamente el error constante que el
servo se inventa.

Asercion 2 — **la boca sigue a la camara.** En un barrido de 60 grados de pitch,
la boca debe moverse al menos 5 grados en el mismo sentido que la camara. Hoy
mueve 1.2. El umbral de 5 no es inventado: sale del mecanismo
(0.15 de influencia x 0.69 de razon de transpaso x 60 = ~6.2 grados). Si mas
 adelante se calibra el peso, este umbral se revisa con el dato nuevo.

Asercion 3 — **respuesta monotona.** El pitch de la columna debeGrowing de forma
monotona con el pitch de camara. (Nota: hoy esto ya se cumple. Es red de seguridad,
no deteccion. Declara lo que es.)

## How to verify

1. El test nuevo queda **ROJO** antes de tocar codigo de juego. Reporta el fallo.
2. Tras el cambio, **VERDE**.
3. **AIMING intacto:** el error boca-contra-apuntado sigue en 0.00 en los cinco
   pitches. Es el invariante que no se debe romper. Si se mueve, **PARA**.
4. Las otras seis suites en verde.
5. En el mensaje del commit, tabular el barrido de ARMED antes y despues, con las
   mismas columnas de la tabla de este ticket, para que se vea el cambio.

**Lo que NO se toca:** la columna procedural en si, el sensor de AIMING, el peso
`INFLUENCE_ARMED`, los clips, y `HeadCCDIK`/`FullBodyIKController` (ya borrados).
No toques `project-docs/`.

**Bloqueado por:** nada.

**Status:** ready-for-agent

- [ ] Test en rojo antes de tocar codigo
- [ ] Asercion 1 (delta ~0 en la neutra) en verde
- [ ] Asercion 2 (boca >= 5 grados siguiendo a la camara) en verde
- [ ] Asercion 3 (monotonia) en verde
- [ ] AIMING sigue en error 0.00 en los cinco pitches
- [ ] 7/7 suites en verde
- [ ] Barrido ARMED antes/despues en el mensaje del commit
- [ ] `INFLUENCE_ARMED` sin tocar, y dicho explicitamente en el commit