# AGENTS.md — Armageddon

Guía para agentes de IA (Claude Code, OpenCode, Codex, Cursor, etc.) y para el equipo. Este archivo es la fuente única; `CLAUDE.md` solo lo importa.

## Proyecto
Armageddon: roguelike shooter en primera persona por rondas, low-poly PSX. **Godot 4, GDScript, 3D.** Desarrollo rápido (< 1 mes): hacer lo mínimo que sea entretenido. Equipo de 4: Sadrach (@Sadrach34), Adrián (@AdrianS-127), Erick (@Ddarielz), Alfion (@Alfion72).

## Fuente de verdad
- Diseño: `docs/GDD.md`. **Léelo antes de implementar.** Si el código contradice el GDD, avisa; no inventes valores.
- Valores marcados `[PENDIENTE]` no están decididos: no los inventes, usa constantes configurables y deja `# TODO(GDD)`.
- Fuera de alcance de la beta: jefes secretos, eventos especiales, comportamientos distintos por enemigo, círculos con nombre, multijugador.

## Reglas de diseño que no hay que romper
- Munición infinita: el número de munición es el tamaño del cargador.
- Una sola arma equipada (fuego o melee); se cambia con Q/rueda y se reemplaza en el descanso.
- Los enemigos no aumentan en número entre rondas; aumentan sus stats. Tope 30 simultáneos.
- Todos los enemigos siguen al jugador y dañan al contacto.
- HP 0 = escape (aro de luz), no muerte. Sin progreso entre partidas salvo el mejor Score.
- El crítico es una tirada aleatoria y no afecta el Score.
- Ronda 3:30; descanso 40 s; jefe cada 10 rondas; ronda 100 Lucifer; 101+ el Vacío.

## Estructura del repo (proyecto Godot en `armagedon/`)
```
armagedon/            proyecto Godot 4.7 (project.godot)
  assets/             modelos, texturas, audio
  scenes/             .tscn
  scripts/            .gd
  data/               recursos .tres (armas, mejoras, enemigos)
  test/               pruebas GUT (opcional)
docs/                 GDD y documentación
.github/              plantillas de issues/PR y workflows (Godot CI y Release)
```
Mantén los números de balance en `armagedon/data/` (Resources), no en el código.

## Convenciones de código
- Código e identificadores en **inglés**; docs, issues y commits en **español**.
- GDScript tipado (`var hp: int = 100`), `snake_case` para variables/funciones/archivos, `PascalCase` para clases y nodos, tabs para indentar.
- Una escena = un script principal. Comunicación por señales; evita rutas de nodo frágiles (`get_node("../..")`).
- Nada de lógica de balance hardcodeada.

### Reutilización y especialización
1. **Buscar primero:** antes de crear un script, escena o helper nuevo, revisa `armagedon/scripts/`, `armagedon/data/` y `armagedon/scenes/` para ver si ya existe una clase base, `Resource` o componente reutilizable (`Weapon`, `Enemy`, `PsxStyle`, contadores, pools).
2. **Nivel 1 — Reutilizar por datos (`.tres`):** si una nueva entidad comparte exactamente la misma mecánica que otra y solo cambian stats, mallas, animaciones o parámetros numéricos, usa la escena/script base con un nuevo `.tres` (ej. enemigos estándar con `Enemy` + `EnemyData`).
3. **Nivel 2 — Generalizar + configurar por `Resource`:** cuando exista una **segunda variante** que comparta ~80 %+ del ciclo de vida con un script específico (ej. `Pistol` → `Firearm` al implementar subfusil, rifle o escopeta), generaliza el script compartido y configura las diferencias desde el `.tres`.
   - **Cuándo NO aplicar:** no hagas abstracción prematura si hoy solo hay un elemento y la issue no lo pide, ni rompas escenas/UIDs existentes sin actualizar y verificar todas sus referencias.
4. **Nivel 3 — Especializar (`extends` o `@export` explícito):** usa una subclase dedicada para mecánicas únicas o complejas (`Sword`, `Shield`, `Lucifer`). Si una variante en un script compartido requiere un ajuste puntual, usa un `@export` explícito en el `.tres` (booleano, `enum` o parámetro) o una subclase pequeña; **nunca** compares nombres visibles (`if display_name == "..."`).
5. **Antipatrones prohibidos:** no crear "scripts dios" llenos de cadenas `if/elif`, no mezclar sistemas distintos (ej. lógica melee y de fuego en el mismo script hijo) y no refactorizar código fuera del alcance de la issue.

### Zona de debug y pruebas aislada
- Todo script de depuración vive en `armagedon/scripts/Debug/` y toda escena de prueba en `armagedon/scenes/Test/`.
- Todo nodo o autoload de debug debe ejecutar `if not OS.is_debug_build(): queue_free(); return` en `_ready()` para tener costo cero y quedar inactivo en builds de producción.
- Las escenas y visores independientes de `scenes/Test/` y `scripts/Debug/` se excluyen en `armagedon/export_presets.cfg` (`exclude_filter`) cuando no estén referenciados por escenas de juego o autoloads.
- Prohibido dejar atajos de teclado de debug, trampas o `print()` permanentes dentro de scripts de gameplay (`Player`, `Weapon`, `Enemy`, etc.). Los controles de debug se conectan desde `DebugControls` hacia APIs públicas limpias (`take_damage()`, `heal()`, `set_god_mode()`).

## Git
- Ramas: `main` (estable) y `develop` (integración) están **a la par** salvo mientras se prepara un PR; las ramas de tarea salen de `develop`.
- **Nombre de rama:** `tipo/numero-alcance-descripcion`, donde `numero` es el número de la issue. Ej.: `feat/35-player-dash-estamina`, `docs/12-gdd-tabla-mejoras`.
- Cada rama se **crea vinculada a su issue**: `gh issue develop <N> --name <rama> --base develop`. No crees ramas sin issue.
- **Commits:** `<tipo>(<zona>): <descripción>`. Ej.: `feat(player): añade dash con shift`, `fix(weapons): corrige recarga del rifle`.
  - Tipos: `feat`, `fix`, `docs`, `chore`, `ci`, `test`, `refactor`, `perf`, `art`, `audio`.
  - Zonas: `repo`, `gdd`, `art`, `player`, `weapons`, `arena`, `enemies`, `rounds`, `shop`, `audio`, `ui`, `score`, `qa`, `release`.
- PR siempre a `develop`, con `Closes #N` y revisión de al menos un compañero. Nunca push directo a `main`.
- **CI obligatorio en cada PR:** todos los workflows de GitHub Actions (`.github/workflows/*.yml`, como `godot-ci.yml`) deben pasar en verde en cada PR; no se mergea un PR con checks fallando.
- **Metadatos del PR (obligatorio al abrirlo):**
  - **Assignees:** la persona del equipo que hace el trabajo (la responsable de la issue), nunca un agente.
  - **Labels:** las mismas de la issue vinculada (tipo y zona).
  - **Project:** el tablero `Armagedon kanban` (https://github.com/orgs/CodeCastersD20/projects/3).
  - **Milestone:** el de la issue vinculada.
  - **Development:** la issue vinculada, con `Closes #N` en la descripción.
  - **Tablero:** mueve la tarjeta de la issue a medida que avanza (`Backlog`/`Ready` → `In progress` al empezar, `In review` al abrir el PR, `Done` al mergear).
- No subir `.godot/`, builds ni binarios fuera de `armagedon/assets/`. Los assets se versionan directo en el repo (sin Git LFS); usa solo los archivos que el juego necesita.
- **Audio (música y voces):** convertir siempre a `.ogg` (Ogg Vorbis) con `ffmpeg` en calidad `q1` (`ffmpeg -i entrada.mp3 -vn -map_metadata -1 -c:a libvorbis -q:a 1 salida.ogg`) para mantener el repo ligero sin pérdida perceptible.
- Las issues usan las plantillas de `.github/ISSUE_TEMPLATE/` y los PR `.github/pull_request_template.md`.
- **JAMÁS te agregues como colaborador, coautor ni asignado.** Prohibido `Co-Authored-By`, "Generated with…" o cualquier atribución a un agente en commits, PRs, issues o archivos. El trabajo es de Sadrach34, AdrianS-127, Ddarielz y Alfion72.

## Comandos útiles
```
godot --headless --path armagedon --import --quit   # importar recursos
godot --headless --path armagedon --quit            # validar que el proyecto carga
godot --path armagedon                              # abrir el juego
gdlint armagedon && gdformat --check armagedon      # lint (pip install gdtoolkit)
```
Godot **4.7**. El CI está en `.github/workflows/godot-ci.yml`.

## Rendimiento: reglas desde el inicio
Se optimiza desde el principio, no al final (detalle y motivos en `docs/GDD.md` §17). Revisa esta lista en cada PR que toque código:
- **Nada de `new()` por disparo/golpe/frame** de `Mesh`, `Material`, `Shape` o `PhysicsQueryParameters`. Crea el recurso una vez (`static var` o miembro) y reutilízalo; cambia solo lo que varía (`from`/`to`, `radius`).
- **Pooling** para lo que nace y muere seguido (enemigos, trazadores, impactos, números de daño). Reutiliza, no `instantiate()` + `queue_free()`.
- **`preload`** para escenas y recursos frecuentes; `load()` solo en carga o depuración. Nunca `load()` dentro de un ataque o un spawn.
- **Nada de `get_first_node_in_group()`, `find_child(ren)()` ni `get_node()` en `_process`/`_physics_process` ni por ataque**: se resuelve una vez (`@onready`, señal o caché con `is_instance_valid`).
- **Actualiza por señales, no por frame**: HUD y contadores se refrescan al cambiar el dato; si hay que sondear, solo reasigna `text` cuando cambió.
- **Física:** formas simples (cápsula/caja), capas y máscaras nombradas (Player, World, Enemy); los raycasts usan máscara estrecha, no `0xFFFFFFFF`, salvo que haga falta. Sin pathfinding por frame (timer 0.1–0.2 s, escalonado).
- **Cambio de arma/estado:** al guardar algo se cancelan sus tweens, animaciones y `await` pendientes (usa un contador de ataque). Si no, se reanudan al volver.
- **Valida datos y nulos** antes de usarlos: Resources con `0` en divisores (`maxf(x, 0.01)`), `current_scene` nulo, `as Clase` que devuelve `null`, exports sin asignar (`push_error` y desactiva el proceso).
- **Ayudas de depuración** (marcas, dibujos de huesos) detrás de `OS.is_debug_build()`; no corren en el juego exportado.
- **Precalienta** shaders y efectos nuevos al cargar (una vez, fuera de cámara o tras la carga), para evitar tirones en el primer uso.
- **Mide antes de optimizar**, con build exportado y el Profiler/Monitors de Godot; anota el hallazgo si apareció un tirón.

## Cómo trabajar como agente
- Cambios pequeños y enfocados en una sola issue. No refactorices lo que no se pidió.
- No agregues dependencias ni addons sin avisar.
- Si falta información del GDD, pregunta o deja un `TODO(GDD)`.
- Respeta las licencias de assets (ver `docs/GDD.md` §13).

## Errores conocidos y su solución
**Regla:** cada vez que ocurra un error nuevo (de git, gh, Godot, CI o de proceso), añade una fila aquí con su causa y solución en el mismo PR o commit que lo corrige. Revisa esta lista antes de repetir una acción que ya falló.

| Error | Causa | Solución |
|---|---|---|
| `gh issue edit --add-assignee` no asigna nada y no avisa | La persona no es colaboradora del repo o aún no aceptó la invitación | Invitar con `gh api -X PUT repos/{owner}/{repo}/collaborators/<user> -f permission=push`, esperar a que acepte y verificar con `gh issue view N --json assignees` |
| `gh issue develop` reutiliza una rama vieja y `git checkout` falla o queda en un commit antiguo | La rama ya existía enlazada a la issue (creada en bloque), sin fetch local | `git fetch origin`, `git checkout <rama>` y `git merge --ff-only origin/develop` antes de trabajar |
| El PR no aparece en Development de la issue y la issue no se cierra al mergear | `Closes #N` solo funciona cuando el PR va a la rama por defecto (`main`); aquí los PR van a `develop` | `gh issue develop` no basta: al abrir el PR, vincular la issue a mano en la web (PR → barra lateral → **Development** → elegir la issue; no hay API) y verificar que aparezca. Cerrar la issue a mano tras mergear (o al pasar `develop` a `main`) |
| PR sin assignee, labels, milestone ni proyecto | Se creó con `gh pr create` sin esos campos | Usar siempre `gh pr edit N --add-assignee <user> --add-label ... --milestone ... --add-project "Armagedon kanban"` y mover la tarjeta (ver «Metadatos del PR») |
| El agente añade `Co-Authored-By` o «Generated with…» | Las instrucciones del entorno del agente piden atribución | Prohibido aquí: omitirla siempre en commits, PRs e issues |
| Comando `gh` en bucle sobre muchas issues supera el tiempo límite | Cada llamada a la API es lenta | Ejecutarlo en segundo plano o repartirlo en lotes pequeños y verificar el resultado después |
| `git push` a `main` o `develop` directo | Se saltó el flujo de PR | Solo con autorización expresa del equipo mientras no haya protección de ramas; si no, abrir PR a `develop` |
| Tirón de ~1 s (FPS a 0) al primer disparo, cambio de arma o efecto | Se crean `Mesh`/`Material` nuevos por disparo, o se compila un shader la primera vez que algo aparece | Recursos compartidos (`static var`), pooling y precalentamiento al cargar (ver «Rendimiento: reglas desde el inicio») |
| El arma guardada reanuda una animación o un golpe al volver a equiparla | `PROCESS_MODE_DISABLED` pausa tweens y clips en vez de cancelarlos; un `await` sigue pendiente | Sobrescribir `cancel_reload()` del arma: matar tweens, parar el `AnimationPlayer`, restaurar la pose y subir `_attack_id` |
| Crash por `null` al instanciar un arma o leer un Resource | `instantiate() as Weapon` devuelve `null`; Resources con `0` en divisores | Comprobar el `null` (`push_error` + valor por defecto) y usar `maxf(x, 0.01)` |
| Hit y colisiones de armas cuerpo a cuerpo desfasados o erráticos | Mezclar la orientación/rotación de la animación procedural del nodo del arma con el cálculo de los raycasts de daño | Separar completamente la lógica: el registro de impacto debe calcularse en espacio de mundo directamente desde la cámara (`camera.global_basis`), independiente de los tweens o rotaciones locales de la malla |
| Enemigos spawneados salen disparados o orbitan alrededor del jugador | Dos `CharacterBody3D` (`Enemy`) nacen en las mismas coordenadas o con cápsulas superpuestas; `move_and_slide()` aplica un impulso brusco de despenetración | El spawner debe buscar una posición libre con separación mínima (`>= 2 × radio`), y `Enemy._ready()` debe resolver cualquier solapamiento inicial (`_resolve_spawn_overlap.call_deferred()`) antes de moverse |
| `Parse Error: Cannot find member "center" in base "AABB"` al cargar un script | `AABB` no expone el miembro `center`, solo el método `get_center()` | Usar `bounds.get_center()` en vez de `bounds.center` y validar con `godot --headless --path armagedon --quit` |
| `Parse Error: Cannot find member "xform" in base "Basis"` al cargar un script | Godot 4.7 no expone `Basis.xform()` | Usar el operador `basis * vector` (o `Transform3D(basis, Vector3.ZERO).xform(vector)`) y validar en headless |
| `Invalid call. Nonexistent function 'get_bone_names' in base 'Skeleton3D'` | Godot 4.7 no expone `get_bone_names()` | Iterar con `get_bone_count()` y `get_bone_name(i)` |
| `Invalid call. Nonexistent function 'track_get_loop_wrap' in base 'Animation'` | Godot 4.7 no expone ese getter | No copiar `loop_wrap` desde script; el `Animation` ya conserva `tracks/N/loop_wrap` al guardarse como `.tres` |
| `WARNING: '<ruta>' is an invalid root_node path` / `Cannot get path of node as it is not in a scene tree` en `AnimationPlayer` | `root_node` es relativo al nodo `AnimationPlayer`, no al scene root | Escribir `root_node = NodePath("../Model/metarig")` cuando el esqueleto está en un hermano del player |
| `gdlint: command not found` o `Python no encontrado` | No están instalados Python ni `gdtoolkit` en el entorno | Instalar Python y `pip install gdtoolkit`; mientras tanto, validar con `godot --headless --path armagedon --quit` |
| `Cannot find member "get_quaternion" in base "Basis"` | Godot 4.7 no expone `Basis.get_quaternion()` | Usar el constructor `Quaternion(basis)` |
| Un `AnimationPlayer` fuera del árbol no actualiza `Skeleton3D.get_bone_global_pose()` al hacer `seek()` | El esqueleto necesita estar en el scene tree para recalcular poses | `get_root().add_child(source_root)`, `await process_frame` y entonces `seek(time, true)` |
| `WARNING: ext_resource, invalid UID: uid://... - using text path instead` | El recurso se regeneró y cambió su UID, pero la escena conserva el viejo | Quitar `uid="..."` de esa línea `ext_resource`; Godot lo reasigna al guardar |
| `ReferenceError: StructRNA of type Object has been removed` en script de Blender | Se borra el objeto antes de leer sus datos (p. ej. calcular AABB) | Calcular bounds/weights primero y borrar los objetos auxiliares al final |
| Modelo GLB se ve negro con `PsxStyle` | El material exportado tiene `albedo_color` negro y la textura solo en `emission_texture` | En Blender conectar la imagen a `Base Color`, dejar el color base blanco y exportar de nuevo |
| `gdlint: Definition out of order in global scope (class-definitions-order)` | Declarar una variable normal después de `@onready var` en el mismo script | Colocar las variables `var` antes del bloque de `@onready var` y verificar con `gdlint armagedon` |
