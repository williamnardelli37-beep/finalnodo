#!/bin/sh
# Gera um DMG simples e confiavel por hdiutil, sem automacao do Finder.
# Uso: OUT=build VERSAO=3.0.5 sh instaladores/mac/montar-dmg.sh
# Requer build/Nodo.app universal e compatibilidade minima com macOS 12.
set -eu
cd "$(dirname "$0")/../.."

VERSAO="${VERSAO:-3.0.5}"
ID="${CODESIGN_IDENTITY:--}"
APP="build/Nodo.app"

[ -d "$APP" ] || { echo "ERRO: build/Nodo.app nao encontrado."; exit 1; }

QTPREFIX="${NODO_QT:-$(sed -n 's/^CMAKE_PREFIX_PATH:[A-Z]*=//p' build/CMakeCache.txt 2>/dev/null | head -1)}"
QTBIN="$QTPREFIX/bin"
if [ -x "$QTBIN/macdeployqt" ]; then
  "$QTBIN/macdeployqt" "$APP"
elif command -v macdeployqt >/dev/null 2>&1; then
  macdeployqt "$APP"
else
  echo "ERRO: macdeployqt nao encontrado. Use o mesmo Qt da compilacao." >&2
  exit 1
fi

# Valida cada executavel e biblioteca: deployment target <= macOS 12.0
# e arquiteturas Intel x86_64 + Apple Silicon arm64.
python3 scripts/verificar_macos_minimo.py "$APP" --minimum 12.0 --archs x86_64,arm64

ARQ="$(lipo -archs "$APP/Contents/MacOS/Nodo" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"
case "$ARQ" in
  "arm64 x86_64") SUF="universal" ;;
  *) echo "ERRO: arquitetura inesperada: $ARQ"; exit 1 ;;
esac
echo "App universal ($ARQ), compativel com macOS 12.0."

mkdir -p "$APP/Contents/Resources"
cp LEIA-ME.txt SEGURANCA.md guia.html "$APP/Contents/Resources/" 2>/dev/null || true
codesign --force --deep --options runtime --sign "$ID" "$APP" 2>/dev/null || codesign --force --deep --sign "$ID" "$APP"
codesign --verify --deep --strict "$APP"

OUT="${OUT:-$PWD}"
mkdir -p "$OUT"
ST="$(mktemp -d)"
cleanup() { rm -rf "$ST"; }
trap cleanup EXIT HUP INT TERM

mkdir -p "$ST/dmg"
ditto "$APP" "$ST/dmg/Nodo.app"
ln -s /Applications "$ST/dmg/Aplicativos"

# Gera a imagem diretamente, sem AppleScript/Finder (nao depende de janela montada).
hdiutil create -volname "NODO $VERSAO" -srcfolder "$ST/dmg" -ov -format UDZO "$OUT/Nodo-$VERSAO-mac-$SUF.dmg"
test -s "$OUT/Nodo-$VERSAO-mac-$SUF.dmg"
echo "DMG gerado: $OUT/Nodo-$VERSAO-mac-$SUF.dmg"

# PKG auxiliar para instalacao administrativa; o workflow publica somente o DMG.
mkdir -p "$ST/scripts"
cat > "$ST/scripts/postinstall" <<'POSTINSTALL'
#!/bin/sh
mkdir -p /usr/local/bin
ln -sf /Applications/Nodo.app/Contents/MacOS/nodo-cli /usr/local/bin/nodo
exit 0
POSTINSTALL
chmod 0755 "$ST/scripts/postinstall"
pkgbuild --component "$APP" --install-location /Applications --scripts "$ST/scripts" --identifier app.nodo.servidor --version "$VERSAO" "$ST/Nodo-componente.pkg" >/dev/null
productbuild --package "$ST/Nodo-componente.pkg" "$OUT/Nodo-$VERSAO-mac-$SUF.pkg" >/dev/null
echo "PKG auxiliar gerado: $OUT/Nodo-$VERSAO-mac-$SUF.pkg"
