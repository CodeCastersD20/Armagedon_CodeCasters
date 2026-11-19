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

## Git
- Ramas: `main` (estable) y `develop` (integración) están **a la par** salvo mientras se prepara un PR; las ramas de tarea salen de `develop`.
- **Nombre de rama:** `tipo/numero-alcance-descripcion`, donde `numero` es el número de la issue. Ej.: `feat/35-player-dash-estamina`, `docs/12-gdd-tabla-mejoras`.
- Cada rama se **crea vinculada a su issue**: `gh issue develop <N> --name <rama> --base develop`. No crees ramas sin issue.
- **Commits:** `<tipo>(<zona>): <descripción>`. Ej.: `feat(player): añade dash con shift`, `fix(weapons): corrige recarga del rifle`.
  - Tipos: `feat`, `fix`, `docs`, `chore`, `ci`, `test`, `refactor`, `perf`, `art`, `audio`.
  - Zonas: `repo`, `gdd`, `art`, `player`, `weapons`, `arena`, `enemies`, `rounds`, `shop`, `audio`, `ui`, `score`, `qa`, `release`.
- PR siempre a `develop`, con `Closes #N` y revisión de al menos un compañero. Nunca push directo a `main`.
- **Metadatos del PR (obligatorio al abrirlo):**
  - **Assignees:** la persona del equipo que hace el trabajo (la responsable de la issue), nunca un agente.
  - **Labels:** las mismas de la issue vinculada (tipo y zona).
  - **Project:** el tablero `Armagedon kanban` (https://github.com/orgs/CodeCastersD20/projects/3).
  - **Milestone:** el de la issue vinculada.
  - **Development:** la issue vinculada, con `Closes #N` en la descripción.
  - **Tablero:** mueve la tarjeta de la issue a medida que avanza (`Backlog`/`Ready` → `In progress` al empezar, `In review` al abrir el PR, `Done` al mergear).
- No subir `.godot/`, builds ni binarios fuera de `armagedon/assets/`. Los assets se versionan directo en el repo (sin Git LFS); usa solo los archivos que el juego necesita.
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
| Hit y colisiones de armas cuerpo a cuerpo desfasados o erráticos | Mezclar la orientación/rotación de la animación procedural del nodo del arma con el cálculo de los raycasts de daño | Separar completamente la lógica: el registro de impacto debe calcularse en espacio de mundo directamente desde la cámara (`camera.global_basis`), independiente de los tweens o rotaciones locales de la malla |
