#!/usr/bin/env bash
URL="http://127.0.0.1:7600/mcp"

# Schaltet jegliche Pufferung für Standard-Input und Output ab
stdbuf -i0 -o0 -e0 while read -r line; do
    if [ -n "$line" ]; then
        # --no-buffer zwingt curl dazu, die Antwort sofort byte-weise auszugeben
        # Wir streamen die Antwort direkt zu Loki, ohne sie in einer Variable zwischenzuspeichern
        curl -s --no-buffer -X POST \
            -H "Content-Type: application/json" \
            -H "Accept: application/json, text/event-stream" \
            -d "$line" "$URL" | stdbuf -o0 tr -d '\n' | stdbuf -o0 sed -l -u 's/^data://g'
        
        # Ein expliziter Zeilenumbruch signalisiert Loki das Ende des JSON-RPC-Pakets
        echo ""
    fi
done
