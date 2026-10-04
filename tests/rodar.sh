#!/usr/bin/env bash
# Roda os testes e falha também em erro de script, que o Godot só imprime:
# uma função que quebra no meio não chega às asserções seguintes.
# Uso: tests/rodar.sh [caminho-do-godot]
set -uo pipefail
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --import >/dev/null 2>&1
saida="$("$GODOT" --headless --script res://tests/run_tests.gd 2>&1)"
status=$?
echo "$saida" | grep -vE '^\s+at: push_warning|^WARNING: Dados pendente|^WARNING: Jogador'
if echo "$saida" | grep -qE 'SCRIPT ERROR|Parse Error|Compile Error'; then
	echo "Erro de script durante os testes" >&2
	exit 1
fi
exit $status
