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

## Corrección registrada — 2026-10-14 (T12)

La decisión de este ADR no se aplicó por el camino previsto, y el fallo dejó
exactamente el problema que este ADR quería cerrar.

- **La exclusión de git no cubría `.opencode/`.** La regla de «se conservan en
  disco pero fuera del índice de git» se aplicó ignorando `/plans/` en la
  raíz del repositorio. Los documentos de planificación del agente viven en
  `.opencode/plans/` y en `.opencode/`, y **siguen versionados**: verificado con
  `git ls-files`, tanto `.opencode/plans/ik-architecture.md` como
  `.opencode/antigravity-weapon-context.md` están en el índice.
- **La consecuencia fue la temida por el propio ADR:** un lector tomaba por
  vigente una planificación que describe sistemas eliminados.
  `.opencode/plans/ik-architecture.md` (2026-06-04) describe siete sistemas de IK;
  a 2026-10-14 **solo sobrevive uno**.
- **Lo que se ha hecho en su lugar:** en vez de borrar (que el ADR sí permite,
  pero que destruiría el registro de por qué se decidió así), se les ha añadido
  una nota de cabecera muy visible con la fecha del contenido, el estado real del
  código y el recuento de sistemas caídos. Borrarlos es una decisión que sigue
  pendiente y **no** se toma aquí.
- **Abierto, sin resolver:** extender la exclusión de git a `.opencode/plans/` y
  desacoplar esa ruta de la lectura automática del agente. Requiere tocar
  `.gitignore` y la configuración del agente, fuera del alcance de una
  sincronización de documentación.