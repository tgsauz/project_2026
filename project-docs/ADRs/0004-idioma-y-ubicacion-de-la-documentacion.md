# Idioma y ubicación de la documentación

## Estado

Aceptado — 2026-10-13.

## Contexto

El repositorio acumuló cuatro fuentes en competencia de documentación, en dos idiomas,
con contradicciones entre sí y con el código:

| Ubicación | Idioma | Estado real |
|---|---|---|
| `plans/00-06` | Inglés | Intención canónica; secciones §6.2, §8.2, §8.5, §8.8 superadas por el código y nunca actualizadas |
| `.opencode/*.md` | Inglés | Scratch de agente; `ik-architecture.md` describe una generación eliminada |
| `project-docs/docs/` | Inglés | 19 documentos canónicos, **borrados** en el WIP |
| `project-docs/Docs/` | Español | Describe la realidad actual con exactitud |

`project-docs/` es un vault de Obsidian. El rename de `docs/` a `Docs/` rompió
todas las referencias cruzadas, y `graphify-out/` seguía indexando los ficheros
borrados.

## Decisión

**Idioma.** Toda la documentación del proyecto, incluidos ADRs y glosario, se
escribe en español. Los nombres de identificadores en código permanecen en
inglés.

**Ubicación.** `project-docs/` es la raíz documental:

```
project-docs/
├── GLOSSARY.md      vocabulario del dominio
├── ADRs/            decisiones, numeradas 0001-, 0002-, …
└── Docs/            documentación vigente
```

**Alcance de la fuente.** `plans/` y `.opencode/*.md` no son fuente de verdad.
`graphify-out/` es un artefacto regenerable y deja de rastrearse.

**Regla de contradicción.** Cuando el código y la documentación discrepan, se
actualiza la documentación primero. Es la regla ya existente en `AGENTS.md`, y
el WIP la incumplió.

## Por qué

Tres fuentes competidor obligaban a cada sesión a determinar cuál era vigente
antes de poder trabajar. Consolidar en un árbol con un propósito por carpeta
hace que la pregunta "dónde miro" tenga respuesta.

## Consecuencias

- Los documentos borrados no se recuperan. Dos de ellos contenían decisiones
  vivas sin copia en otro sitio: `15 - Aiming and Weapon States.md` (contrato de
  stance de arma) y `17 - Engine Coordinate Standards.md` (el estándar `-Z`).
  Ambas están ahora en `GLOSSARY.md` y en ADR-0002 respectivamente.
- Los ADRs solo se crean cuando la decisión es **dura de revertir**, **sorprendente
  sin contexto**, y el resultado de un **trade-off real**. Sin las tres, no hay
  ADR.

## Nota

Los ADRs se escriben **después** de decidir, no antes. Un ADR escrito antes de
la decisión es ficción.