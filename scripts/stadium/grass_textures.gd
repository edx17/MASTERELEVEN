class_name GrassTextures
extends RefCounted
## Texturas fotográficas del césped (opcionales, CC0). Si están en
## res://assets/textures/grass/ se usan en lugar del detalle procedural:
##   grass_albedo.(png|jpg)  grass_normal.(png|jpg)  grass_roughness.(png|jpg)
## (por ejemplo "Grass 004" de ambientCG o "aerial_grass_rock" de Poly Haven,
## versión 1K o 2K; ver assets/CREDITS.md).

const DIR := "res://assets/textures/grass/"


static func _find(base: String) -> Texture2D:
	for ext in ["png", "jpg", "jpeg", "webp"]:
		var path: String = DIR + base + "." + ext
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
static func apply(mat: ShaderMaterial) -> bool:
	var albedo := _find("grass_albedo")
	if albedo == null:
		mat.set_shader_parameter("use_textures", false)
		return false
	mat.set_shader_parameter("use_textures", true)
	mat.set_shader_parameter("albedo_tex", albedo)
	var normal := _find("grass_normal")
	if normal != null:
		mat.set_shader_parameter("normal_tex", normal)
		mat.set_shader_parameter("use_normal_tex", true)
	var rough := _find("grass_roughness")
	if rough != null:
		mat.set_shader_parameter("roughness_tex", rough)
		mat.set_shader_parameter("use_roughness_tex", true)
	return true
