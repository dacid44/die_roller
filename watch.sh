#!/usr/bin/bash

# export WEBKIT_DISABLE_COMPOSITING_MODE=1

gleam run &

cd frontend
inotifywait -m -r -e modify,delete,create src | while read; do
    elm make src/Main.elm --output=../public/main.js;
done
