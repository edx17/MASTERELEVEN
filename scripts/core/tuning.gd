class_name Tuning
extends Resource
## Parámetros de "sensación de juego". Todos editables desde el Inspector abriendo
## res://data/tuning/default_tuning.tres, sin tocar código.
## Unidades: metros, segundos, m/s, m/s².

@export_group("Pelota")
## Gravedad aplicada a la pelota.
@export var gravity: float = 9.81
## Radio de la pelota (reglamentaria ~0.11 m).
@export var ball_radius: float = 0.11
## Resistencia del aire cuadrática (a = -k·|v|·v).
@export var air_drag: float = 0.012
## Desaceleración constante al rodar sobre el pasto.
@export var rolling_decel: float = 2.6
## Coeficiente de rebote vertical contra el pasto.
@export var ground_restitution: float = 0.55
## Fracción de velocidad horizontal que se conserva en cada pique.
@export var bounce_friction: float = 0.82
## Por debajo de esta velocidad vertical la pelota deja de picar y rueda.
@export var bounce_min_speed: float = 1.2
## Fuerza del efecto (Magnus): a = k · (ω × v).
@export var magnus: float = 0.045
## Decaimiento del efecto por segundo (0..1 por segundo aprox).
@export var spin_decay: float = 0.6
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
## Velocidad de giro (rad/s) sin pelota / con pelota / con pelota en sprint.
@export var turn_rate: float = 14.0
@export var turn_rate_ball: float = 10.0
@export var turn_rate_ball_sprint: float = 6.0

@export_group("Conducción y robo")
## Distancia de la pelota al pie al conducir caminando / en sprint.
@export var dribble_distance: float = 0.55
@export var dribble_distance_sprint: float = 0.95
## Radio (horizontal) para tomar una pelota suelta.
@export var control_radius: float = 0.75
## Altura máxima a la que un jugador de campo controla la pelota.
@export var control_height: float = 1.1
## Radio de contacto para robar la pelota al rival.
@export var steal_radius: float = 0.95
## Probabilidad de robo por segundo de contacto (normal / presionando).
@export var steal_rate: float = 0.9
@export var steal_rate_pressing: float = 2.2
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
@export var shot_speed_min: float = 17.0
@export var shot_speed_max: float = 31.0
## Elevación del tiro (grados) según potencia.
@export var shot_angle_min: float = 1.5
@export var shot_angle_max: float = 14.0
## Desvío aleatorio del tiro (grados) a potencia máxima.
@export var shot_error_max: float = 4.0
## Cono (grados) para buscar receptor en la dirección del stick.
@export var pass_cone_degrees: float = 50.0
## Tiempo durante el que se recuerda un pase/tiro pedido antes de recibir (toque de primera).
@export var one_touch_buffer: float = 0.55

@export_group("Cámara")
@export var camera_height: float = 21.0
@export var camera_distance: float = 30.0
@export var camera_fov: float = 36.0
@export var camera_smoothing: float = 3.2
## Cuánto se adelanta la cámara según la velocidad de la pelota (segundos).
@export var camera_lookahead: float = 0.35

@export_group("Arquero")
@export var keeper_reach: float = 1.9
@export var keeper_catch_height: float = 2.5
@export var keeper_dive_speed: float = 7.5
@export var keeper_hold_time: float = 1.2
## Radio y probabilidad por segundo de que el arquero le saque la pelota de los pies al atacante.
@export var keeper_smother_radius: float = 1.4
@export var keeper_smother_rate: float = 5.0
