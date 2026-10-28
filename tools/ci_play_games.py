"""CI do APK do The Fastfather: liga o plugin Play Games Services (save na nuvem).

Põe o autoload do plugin em project.godot e o game_id (variável GAME_ID) nas
opções do preset "Android Idle" (preset.3), onde o export_plugin dele o lê.
Uso: GAME_ID=123 python3 tools/ci_play_games.py
"""
import os
import re

AUTOLOAD = 'GodotPlayGameServices="*res://addons/GodotPlayGameServices/scripts/autoloads/godot_play_game_services.gd"'

proj = open("project.godot", encoding="utf-8").read()
if "GodotPlayGameServices=" not in proj:
    if "\n[autoload]\n" in proj:
        proj = proj.replace("\n[autoload]\n", "\n[autoload]\n\n" + AUTOLOAD + "\n", 1)
    else:
        proj += "\n[autoload]\n\n" + AUTOLOAD + "\n"
    open("project.godot", "w", encoding="utf-8").write(proj)

pre = open("export_presets.cfg", encoding="utf-8").read()
linha = 'godot_play_game_services/game_id="%s"' % os.environ["GAME_ID"]
pre = re.sub(r'^godot_play_game_services/game_id=.*\n', "", pre, flags=re.M)
pre = pre.replace("[preset.3.options]\n", "[preset.3.options]\n\n" + linha + "\n", 1)
assert linha in pre, "preset.3.options não encontrado"
open("export_presets.cfg", "w", encoding="utf-8").write(pre)
print("Play Games: autoload e game_id", os.environ["GAME_ID"])
