# Proyecto_Simulacion
res://project/
├── assets/                          # ← ya existe
├── audio/                           # ← ya existe
├── data/                            # ← ya existe
│   ├── characteres/                 # ← ya existe
│   │   ├── character_maleAdventure.svg  # jugador
│   │   └── character_robot.svg          # enemigo placeholder
│   └── fondos/                      # ← ya existe
│       ├── main-menu.jpg                # fondo del menú ← USAR HOY
│       ├── scene-1.png                  # fondo Map1
│       ├── title1.png                   # título del menú ← USAR HOY
│       └── title2.png
│
├── scenes/                          # ← ya existe
│   ├── maps/                        # ← CREAR HOY
│   │   ├── Map1.tscn               # ← CREAR HOY (mover si ya existe)
│   │   ├── Map2.tscn               # (después)
│   │   └── Map3.tscn               # (después)
│   ├── battle/                      # ← CREAR HOY
│   │   ├── Battle.tscn             # ← placeholder hoy, completo mañana
│   │   └── BossBattle.tscn         # (después)
│   └── ui/                          # (después)
│
├── scripts/                         # ← ya existe
│   ├── main_menu.gd                 # ← CORREGIR HOY
│   ├── Map1.gd                      # ← CREAR HOY
│   ├── Battle.gd                    # ← placeholder hoy
│   ├── core/                        # GlobalState, BattleManager (mañana)
│   └── simulation/                  # modelos (mañana)
│
└── main_menu.tscn                   # ← ya existe, asignarle el script corregido