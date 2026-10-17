extends "res://tests/base_teste.gd"


func _carro(d: Node, id: String) -> Carro:
	var c := Carro.new(d.carro(id))
	c.adicionar_pneu(d.pneu("seco"))
	return c


func test_efeitos_soma_antes_de_mult_independente_da_ordem() -> void:
	var d := dados_fixture()
	var a := _carro(d, "fraco")
	a.instalar(d.peca("turbo"))
	a.instalar(d.peca("alivio"))
	var b := _carro(d, "fraco")
	b.instalar(d.peca("alivio"))
	b.instalar(d.peca("turbo"))
	var ea := a.atributos_efetivos("seco")
	perto(ea["potencia"], 150.0, 1e-6, "potência")
	perto(ea["peso"], 510.0, 1e-6, "peso (1000+20)*0.5")
	igual(b.atributos_efetivos("seco"), ea, "ordem de instalação")
	d.free()


func test_compatibilidade_e_uma_peca_por_categoria() -> void:
	var d := dados_fixture()
	var fraco := _carro(d, "fraco")
	verificar(not fraco.instalar(d.peca("motor_fr")), "motor_fr não serve em FF")
	var forte := _carro(d, "forte")
	forte.instalar(d.peca("turbo"))
	verificar(forte.instalar(d.peca("motor_fr")), "motor_fr serve em FR")
	perto(forte.atributos_efetivos("seco")["potencia"], 350.0, 1e-6, "motor_fr substitui turbo")
	d.free()


func test_pneu_de_chuva_e_usado_automaticamente() -> void:
	var d := dados_fixture()
	var c := _carro(d, "fraco")
	perto(c.atributos_efetivos("chuva")["aderencia"], 0.5, 1e-6, "só seco, na chuva")
	c.adicionar_pneu(d.pneu("chuva"))
	igual(c.atributos_efetivos("chuva")["pneu"], "chuva", "escolha na chuva")
	perto(c.atributos_efetivos("chuva")["aderencia"], 0.9, 1e-6, "aderência na chuva")
	igual(c.atributos_efetivos("seco")["pneu"], "seco", "escolha no seco")
	d.free()


func test_forma_do_ganho_na_curva() -> void:
	var antes := {"curva_rpm": PackedFloat64Array([1000, 4000, 7000]), "curva_nm": PackedFloat64Array([100, 120, 100]), "corte": 7000.0}
	var igual_ := {"curva_rpm": antes["curva_rpm"], "curva_nm": PackedFloat64Array([110, 132, 110]), "corte": 7000.0}
	verificar(GraficoMotor.forma_do_ganho(antes, igual_).contains("por igual"), "10% em todo o giro: por igual")
	var alto := {"curva_rpm": antes["curva_rpm"], "curva_nm": PackedFloat64Array([100, 130, 140]), "corte": 7500.0}
	var f := GraficoMotor.forma_do_ganho(antes, alto)
	verificar(f.contains("giro alto") and f.contains("corte sobe 500"), "turbo: giro alto e corte (%s)" % f)
