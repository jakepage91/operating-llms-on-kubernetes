#!/bin/bash
set -e

API_URL="${API_URL:-http://localhost:3001}"

echo "🧪 Testing Restaurant API at ${API_URL}..."
echo ""

# Test health endpoint
echo "1️⃣  Testing health check..."
HEALTH_RESPONSE=$(curl -s "${API_URL}/health")
echo "Response: ${HEALTH_RESPONSE}"
echo ""

# Check if Ollama is connected
if echo "${HEALTH_RESPONSE}" | grep -q '"connected":true'; then
    echo "✅ Ollama connection healthy"
else
    echo "⚠️  Ollama not connected. Ensure mirrord is running or port-forward is active."
    echo "   Run: mirrord exec --config mirrord/config.json -- npm run dev"
    echo "   Or:  kubectl port-forward -n llm svc/ollama 11434:11434"
    exit 1
fi
echo ""

# Test sample orders endpoint
echo "2️⃣  Testing sample orders endpoint..."
ORDERS_RESPONSE=$(curl -s "${API_URL}/api/sample-orders")
ORDER_COUNT=$(echo "${ORDERS_RESPONSE}" | grep -o '"id"' | wc -l | tr -d ' ')
echo "✅ Received ${ORDER_COUNT} sample orders"
echo ""

# Test recommendations endpoint
echo "3️⃣  Testing recommendations endpoint..."
echo "   (This may take 10-30 seconds depending on model size)"

RECOMMENDATIONS_RESPONSE=$(curl -s -X POST "${API_URL}/api/recommendations" \
  -H "Content-Type: application/json" \
  -d '{
    "temperature": 0.2,
    "top_p": 0.9,
    "model": "llama3.2"
  }')

if echo "${RECOMMENDATIONS_RESPONSE}" | grep -q '"summary"'; then
    echo "✅ Recommendations generated successfully!"
    echo ""
    echo "Summary excerpt:"
    echo "${RECOMMENDATIONS_RESPONSE}" | grep -o '"summary":"[^"]*"' | head -c 200
    echo "..."
else
    echo "❌ Failed to generate recommendations"
    echo "Response: ${RECOMMENDATIONS_RESPONSE}"
    exit 1
fi
echo ""

echo "🎉 All tests passed!"
echo ""
echo "Next steps:"
echo "  - Run the frontend: cd restaurant-app/frontend && npm run dev"
echo "  - Open browser: http://localhost:5173"
