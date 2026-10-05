class_name CameraConfig
extends Resource
## Parámetros de un modo de cámara (editables en res://data/config/cameras/).
## LATERAL: cámara de transmisión en la tribuna (+Z) que acompaña la pelota en
## parte deslizándose y en parte rotando (vista diagonal cerca de los arcos).
## VERTICAL: detrás del equipo humano, mirando hacia el arco rival.
## TOPDOWN: vista de dron desde arriba.

enum Mode { LATERAL, VERTICAL, TOPDOWN }

## Nombre que se muestra al cambiar de cámara.
@export var display_name: String = "TV"
@export var mode: Mode = Mode.LATERAL
## Altura de la cámara sobre el césped (m).
@export var camera_height: float = 19.0
## Distancia horizontal desde la zona de la pelota (m).
@export var camera_distance: float = 33.0
## Giro extra (grados) alrededor del eje vertical: 0 = lateral puro.
@export var camera_angle: float = 0.0
## Qué tan rápido sigue a la pelota (mayor = más pegada, menor = más suave).
@export var follow_speed: float = 2.6
## Anticipación según la velocidad de la pelota (segundos).
@export var look_ahead: float = 0.35
## Zoom (1 = campo de visión base; >1 acerca).
@export var zoom: float = 1.0
## Campo de visión base (grados).
@export var base_fov: float = 36.0
## Corrimiento del punto mirado a lo largo de la cancha (m, + = hacia la derecha).
@export var horizontal_offset: float = 0.0
## Corrimiento del punto mirado a lo ancho (m, + = hacia la cámara).
@export var vertical_offset: float = -3.0
## 1 = la cámara se desliza por la tribuna siguiendo la pelota; 0 = queda fija
## en la mitad de cancha y sólo rota.
@export_range(0.0, 1.0) var track_factor: float = 0.72
## Cuánto sigue a la pelota a lo ancho (1 = la sigue hasta la banda cercana).
@export_range(0.0, 1.0) var track_z: float = 0.8
## Nombres de todos los jugadores arriba de la cabeza (cámara Lejana, como
## la "Normal Far" con nombres del WE).
@export var show_names: bool = false
## Límite del foco a lo largo de la cancha (para no mirar de más afuera).
@export var focus_limit_x: float = 44.0
