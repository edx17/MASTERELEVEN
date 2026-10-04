class_name GrassTextures
extends RefCounted
## Texturas fotográficas del césped (opcionales, CC0). Si están en
## res://assets/textures/grass/ se usan en lugar del detalle procedural:
##   grass_albedo.(png|jpg)  grass_normal.(png|jpg)  grass_roughness.(png|jpg)
## (por ejemplo "Grass 004" de ambientCG o "aerial_grass_rock" de Poly Haven,
## versión 1K o 2K; ver assets/CREDITS.md).

const DIR := "res://assets/textures/grass/"
## Césped gastado (Poliigon GrassPatchyGround): mismos nombres de archivo.
const WORN_DIR := "res://assets/textures/grass_worn/"


static func _find(base: String, dir: String = DIR) -> Texture2D:
	for ext in ["png", "jpg", "jpeg", "webp"]:
		var path: String = dir + base + "." + ext
		if ResourceLoader.exists(path):
			return _with_mipmaps(load(path) as Texture2D)
	return null


## Sin mipmaps, a la distancia de la cámara cada píxel de pantalla toma un
## píxel suelto de la textura (4K) y el césped se ve "granulado". Se generan
## al cargar, así funciona sin importar cómo se importó el archivo.
static func _with_mipmaps(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.has_mipmaps():
		return tex
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Configura el material del césped: con textura si hay, si no procedural.
static func apply(mat: ShaderMaterial, worn: bool = false) -> bool:
	var dir := WORN_DIR if worn and _find("grass_albedo", WORN_DIR) != null else DIR
	var albedo := _find("grass_albedo", dir)
	if albedo == null:
		mat.set_shader_parameter("use_textures", false)
		return false
	mat.set_shader_parameter("use_textures", true)
	# Gastado: manda el color de la foto (calvas, tierra) y un poco más grande.
	mat.set_shader_parameter("tex_tone", 0.85 if dir == WORN_DIR else 0.0)
	if dir == WORN_DIR:
		mat.set_shader_parameter("tex_scale", 0.2)
	mat.set_shader_parameter("albedo_tex", albedo)
	var normal := _find("grass_normal", dir)
	if normal != null:
		mat.set_shader_parameter("normal_tex", normal)
		mat.set_shader_parameter("use_normal_tex", true)
	var rough := _find("grass_roughness", dir)
	if rough != null:
		mat.set_shader_parameter("roughness_tex", rough)
		mat.set_shader_parameter("use_roughness_tex", true)
	return true
