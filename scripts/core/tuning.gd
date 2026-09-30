class_name Tuning
extends Resource
## Parámetros de "sensación de juego". Todos editables desde el Inspector abriendo
## res://data/config/tuning.tres, sin tocar código.
## Unidades: metros, segundos, m/s, m/s².

@export_group("Pelota")
## Gravedad aplicada a la pelota.
@export var gravity: float = 9.81
## Radio de la pelota (reglamentaria ~0.11 m, circunferencia 68-70 cm).
@export var ball_radius: float = 0.11
## Masa (FIFA: 410-450 g).
@export var ball_mass: float = 0.43
## Densidad del aire (kg/m³, nivel del mar).
@export var air_density: float = 1.2
## Coeficiente de arrastre a baja y a alta velocidad. Entre ambas velocidades
## de "crisis de arrastre" el flujo pasa a turbulento y el Cd cae (~0,45 -> ~0,22):
## los tiros fuertes "vuelan" más de lo que frenarían con un Cd constante.
@export var drag_cd_low: float = 0.45
@export var drag_cd_high: float = 0.22
@export var drag_crisis_low: float = 9.0
@export var drag_crisis_high: float = 15.0
## Desaceleración constante al rodar sobre el pasto (resistencia a la rodadura).
@export var rolling_decel: float = 2.6
## Coeficiente de rebote vertical contra el pasto (en superficie dura la FIFA
## pide ~0,8: cae de 2 m y rebota 1,2-1,4 m; el césped absorbe más).
@export var ground_restitution: float = 0.6
## Fracción de velocidad horizontal que se conserva en cada pique.
@export var bounce_friction: float = 0.88
## Por debajo de esta velocidad vertical la pelota deja de picar y rueda.
@export var bounce_min_speed: float = 1.2
## Efecto Magnus: a = k · (ω × v), con ω en rad/s. Con k = 0,005, un tiro a
## 25 m/s con 60 rad/s (~10 vueltas/s) se desvía ~3 m en 25 m (tiro libre con comba).
@export var magnus: float = 0.005
## Decaimiento del efecto por segundo (0..1 por segundo aprox).
@export var spin_decay: float = 0.35
## Rebote contra postes y travesaño.
@export var post_restitution: float = 0.6
## Rebote contra la red (bajo: la red "absorbe").
@export var net_restitution: float = 0.05

@export_group("Jugadores")
@export var run_speed: float = 6.2
@export var sprint_speed: float = 8.4
## Multiplicador de velocidad cuando se conduce la pelota.
@export var dribble_speed_factor: float = 0.9
@export var acceleration: float = 26.0
@export var deceleration: float = 32.0
## Velocidad de giro (rad/s) quieto/lento y a velocidad de sprint: a mayor
## velocidad, giro más amplio (nunca 180° instantáneo).
@export var turn_rate: float = 16.0
@export var turn_rate_sprint: float = 5.5
## Multiplicador del giro con la pelota en el pie.
@export var turn_rate_ball_factor: float = 0.85

@export_group("Energía y reacción")
## Puntos de energía (0-100) por segundo de sprint (jugador promedio).
@export var stamina_sprint_drain: float = 2.6
## Recuperación por segundo trotando / parado o caminando.
@export var stamina_regen_jog: float = 0.9
@export var stamina_regen_rest: float = 2.2
## Debajo de esta energía la velocidad baja hasta stamina_min_speed_factor.
@export var stamina_tired_threshold: float = 35.0
@export var stamina_min_speed_factor: float = 0.85
## Tiempo de reacción de la IA ante una patada (informe: 0,15-0,25 s),
## según el atributo reaction (99 -> mínimo, 1 -> máximo).
@export var ai_reaction_min: float = 0.15
@export var ai_reaction_max: float = 0.25

@export_group("Conducción y robo")
## Máximo que se adelanta la pelota en cada toque, trotando / en sprint
## (jugador de control promedio; ver Dribble.touch_distance).
@export var dribble_distance: float = 0.3
@export var dribble_distance_sprint: float = 0.9
## Aceleración máxima con la que el "resorte" de conducción corrige la pelota
## (más alto = más pegada; más bajo = más suelta en los giros).
@export var dribble_steer_accel: float = 70.0
## Si la pelota queda más lejos que esto del pie, el conductor la pierde.
@export var dribble_lose_distance: float = 2.5
## Radio (horizontal) para tomar una pelota suelta.
@export var control_radius: float = 0.8
## Radio extra para el receptor designado de un pase (recepción segura).
@export var receive_radius: float = 1.1
## Altura máxima a la que un jugador de campo controla la pelota.
@export var control_height: float = 1.1
## Probabilidad por segundo de que un rival se quede con una pelota expuesta
## (lejos del pie del conductor, p. ej. en sprint) si está dentro de control_radius.
@export var intercept_rate: float = 4.0

@export_group("Entradas")
## Distancia a la pelota desde la que se intenta una entrada.
@export var tackle_range: float = 1.3
## Probabilidad base de éxito de frente / de costado / de atrás.
@export var tackle_front: float = 0.7
@export var tackle_side: float = 0.45
@export var tackle_back: float = 0.18
## Tiempo entre intentos y desbalance si falla.
@export var tackle_cooldown: float = 0.7
@export var tackle_fail_stagger: float = 0.4
## Tiempo sin poder tocar la pelota tras patearla o perderla.
@export var touch_cooldown: float = 0.28
@export var lost_ball_cooldown: float = 0.6

@export_group("Barrida")
@export var slide_speed: float = 10.5
@export var slide_duration: float = 0.45
@export var slide_recovery: float = 0.55
@export var slide_reach: float = 1.1

@export_group("Pases y tiros")
## Tiempo para cargar la barra de potencia de 0 a 1.
@export var power_charge_time: float = 0.85
## Velocidad con la que un pase corto llega al receptor (mín/máx según potencia).
@export var short_pass_arrive_min: float = 5.0
@export var short_pass_arrive_max: float = 9.0
## Distancia máxima que se considera para un pase corto.
@export var short_pass_max_distance: float = 35.0
## Adelanto del pase al hueco (mín/máx según potencia).
@export var through_lead_min: float = 5.0
@export var through_lead_max: float = 18.0
## Ángulo del pase largo/centro (grados) según potencia.
@export var long_pass_angle_min: float = 18.0
@export var long_pass_angle_max: float = 38.0
## Distancia de un pase largo sin receptor claro (mín/máx según potencia).
@export var long_pass_free_min: float = 18.0
@export var long_pass_free_max: float = 55.0
## Velocidad de tiro (mín/máx según potencia).
@export var shot_speed_min: float = 15.0
@export var shot_speed_max: float = 30.0
## Altura (m) a la que el tiro llega al arco según potencia (el travesaño
## está a 2,44 m; a potencia >95 % se suma ~0,9 m y se puede ir por arriba).
@export var shot_height_min: float = 0.2
@export var shot_height_max: float = 1.9
## Ayuda al pasar (0 = el pase sale exactamente hacia el stick, 1 = va
## directo al receptor elegido). WE: ayuda leve, se puede fallar.
@export var pass_assist: float = 0.88
## Cono (grados) para buscar receptor en la dirección del stick.
@export var pass_cone_degrees: float = 50.0
## Tiempo durante el que se recuerda un pase/tiro pedido antes de recibir (toque de primera).
@export var one_touch_buffer: float = 0.55

@export_group("Arquero")
@export var keeper_reach: float = 1.9
@export var keeper_catch_height: float = 2.5
@export var keeper_dive_speed: float = 7.5
@export var keeper_hold_time: float = 1.2
## Radio y probabilidad por segundo de que el arquero le saque la pelota de los pies al atacante.
@export var keeper_smother_radius: float = 1.4
@export var keeper_smother_rate: float = 5.0
