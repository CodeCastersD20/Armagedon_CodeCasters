# AGENTS.md — Armageddon

Guía para agentes de IA (Claude Code, OpenCode, Codex, Cursor, etc.) y para el equipo. Este archivo es la fuente única; `CLAUDE.md` solo lo importa.

## Proyecto
Armageddon: roguelike shooter en primera persona por rondas, low-poly PSX. **Godot 4, GDScript, 3D.** Desarrollo rápido (< 1 mes): hacer lo mínimo que sea entretenido. Equipo de 3: Sadrach (@Sadrach34), Adrián (@AdrianS-127), Erick (@Ddarielz).

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
  assets/             modelos, texturas, audio (Git LFS)
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
- Ramas: `main` (estable, solo entregas) ← `develop` (integración) ← ramas por tarea.
- Rama por issue: `feature/T04-1-movimiento`, `art/…`, `audio/…`, `docs/…`, `fix/…`, `chore/…`.
- PR siempre a `develop`, con revisión de al menos un compañero. Nunca push directo a `main`.
- Commits: `tipo(#T04.1): descripción` (feat, fix, docs, chore, art, audio, refactor).
- No subir `.godot/`, builds ni binarios fuera de `assets/`. Binarios por Git LFS.
- Cada tarea del tablero es una issue `[Txx.y]`; referénciala en el PR (`Closes #N`).
- Las issues usan las plantillas de `.github/ISSUE_TEMPLATE/` y los PR `.github/pull_request_template.md`.

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
