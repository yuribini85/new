class_name AreaSegura
extends RefCounted
## Recorte do topo do aparelho (câmera, barra do sistema), em px da tela do
## jogo: o cenário passa por baixo; botões e textos ficam abaixo dele. No app
## (Android/iOS) vem do DisplayServer; no navegador, de env(safe-area-inset-top)
## (o shell web usa viewport-fit=cover para o jogo ocupar a tela inteira).


static func topo(largura_tela: float) -> float:
	return _lado(largura_tela, true)


## Recorte do pé (barra de gestos), para a navegação ficar acima dele.
static func base(largura_tela: float) -> float:
	return _lado(largura_tela, false)


static func _lado(largura_tela: float, cima: bool) -> float:
	if OS.has_feature("web"):
		var js := "(function(){var d=document.createElement('div');" \
				+ "d.style.cssText='position:fixed;top:0;left:0;width:1px;height:env(safe-area-inset-%s,0px)';" \
				+ "document.body.appendChild(d);var h=d.getBoundingClientRect().height;d.remove();" \
				+ "return h/Math.max(window.innerWidth,1);})()"
		var fracao = JavaScriptBridge.eval(js % ("top" if cima else "bottom"), true)
		return maxf(0.0, float(fracao) * largura_tela) if fracao != null else 0.0
	if not OS.has_feature("mobile"):
		return 0.0
	var seguro := Rect2(DisplayServer.get_display_safe_area())
	var janela := Rect2(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	if janela.size.x <= 0 or seguro.size.x <= 0:
		return 0.0
	var px := seguro.position.y - janela.position.y if cima else janela.end.y - seguro.end.y
	return maxf(0.0, px) * largura_tela / janela.size.x
