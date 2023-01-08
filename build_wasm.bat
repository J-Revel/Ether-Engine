odin build src/platform_layer/wasm_backend -debug -out:"html/ethereal.wasm" -target:"js_wasm32"
start firefox -private-window "http://localhost:8000"
