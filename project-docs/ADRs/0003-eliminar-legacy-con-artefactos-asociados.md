# Lo marcado como legacy y documentado en el código se elimina

## Estado

Aceptado — 2026-10-13.

## Contexto

La rama `weapon_system` arrastraba una acumulación de código y documentación
obsoletos que ningún consumidor alcanzaba, pero que se seguían incluyendo en el
razonamiento posterior:

- 4 input actions ligadas a `WeaponPositionController`, clase ya borrada.
- Nodos `GunMarker` y `AimTarget` sin una sola referencia.
- `Player/GLBs/mastercharacter.glb`, duplicado de 973 KB del GLB vivo.
- `AimState.to_dictionary` / `from_dictionary`: 77 líneas de serialización RPC
  especulativa, cero callers.
- Alias duplicados y funciones con cuerpo `pass`.
- Documentación de planificación (`plans/`) que describía sistemas eliminados
  y que un lector tomaba por vigente.
- `graphify-out/`, que indexaba ficheros ya borrados.

El patrón de fondo: cada vez que se borraba algo, el artefacto asociado —la
binding, el nodo, el perfil, el documento— se quedaba atrás. Sin una regla
explícita, la siguiente decisión se tomaba sobre ficción.

## Decisión

Cuando algo esté marcado como legacy **y** documentado en el código, se elimina
—binding, nodo, recurso, documento y entrada de documentación— en el mismo
cambio.

Un artefacto se considera vivo solo si tiene un consumidor. "Va a hacer falta más
adelante" no es un consumidor. Si hace falta, se reincorpora cuando exista la
necesidad, con el contexto que la motivó.

## Por qué

- Elimina la clase de bug en la que el historial y el código discrepan.
- Hace que "está obsoleto" sea una afirmación verificable, no una opinión.
- El coste de reincorporar algo es el commit que lo lee. El coste de mantenerlo
  es el razonamiento de cada sesión que lo encuentra.

## Consecuencias

- Los documentos de planificación dejan de rastrearse. Se conservan en disco
  pero fuera del índice de git.
- `AimState` pierde su serialización. Se reincorpora cuando exista un
  transporte real que la consuma, no antes.
- La limpieza se commitea **separada** del rediseño, para que el diff del
  rediseño sea legible.

## Lo que este ADR no cubre

No es una política de calidad de código. No exige cobertura de tests, ni
nombres consistentes, ni tipado. Solo cubre la eliminación de lo que ya no
tiene consumidor.