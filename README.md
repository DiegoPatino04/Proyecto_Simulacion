# Semestre Maldito

RPG por turnos desarrollado en Godot Engine 4.x como proyecto final de la asignatura Simulación por Computador — ExpoSimu 2024
Universidad Pedagógica y Tecnológica de Colombia (UPTC)


# Descripción
Semestre Maldito es un videojuego RPG por turnos con temática académica universitaria. Los jugadores controlan a tres estudiantes atrapados en un semestre imposible, enfrentando entidades corruptas del conocimiento que dominan los bloques del campus de la Academia Bit.
Lo que diferencia este proyecto de un RPG convencional es que su mecánica de combate está completamente impulsada por cinco modelos de simulación independientes, visibles en tiempo real a través del HUD del juego.

# Características principales

Combate por turnos con 3 personajes jugables y 5 tipos de enemigos
5 modelos de simulación integrados en el núcleo de combate
HUD con métricas de simulación en vivo (λ, μ, ρ de cola M/M/1)
3 niveles explorables con encuentros generados estocásticamente
Jefe final (El Catedrático) con IA autónoma y estado adaptativo
Sistema de Corrupción — barra dinámica que escala la dificultad con retroalimentación positiva


Modelos de Simulación
Todos los modelos se encuentran en project/scripts/simulation/ y son evaluables de forma independiente.
ArchivoTipo de SimulaciónRol en el juegoQueueModel.gdCola M/M/1 (eventos discretos)Modela la cadencia de ataques como sistema de colas; calcula λ, μ, ρ mostrados en HUDMonteCarlo.gdMonte Carlo (estocástica)Resuelve esquive, daño aleatorio y golpes críticos en cada turnoRandomWalk.gdCadenas de Markov (discreta)Determina qué enemigo aparece según la posición en el grafo del nivelSystemDynamics.gdDinámica de sistemas (continua)Gestiona el stock de Corrupción con retroalimentación positiva que escala el daño del enemigoEnemyAgent.gdAgente basado en reglas (ABS)IA del enemigo con 4 estados (ACTIVO → FURIOSO → CRÍTICO) que cambian su comportamiento

Personajes
PersonajeClaseHPDañoDescripciónProgramadorAtacante10010–18Daño consistente, 20% de probabilidad de críticoMatemáticoMago858–22Alta varianza de daño, impredecibleTécnico en RedesTank12012–16Resistente, daño bajo pero estable

Estructura del proyecto
semestre-maldito/
├── project/
│   ├── data/
│   │   ├── characteres/          # Sprites animados de personajes y enemigos
│   │   ├── Efectos/              # Animaciones de ataque/defensa y música
│   │   └── fondos/               # Fondos de batalla, mapas y menús
│   ├── scenes/
│   │   ├── maps/
│   │   │   ├── Nivel_1/          # Dungeon primer semestre
│   │   │   ├── Nivel2/           # Laboratorio de redes
│   │   │   ├── Nivel3/           # Sala de servidores
│   │   │   ├── battle/           # Escena de combate (Battle.tscn)
│   │   │   ├── Boss/             # Enfrentamiento final
│   │   │   ├── Select_Menu/      # Selección de personaje
│   │   │   └── Escena Principal/ # Mapa principal
│   │   └── maps/Final/           # Escena de fin de juego
│   └── scripts/
│       ├── Battle.gd             # Orquestador principal de combate (v3)
│       ├── GlobalState.gd        # Singleton: HP del grupo, corrupción, nivel actual
│       ├── Map1.gd               # Lógica de exploración del mapa
│       ├── main_menu.gd          # Menú principal
│       └── simulation/           # Modelos de simulación independientes
│           ├── QueueModel.gd
│           ├── MonteCarlo.gd
│           ├── RandomWalk.gd
│           ├── SystemDynamics.gd
│           └── EnemyAgent.gd
└── Tile_sets/                    # Tilesets del dungeon

Requisitos e instalación
Requisitos

Godot Engine 4.x (recomendado 4.2 o superior)
No se requieren plugins adicionales

Pasos para ejecutar
bash
# 1. Clona el repositorio
git clone https://github.com/DiegoPatino04/Proyecto_Simulacion.git

# 2. Abre Godot Engine 4.x

# 3. Importa el proyecto
#    File → Import Project → navega a semestre-maldito/project.godot

# 4. Ejecuta con F5 o el botón ▶ de Godot

Cómo jugar

En el Menú Principal, presiona Jugar
En la pantalla de selección, elige tu personaje (Programador, Matemático o Técnico en Redes)
Explora el mapa — al contactar un enemigo se inicia el combate automáticamente
En combate:

Presiona Atacar para que el personaje actual realice su acción
Los tres personajes atacan en secuencia antes del turno del enemigo
Observa el panel de simulación (λ, μ, ρ, Estado del agente) en el HUD
Vigila la barra de Corrupción — cuando se llena, el enemigo hace el doble de daño


Derrota a todos los enemigos de los tres niveles para llegar al Boss final


📐 Arquitectura de simulación
                    ┌─────────────────────────────┐
                    │        Battle.gd (v3)        │
                    │   Orquestador de combate     │
                    └──────────┬──────────────────-┘
         ┌──────────────┬──────┴─────┬─────────────┬──────────────┐
         ▼              ▼            ▼             ▼              ▼
   ┌──────────┐  ┌──────────┐ ┌──────────┐ ┌─────────────┐ ┌──────────┐
   │QueueModel│  │MonteCarlo│ │RandomWalk│ │SystemDynamic│ │EnemyAgent│
   │ λ, μ, ρ  │  │ Daño RNG │ │  Grafo   │ │ Corrupción  │ │ IA/Reglas│
   └──────────┘  └──────────┘ └──────────┘ └─────────────┘ └──────────┘
         │              │            │             │              │
         ▼              ▼            ▼             ▼              ▼
      HUD Panel    Resultado     Enemigo       Mult. daño     Decisión
      en tiempo    del turno     seleccionado  del enemigo    del turno
      real
El GlobalState (singleton de Godot) actúa como memoria compartida entre escenas, persistiendo el HP del grupo, el nivel de corrupción y el mapa actual.

Tecnologías utilizadas

Motor: Godot Engine 4.x
Lenguaje: GDScript
Arte: Pixel art 32-bit (sprites originales)
Audio: Freesound Community, Floraphonic (licencia libre)
Control de versiones: Git / GitHub


Contexto académico
Este proyecto fue desarrollado como Taller Final de la asignatura Simulación por Computador en la UPTC (2024), cumpliendo los siguientes requisitos:

 Tipo de juego seleccionado con análisis comparativo
 Mecánicas de juego documentadas con diagramas de flujo
 Arte conceptual con paleta de colores definida
 Mínimo 5 modelos de simulación independientes y evaluables
 Integración de modelos en el producto final
 Pruebas de balance y funcionalidad documentadas


Equipo de desarrollo
Desarrollado por estudiantes de la Escuela de Ciencias de la Computación e Informática — UPTC
Docente: Alex Puertas González

Licencia
Este proyecto fue desarrollado con fines académicos.
Los assets de audio son propiedad de sus respectivos autores bajo licencias libres (ver archivos .import en project/data/Efectos/Musica/).
