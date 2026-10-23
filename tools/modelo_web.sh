#!/bin/bash
# Compila o modelo de exportação web do Godot sem os módulos que o jogo não usa
# (decisão 95, item 9: o index.wasm padrão é a maior parte do download da demo).
# Roda no CI (.github/workflows/pages.yml), com o Emscripten já no PATH; o
# resultado fica em cache e o preset Web aponta para ele (custom_template).
# Uso: tools/modelo_web.sh <pasta de saída>
set -euo pipefail
saida="$(realpath -m "${1:?pasta de saída}")"
versao="4.5.1-stable"
mkdir -p "$saida"
fonte="$(mktemp -d)"
git clone --depth 1 --branch "$versao" https://github.com/godotengine/godot.git "$fonte/godot"
cd "$fonte/godot"
# O preset Web roda sem threads (variant/thread_support=false). Fora: rede,
# realidade virtual, vídeo, mp3, navegação, formas CSG e mapas em grade, a
# importação de modelos e o Jolt (o jogo usa a física padrão). O resto fica:
# imagens, áudio OGG/WAV, ruído, regex, texto avançado, SVG (ícones do tema).
desligados=(
	csg gridmap navigation openxr webxr mobile_vr camera
	multiplayer enet websocket webrtc upnp jsonrpc
	theora minimp3 gltf fbx jolt_physics
	lightmapper_rd denoise xatlas_unwrap vhacd meshoptimizer raycast msdfgen
)
opcoes=()
for m in "${desligados[@]}"; do
	opcoes+=("module_${m}_enabled=no")
done
scons platform=web target=template_release threads=no lto=full production=yes \
	"${opcoes[@]}" -j"$(nproc)"
cp bin/godot.web.template_release.wasm32.nothreads.zip "$saida/web_nothreads_release.zip"
ls -l "$saida"
