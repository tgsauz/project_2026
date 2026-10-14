# 01: Costura de test para nodos del sector del rig

**What to build:** un test de regresión que verifica que existen los nodos
que el sector del rig necesita: punto de mirada (hijo del esqueleto),
objetivos de brazos y de cabeza (hijos del rig), y nodo del arma en el
jugador (runtime, con esperas). Corre headless junto a la suite de humo
existente.

Corrección respecto al borrador: la primera versión afirmaba las rutas
contra la base del esqueleto. Medido: las cuatro rutas resuelven desde su
propio modificador y ninguna base produce movimiento — la base no es la
variable operativa. Este ticket ya no afirma ninguna base: solo existencia.
Es red de regresión para los tickets que retiran nodos (T02 retira el
solver pero debe conservar el punto de mirada).

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] El test existe y corre headless sin infraestructura nueva
- [ ] Pasa en el código actual (es red de seguridad, no detector)
- [ ] Cubre punto de mirada, tres objetivos, y nodo del arma
- [ ] La suite de humo existente sigue en verde
**Done:** e1ea9cb feat(T05): retirada de ads_weight + prioridad de lectura pen
