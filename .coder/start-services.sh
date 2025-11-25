#!/bin/bash
# Helper script to start all Shtetl services in tmux

echo "🚀 Starting all Shtetl services in tmux..."

# Create a new tmux session with the first service
tmux new-session -d -s shtetl -n zmanim "cd /home/coder/workspace/submodules/shtetl-api/zmanim && go run cmd/zmanim/main.go"

# Create windows for other services
tmux new-window -t shtetl -n shul "cd /home/coder/workspace/submodules/shtetl-api/shul && go run cmd/shul/main.go"
tmux new-window -t shtetl -n kehilla "cd /home/coder/workspace/submodules/shtetl-api/kehilla && go run cmd/kehilla/main.go"
tmux new-window -t shtetl -n web "cd /home/coder/workspace/submodules/shtetl-web && npm run dev"

# Attach to the session
echo "✅ All services started in tmux session 'shtetl'"
echo ""
echo "To view services:"
echo "  tmux attach -t shtetl"
echo ""
echo "To switch between services:"
echo "  Ctrl+B then 0 (zmanim)"
echo "  Ctrl+B then 1 (shul)"
echo "  Ctrl+B then 2 (kehilla)"
echo "  Ctrl+B then 3 (web)"
echo ""
echo "To detach: Ctrl+B then D"
echo "To kill all: tmux kill-session -t shtetl"
echo ""

# Attach to the session
tmux attach -t shtetl
