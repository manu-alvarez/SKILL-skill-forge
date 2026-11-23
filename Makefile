# skill-forge — tareas del proyecto
# Uso: make <target>   (targets: validate, adversarial, test, sync, check, help)

SKILL_DIR := skills/skill-forge
FORGE     := $(SKILL_DIR)/scripts
PI_DEST   := $(HOME)/.pi/agent/skills/skill-forge
AGENTS_DEST := $(HOME)/.agents/skills/skill-forge

.PHONY: help validate adversarial test sync check install

help: ## lista los targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "} {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

validate: ## validador oficial + validate.sh sobre la skill canónica
	npx -y skills-ref validate $(SKILL_DIR)
	bash $(FORGE)/validate.sh $(SKILL_DIR)

adversarial: ## suite adversarial (12 checks)
	bash $(FORGE)/adversarial.sh $(SKILL_DIR)

test: validate adversarial ## todo lo anterior + demo e2e auto-limpia
	@echo "== demo e2e: skill =="
	bash $(FORGE)/forge-skill.sh demo-e2e-skill "Usar SIEMPRE que se pruebe el forge en modo skill. Demo temporal de validacion end to end." /tmp/demo-e2e-skill
	bash $(FORGE)/validate.sh /tmp/demo-e2e-skill
	bash $(FORGE)/adversarial.sh /tmp/demo-e2e-skill
	rm -rf /tmp/demo-e2e-skill
	@echo "== demo e2e: mcp (sin registro) =="
	bash $(FORGE)/forge-mcp.sh demo-e2e-mcp /tmp/demo-e2e-mcp --no-register
	bash $(FORGE)/validate-mcp.sh /tmp/demo-e2e-mcp
	bash $(FORGE)/adversarial.sh /tmp/demo-e2e-mcp --mcp
	rm -rf /tmp/demo-e2e-mcp
	@echo "== TEST E2E COMPLETO: VERDE =="

sync: ## despliega la skill canónica a Pi y ~/.agents
	mkdir -p $(PI_DEST) $(AGENTS_DEST)
	cp -R $(SKILL_DIR)/ $(PI_DEST)/
	cp -R $(SKILL_DIR)/ $(AGENTS_DEST)/
	@echo "desplegado en Pi y ~/.agents"

check: ## validate + adversarial sobre las 3 copias (repo, Pi, ~/.agents)
	@set -e; for d in $(SKILL_DIR) $(PI_DEST) $(AGENTS_DEST); do \
		echo "== $$d =="; \
		npx -y skills-ref validate $$d; \
		bash $(FORGE)/validate.sh $$d | tail -1; \
		bash $(FORGE)/adversarial.sh $$d | tail -1; \
	done
	@echo "== CHECK 3 COPIAS: VERDE =="

install: sync check ## alias de sync + verificación
