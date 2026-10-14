# El torso twist hasta un límite antes de que gire el cuerpo

## Estado

Propuesto — 2026-10-13. Comportamiento objetivo; fuera del incremento actual.

## Contexto

Hoy el cuerpo (`CharacterController`) lleva el yaw completo de golpe: el
personaje gira entero en cuanto el ratón pasa de un píxel. Es funcional y es
lo habitual en un prototipo, pero produce dos cosas que en un shooter
acaban mal:

1. **Se pierde la sensación de peso.** Un giro instantáneo de 180° no tiene
   inercia visual ni anticipación.
2. **No hay lectura de intención.** El jugador no puede inferir hacia dónde va
   a girar el cuerpo solo con mirar el torso.

Los shooters de referencia reparten: el torso twist hasta un límite angular
(~±35-45° respecto al cuerpo), y solo cuando el límite se supera el cuerpo
completa el giro. Opcionalmente, el torso ejecuta un giro animado en el eje
para "alcanzar" al objetivo antes de que el cuerpo se mueva.

## Decisión (objetivo)

El yaw se reparte entre torso y cuerpo:

1. El torso twist siguiendo el yaw de cámara, hasta un límite de ±L grados
   respecto al torso.
2. Al superar el límite, el cuerpo completa el resto, y el torso vuelve al
   centro.
3. Opcionalmente, una animación de twist cuando el torso alcanza el límite.

El cuerpo **deja de** llevar el yaw completo.

## Por qué no ahora

Tres cosas deben estar resueltas antes:

1. **El torso twist comparte el problema del pitch**: hoy la columna no
   responde (modifiers inertes — ver ADR-0008, no problema de ruta) y su peso
   es por estado, no por eje. Arreglar el pitch no arregla el yaw
   automáticamente, y al revés.
   *Corrección 2026-10-14:* la redacción anterior decía «el CCDIK de la
   columna no resuelve su target»; premisa sustituida por ADR-0008.
2. **El límite L debe medirse**: hay que ver a qué ángulo la pose de locomoción
   (caminar, correr, strafear) deja de ser creíble con el torso girado.
3. **El solape entre torso y cuerpo debe repartirse con precisión**: si ambos
   giran a la vez, el total se pasa y los dos movimientos se transparentan.
   Necesita una función de reparto explícita, no dos multiplicadores.

## Riesgo

Añadir twist de torso sin haber implementado la escritura procedural de la
columna (ADR-0008) produce un torso que no sigue la cámara — el caso peor,
donde el torso se clava en un ángulo y el jugador solo puede girar en el
rango que el fix permite.
*Corrección 2026-10-14:* la redacción anterior pedía «arreglar el target del
CCDIK»; la vía vigente es procedural.

## Relación con ADR-0005

ADR-0005 fija el comportamiento **actual y temporal** (cuerpo lleva el yaw,
torso sin twist). Este ADR fija el comportamiento **objetivo**. No se
contradicen: uno describe el incremento, el otro la dirección.

## Dependencias

- La columna debe escribirse proceduralmente desde `_process` (T02 del
  overhaul de la columna; ver ADR-0008).
- El reparto de yaw necesita pesos separados por eje en la matemática propia
  (T03), no influences de solver: al ser procedural, el reparto por eje es
  trivial.
  *Corrección 2026-10-14:* la redacción anterior pedía «target del CCDIK» e
  «influence separada por eje»; premisa sustituida por ADR-0008.
