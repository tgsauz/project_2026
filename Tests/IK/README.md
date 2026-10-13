# Weapon / IK Test Harness

Banco de pruebas **permanente** para inspeccionar el acople del arma y el IK de brazos
sin tener que recoger el arma manualmente.

## Archivos
- `res://Tests/IK/weapon_ik_test.tscn` — banco base (arquitectura actual).
- `res://Tests/IK/weapon_ik_test_experimental.tscn` — variante experimental, aislada y reversible.
- `res://Tests/IK/weapon_ik_test.gd` — arnés (auto-equipa + diagnóstico).
- `res://Tests/IK/WeaponLayerSocketPositionTest.gd` — capa experimental usada solo por el banco.
- `res://Tests/IK/weapon_ik_transform_investigation.md` — registro de análisis, mediciones, experimentos y pendientes del acople arma/IK.

## Cómo usarlo
1. Abre y ejecuta `res://Tests/IK/weapon_ik_test.tscn`.
2. Al arrancar **equipa automáticamente el arma** en `right_hand` y **arranca en 3ª persona**
   para ver el cuerpo, los brazos y el arma.
3. Controles:
   - **F3** → alternar FPS / TPS (`toggle_camera`).
   - **Ratón** → orbitar la cámara (TPS).
   - **J** → diagnóstico de alcance IK del proyecto (`debug_ik_reach`), se imprime en consola.
   - **Clic izq. (`primary_action`)** → disparar.
   - **F (`interact`)** → interactuar.
4. En el Inspector del nodo raíz `WeaponIKTest`:
   - `Weapon Definition` → cambia el arma a testear.
   - `Weapon Slot` → `right_hand` / `left_hand`.
   - `Start Third Person` → arrancar en TPS o FPS.
   - `Print IK Diagnostic` → imprime el diagnóstico IK automáticamente a los 0.25 s.

## Prueba experimental: socket puro

Ejecuta `res://Tests/IK/weapon_ik_test_experimental.tscn` para aislar el acople, sin modificar escenas de juego ni Testing World:

- **Transform del arma:** `WeaponRoot` recibe directamente `skeleton.global_transform * ik_hand_gun.global_pose`.
- **Sin correcciones:** no hay compensación por `RGRIP`, reconstrucción de basis, eliminación de roll ni capa `WeaponLayerAim`.
- **IK:** `GripTarget` sigue derivándose de los marcadores del arma; el solver no se modifica.
- **Apuntado:** queda fuera de esta prueba para no contaminar la comparación con una orientación hacia cámara.

La hipótesis es que el asset fue exportado para que su raíz coincida con `ik_hand_gun`. Si el arma presenta un offset en esta prueba, ese resultado revela una discrepancia real entre marcos (socket, raíz, geometría o export), no una corrección aplicada por el harness. Esta variante solo cambia el banco experimental. El crosshair conserva el `MOUSE_FILTER_IGNORE` local para que el input del banco no interfiera.

En la prueba de socket puro, la capa de aim se retira deliberadamente; no usar RMB como criterio de esta comparación. Primero verifica el montaje en reposo. El comportamiento de torso/arma al apuntar arriba/abajo se investigará después, en una prueba separada.

## Notas
- La esfera **verde** flotante es el gizmo del `LookAtTarget` (debug del rig), no un error.
- La escena replica el mundo de `testing_world` (suelo, entorno, luz, `UIRoot`) para que el
  comportamiento refleje el juego real.
- El arnés usa la ruta interna de la cámara (`CAMERARIG._set_camera_mode(false)`) para
  arrancar en TPS; es el mismo camino que dispara la tecla F3.