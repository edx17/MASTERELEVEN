class_name CameraConfig
extends Resource
## Parámetros de la cámara de transmisión (editables en
## res://data/config/camera.tres). Modelo: una cámara en la tribuna lateral
## (+Z) que acompaña la pelota en parte deslizándose por la tribuna y en parte
## rotando, lo que da la vista diagonal cerca de los arcos (como en la TV).

## Altura de la cámara sobre el césped (m).
@export var camera_height: float = 24.0
## Distancia horizontal desde la zona de la pelota hacia la tribuna (m).
@export var camera_distance: float = 30.0
## Giro extra (grados) alrededor del eje vertical: 0 = lateral puro.
@export var camera_angle: float = 0.0
## Qué tan rápido sigue a la pelota (mayor = más pegada, menor = más suave).
@export var follow_speed: float = 2.6
## Anticipación según la velocidad de la pelota (segundos).
@export var look_ahead: float = 0.35
## Zoom (1 = campo de visión base; >1 acerca).
@export var zoom: float = 1.0
## Campo de visión base (grados).
@export var base_fov: float = 34.0
## Corrimiento del punto mirado a lo largo de la cancha (m, + = hacia la derecha).
@export var horizontal_offset: float = 0.0
## Corrimiento del punto mirado a lo ancho (m, + = hacia la cámara).
@export var vertical_offset: float = 2.0
## 1 = la cámara se desliza por la tribuna siguiendo la pelota; 0 = queda fija
## en la mitad de cancha y sólo rota.
@export_range(0.0, 1.0) var track_factor: float = 0.72
## Límite del foco a lo largo de la cancha (para no mirar de más afuera).
@export var focus_limit_x: float = 44.0
