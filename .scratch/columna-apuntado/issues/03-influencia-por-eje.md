# 03: Influencia por eje en la columna, cabeza aislada a 0

**What to build:** descomponer el offset procedural en pitch y yaw con pesos separados, con
la cabeza quieta en los tres estados (posición transitoria según ADR-0005,
para aislar el efecto de la columna). Sin spike: al ser matemática propia y
no solver, el reparto por eje es trivial (dos pesos, no uno). La cabeza
queda quieta por omisión — no se le escribe nada.

**Blocked by:** 02 (necesita columna reactiva para modular).

**Status:** ready-for-agent

- [ ] Entrada solo-yaw NO mueve yaw de columna (variación < 1°): el cuerpo
  lo absorbe (verificar que el cuerpo sí giró, para no medir quietud falsa)
- [ ] Cabeza quieta dentro del mismo estado ante barrido de yaw (pose local
  estable < 1°): nadie le escribe proceduralmente
- [ ] Suites existentes en verde
