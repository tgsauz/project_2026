# 02: Columna reactiva (ruta + neutral + monotonía)

**What to build:** la columna responde al pitch del ratón de forma monótona,
y no se mueve con el ratón quieto al cambiar de estado de apuntado. Mecanismo
(ADR-0008): escritura procedural desde `_process` — leer la base animada,
sumar el offset de apuntado, escribir — reutilizando el nodo controlador de
columna existente. Se retira el solver CCDIK (inerte) pero se conserva el
punto de mirada como ancla visual. La fase escritor-vs-mezclador se determina
empíricamente: la escritura debe aterrizar después del mezclador cada frame
(medido: escrituras con timing de script sobreviven con +30° netos).

Corrección respecto al borrador: no se "corrige la ruta" (las rutas están
bien) ni se tocan iteraciones del solver (irrelevante sin solver). El neutral
"arriba" desaparece con el solver: offset identidad cuando la influencia
tiende a 0.

**Blocked by:** 01 (su aceptación usa esa costura).

**Status:** ready-for-agent

- [ ] Test de monotonía: el ángulo de columna varía monótonamente con el pitch
- [ ] Ratón quieto + cambio de estado = columna quieta
- [ ] La costura de T01 pasa
- [ ] Suites existentes en verde
