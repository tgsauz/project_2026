# `.opencode/` — configuración del asistente, no del juego

## Qué hay aquí

`opencode.json`, `plugins/`, `skills/` y `node_modules/` son **herramientas**.
No forman parte del juego y no se necesitan para ejecutarlo.

## La regla importante

**Este directorio no contiene arquitectura del sistema.**

Antes de este trabajo contenía dos documentos grandes de contexto e
arquitectura de IK. Se borraron el 2026-10-15, y con ellos una advertencia que
conviene tener presente:

> Escritos con formato "arquitectura del sistema", esos documentos describían
> 7 sistemas de IK de los que **solo sobrevive uno**. Un agente que los leyera
> construiría exactamente el sistema que ya fue demolido.

Si alguna vez se vuelve a escribir un documento de contexto aquí, que lleve en
la primera línea su fecha y qué parte de lo que describe ya no existe.

## Dónde vive la documentación de verdad

- `project-docs/ADRs/` — decisiones, con su fecha y sus correcciones
- `project-docs/GLOSSARY.md` — vocabulario del dominio
- `project-docs/Docs/` — especificaciones e informes (los que llevan fecha son
  registros históricos)

## Los planes no se versionan

`.opencode/plans/` y `/plans/` están en `.gitignore` por decisión de ADR-0003.
La regla original solo cubría `/plans/` de la raíz, así que `.opencode/plans/`
siguió versionado durante meses sin que nadie lo notara: exactamente el fallo
que ese ADR quería cerrar. Corregido el 2026-10-15.