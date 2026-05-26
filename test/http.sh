# If this fails try sse.sh

curl -X POST http://127.0.0.1:7600/mcp -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}'
