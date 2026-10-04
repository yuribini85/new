#!/usr/bin/env bash
# Roda os testes e falha também em erro de script, que o Godot só imprime:
# uma função que quebra no meio não chega às asserções seguintes.
# Uso: tests/rodar.sh [caminho-do-godot]
set -uo pipefail
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
importacao="$("$GODOT" --headless --import 2>&1)"
# timeout: se o runner não compila, o Godot fica aberto em vez de sair.
saida="$(timeout 600 "$GODOT" --headless --script res://tests/run_tests.gd 2>&1)"
status=$?
echo "$saida" | grep -vE '^\s+at: push_warning|^WARNING: Dados pendente|^WARNING: Jogador'
if [ $status -eq 124 ]; then
	echo "Testes não terminaram em 600 s" >&2
	exit 1
fi
if echo "$importacao$saida" | grep -qE 'SCRIPT ERROR|Parse Error|Compile Error'; then
	echo "$importacao" | grep -E 'SCRIPT ERROR|Parse Error|Compile Error' >&2
	echo "Erro de script durante os testes" >&2
	exit 1
fi
python3 tests/checar_rascunhos.py || exit 1
python3 tests/checar_conversor.py || exit 1
exit $status
