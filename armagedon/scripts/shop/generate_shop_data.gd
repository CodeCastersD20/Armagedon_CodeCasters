@tool
extends EditorScript

# TODO(GDD #22): Valores temporales de balance mientras se cierra la issue #22
func _run() -> void:
	_ensure_dir("res://data/upgrades")
	_ensure_dir("res://data/faith_powers")
	_ensure_dir("res://data/weapons")

	# 1. Upgrades, consumibles y habilidades (data/upgrades/)
	var upgrades := [
		# Siempre (nivel_maximo = 0 indica compra repetible)
		[&"vida_curacion", "Vida (curación)", UpgradeData.Category.SIEMPRE, "Restaura una parte de la vida", 50, 30.0, 0],
		[&"fe_recarga", "Fe (recarga)", UpgradeData.Category.SIEMPRE, "Restaura una parte de la barra de Fe", 50, 30.0, 0],

		# Melee
		[&"melee_crit_chance", "Prob. de crítico (melee)", UpgradeData.Category.MELEE, "Aumenta la probabilidad de crítico de la espada", 100, 0.05, 5],
		[&"melee_crit_damage", "Daño crítico (melee)", UpgradeData.Category.MELEE, "Aumenta el multiplicador de los críticos de la espada", 100, 0.25, 5],
		[&"melee_flat_damage", "Daño plano (melee)", UpgradeData.Category.MELEE, "Suma daño fijo a cada golpe de la espada", 100, 5.0, 5],
		[&"melee_pct_damage", "Daño % (melee)", UpgradeData.Category.MELEE, "Aumenta en porcentaje el daño de la espada", 120, 0.10, 5],

		# Fuego
		[&"fuego_crit_chance", "Prob. de crítico (fuego)", UpgradeData.Category.FUEGO, "Aumenta la probabilidad de crítico del arma de fuego", 100, 0.05, 5],
		[&"fuego_crit_damage", "Daño crítico (fuego)", UpgradeData.Category.FUEGO, "Aumenta el multiplicador de los críticos del arma de fuego", 100, 0.25, 5],
		[&"fuego_flat_damage", "Daño plano (fuego)", UpgradeData.Category.FUEGO, "Suma daño fijo a cada disparo", 100, 3.0, 5],
		[&"fuego_pct_damage", "Daño % (fuego)", UpgradeData.Category.FUEGO, "Aumenta en porcentaje el daño del arma de fuego", 120, 0.10, 5],
		[&"fuego_cadencia", "Cadencia", UpgradeData.Category.FUEGO, "Reduce el tiempo entre disparos", 120, 0.10, 5],
		[&"fuego_cargador", "Tamaño de cargador", UpgradeData.Category.FUEGO, "Aumenta las balas por cargador", 100, 4.0, 5],

		# Personaje
		[&"personaje_vida_max", "Vida máxima", UpgradeData.Category.PERSONAJE, "Aumenta los HP máximos", 100, 20.0, 5],
		[&"personaje_dash", "Dash", UpgradeData.Category.PERSONAJE, "Mejora el dash (más distancia o más cargas de estamina)", 150, 1.0, 3],
		[&"personaje_velocidad", "Velocidad", UpgradeData.Category.PERSONAJE, "Aumenta la velocidad de movimiento", 100, 0.10, 5],
		[&"personaje_doble_salto", "Doble salto (alas)", UpgradeData.Category.PERSONAJE, "Permite un segundo salto en el aire", 250, 1.0, 1],
		[&"personaje_dash_aire", "Dash en el aire", UpgradeData.Category.PERSONAJE, "Permite usar el dash mientras está en el aire", 250, 1.0, 1],

		# Habilidad de arma
		[&"habilidad_tajo_distancia", "Tajo a distancia", UpgradeData.Category.HABILIDAD_ARMA, "Lanza un tajo hacia adelante que daña a distancia", 200, 1.0, 1],
	]

	for u in upgrades:
		var res := UpgradeData.new()
		res.id = u[0]
		res.nombre = u[1]
		res.categoria = u[2]
		res.efecto = u[3]
		res.precio = u[4]
		res.valor_por_nivel = u[5]
		res.nivel_maximo = u[6]
		ResourceSaver.save(res, "res://data/upgrades/%s.tres" % String(res.id))

	# 2. Poderes de Fe (data/faith_powers/)
	var faith_powers := [
		[&"bola_de_fuego", "Bola de fuego", "Poder de Fe: lanza una bola de fuego que daña a los enemigos", 150, 25.0, 4.0, 20.0, 3],
		[&"curacion_pasiva", "Curación pasiva", "Poder de Fe: aumenta la regeneración de vida", 150, 20.0, 8.0, 2.0, 3],
		[&"dano_extra_arma", "Daño extra al arma equipada", "Poder de Fe: suma daño al arma que esté equipada", 150, 30.0, 10.0, 15.0, 3],
	]

	for fp in faith_powers:
		var res := FaithPowerData.new()
		res.id = fp[0]
		res.nombre = fp[1]
		res.efecto = fp[2]
		res.precio_tienda = fp[3]
		res.costo_fe = fp[4]
		res.cooldown = fp[5]
		res.valor_por_nivel = fp[6]
		res.nivel_maximo = fp[7]
		ResourceSaver.save(res, "res://data/faith_powers/%s.tres" % String(res.id))

	# 3. Armas de fuego en tienda (data/weapons/)
	var weapons := [
		[&"pistola", "Pistola", "Reemplaza el arma de fuego equipada por la pistola", 150],
		[&"escopeta", "Escopeta", "Reemplaza el arma de fuego equipada por la escopeta", 250],
		[&"subfusil", "Subfusil", "Reemplaza el arma de fuego equipada por el subfusil", 250],
		[&"rifle_fx05", "Rifle FX-05", "Reemplaza el arma de fuego equipada por el rifle", 350],
	]

	for w in weapons:
		var res := ShopWeaponData.new()
		res.id = w[0]
		res.nombre = w[1]
		res.slot = ShopWeaponData.WeaponSlot.FUEGO
		res.efecto = w[2]
		res.precio_tienda = w[3]
		ResourceSaver.save(res, "res://data/weapons/%s.tres" % String(res.id))

	print("Listo: 18 upgrades, 3 poderes de Fe y 4 armas generados en res://data/")

func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
