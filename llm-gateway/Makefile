.PHONY: help install test test-unit test-integration test-cov lint run docker-build docker-run k8s-deploy k8s-delete clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install dependencies
	pip install -r requirements.txt

test: ## Run all tests
	pytest -v

test-unit: ## Run unit tests only
	pytest tests/test_policy.py -v

test-integration: ## Run integration tests only
	pytest tests/test_integration.py -v

test-cov: ## Run tests with coverage report
	pytest --cov=app --cov-report=html --cov-report=term
	@echo "Coverage report generated in htmlcov/index.html"

lint: ## Run linting (requires ruff or flake8)
	@which ruff > /dev/null 2>&1 && ruff check app/ || echo "ruff not installed, skipping lint"

run: ## Run the service locally
	python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

docker-build: ## Build Docker image
	docker build -t llm-gateway:latest .

docker-run: ## Run Docker container locally
	docker run -p 8000:8000 \
		-e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
		-e ENFORCEMENT_MODE=monitor \
		llm-gateway:latest

k8s-deploy: ## Deploy to Kubernetes
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/secret.yaml
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml
	@echo "Deployment complete. Check status with: kubectl get pods -n llm-gateway"

k8s-delete: ## Delete from Kubernetes
	kubectl delete -f k8s/service.yaml || true
	kubectl delete -f k8s/deployment.yaml || true
	kubectl delete -f k8s/secret.yaml || true
	kubectl delete -f k8s/configmap.yaml || true
	kubectl delete -f k8s/namespace.yaml || true

k8s-logs: ## Show logs from Kubernetes deployment
	kubectl logs -n llm-gateway -l app=llm-gateway --tail=100 -f

k8s-port-forward: ## Port-forward Kubernetes service to localhost:8000
	kubectl port-forward -n llm-gateway svc/llm-gateway 8000:80

clean: ## Clean up generated files
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	rm -rf htmlcov/ .coverage build/ dist/
