# 05: Retirada de ads_weight

**What to build:** eliminar el campo del estado de apuntado, su producción y
velocidades en el controlador de apuntado, y su único consumidor vivo. El
estado de apuntado queda discreto (ADR-0007). Sin cambio de comportamiento:
la cabeza ya está en 0 por T03.

**Blocked by:** 03 (su único consumidor atenúa la cabeza; aterrizar antes
subiría la cabeza a 0.35 en apuntado y contradiría el reparto decidido).

**Status:** ready-for-agent

- [ ] Cero menciones restantes en código
- [ ] Suites en verde sin cambio de comportamiento observable
- [ ] El FOV sigue funcionando (campo independiente, no tocado)
