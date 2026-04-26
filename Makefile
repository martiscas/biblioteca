.PHONY: help start dev stop \
	library-build library-update library-stats library-refresh \
	reviews-first reviews-all reviews-force reviews-refresh \
	sync-template

PORT ?= 8000
HOST ?= 127.0.0.1
LIBRARY_JSON ?= info/library.json
LIBRARY_STATS_JSON ?= info/library-stats.json
RSS_URL ?=
COOKIE ?=
RSS_PAGES ?= 100
REVIEW_RSS_PAGES ?= 100
FORCE ?= 0
SITE_BASE_URL ?= https://jorgezuluaga.github.io
TEMPLATE_UPSTREAM ?= https://github.com/JorgeZuluaga/mylibrary.github.io.git
TEMPLATE_BRANCH ?= main
SYNC_BRANCH ?= sync-template

help:
	@echo "make start|stop|dev|library-build|library-update|library-stats|reviews-all"
	@echo "  library-update FORCE=0/1/2 # incremental books/likes/reviews"
	@echo "make sync-template            # sync template files only (keeps info/, reviews/, assets/profile.*)"

start:
	@echo "Starting server on http://$(HOST):$(PORT)"
	@nohup python3 -m http.server "$(PORT)" --bind "$(HOST)" >/dev/null 2>&1 &
	@sleep 0.2
	@echo "Started. Stop with: make stop"

dev:
	@python3 bin/dev_server.py --host "$(HOST)" --port "$(PORT)" --root "."

stop:
	@echo "Stopping server on port $(PORT) (best-effort)"
	@PID="$$(lsof -tiTCP:$(PORT) -sTCP:LISTEN 2>/dev/null | head -n 1)"; 	if [ -n "$$PID" ]; then 		echo "Killing pid $$PID"; 		kill "$$PID" 2>/dev/null || true; 		sleep 0.2; 		if kill -0 "$$PID" 2>/dev/null; then 			echo "Still running, forcing stop (SIGKILL)"; 			kill -9 "$$PID" 2>/dev/null || true; 		fi; 	else 		echo "No process listening on $(PORT)."; 	fi

library-build:
	@if [ -z "$(RSS_URL)" ]; then 		echo "RSS_URL is required."; 		exit 1; 	fi
	@python3 bin/build_library_from_goodreads.py --rss-url "$(RSS_URL)" --out "$(LIBRARY_JSON)" --rss-pages "$(RSS_PAGES)" --scrape-likes-mode all --cookie "$(COOKIE)" --verbose

library-update:
	@if [ -z "$(RSS_URL)" ]; then \
		echo "RSS_URL is required."; \
		echo "Example: make library-update RSS_URL=\"https://www.goodreads.com/review/list_rss/...\" FORCE=0"; \
		exit 1; \
	fi
	@if [ "$(FORCE)" != "0" ] && [ "$(FORCE)" != "1" ] && [ "$(FORCE)" != "2" ]; then \
		echo "FORCE must be 0, 1 or 2."; \
		exit 1; \
	fi
	@LIKES_MODE="none"; \
	if [ "$(FORCE)" = "1" ]; then LIKES_MODE="new"; fi; \
	if [ "$(FORCE)" = "2" ]; then LIKES_MODE="all"; fi; \
	echo "library-update: FORCE=$(FORCE) likes=$$LIKES_MODE"; \
	python3 bin/build_library_from_goodreads.py \
		--rss-url "$(RSS_URL)" \
		--out "$(LIBRARY_JSON)" \
		--rss-pages "$(RSS_PAGES)" \
		--scrape-likes-mode "$$LIKES_MODE" \
		--merge-from "$(LIBRARY_JSON)" \
		--cookie "$(COOKIE)" \
		--verbose
	@if [ "$(FORCE)" = "2" ]; then \
		$(MAKE) reviews-force COOKIE="$(COOKIE)" REVIEW_RSS_PAGES="$(REVIEW_RSS_PAGES)"; \
	else \
		$(MAKE) reviews-all COOKIE="$(COOKIE)" REVIEW_RSS_PAGES="$(REVIEW_RSS_PAGES)"; \
	fi
	@$(MAKE) library-stats
	@echo "Library update completed (FORCE=$(FORCE))."

library-stats:
	@python3 bin/update_library_stats.py "$(LIBRARY_JSON)" --out "$(LIBRARY_STATS_JSON)"

library-refresh: library-build library-stats
	@echo "Library refresh completed."

reviews-first:
	@python3 bin/mirror_first_review.py --library-json "$(LIBRARY_JSON)" --reviews-dir reviews --cookie "$(COOKIE)" --rss-pages "$(REVIEW_RSS_PAGES)" --site-base-url "$(SITE_BASE_URL)"

reviews-all:
	@python3 bin/mirror_all_reviews.py --library-json "$(LIBRARY_JSON)" --reviews-dir reviews --cookie "$(COOKIE)" --rss-pages "$(REVIEW_RSS_PAGES)" --site-base-url "$(SITE_BASE_URL)"

reviews-force:
	@python3 bin/mirror_all_reviews.py --library-json "$(LIBRARY_JSON)" --reviews-dir reviews --cookie "$(COOKIE)" --rss-pages "$(REVIEW_RSS_PAGES)" --site-base-url "$(SITE_BASE_URL)" --force

reviews-refresh: reviews-all library-stats
	@echo "Reviews refresh completed."

sync-template:
	@set -e; \
	TMP_DIR="$$(mktemp -d)"; \
	KEEP_DIR="$$(mktemp -d)"; \
	trap 'rm -rf "$$TMP_DIR"' EXIT; \
	trap 'rm -rf "$$TMP_DIR" "$$KEEP_DIR"' EXIT; \
	echo "[1/9] Configurando remoto upstream..."; \
	if git remote get-url upstream >/dev/null 2>&1; then \
		git remote set-url upstream "$(TEMPLATE_UPSTREAM)"; \
		echo "Updated upstream -> $(TEMPLATE_UPSTREAM)"; \
	else \
		git remote add upstream "$(TEMPLATE_UPSTREAM)"; \
		echo "Added upstream -> $(TEMPLATE_UPSTREAM)"; \
	fi; \
	echo "[2/9] Descargando cambios del template..."; \
	git fetch upstream; \
	echo "[3/9] Cambiando a main..."; \
	git checkout main; \
	echo "[4/9] Respaldando datos locales (info/, reviews/, assets/profile.*)..."; \
	mkdir -p "$$KEEP_DIR/info" "$$KEEP_DIR/reviews" "$$KEEP_DIR/assets"; \
	if [ -d info ]; then rsync -a info/ "$$KEEP_DIR/info/"; fi; \
	if [ -d reviews ]; then rsync -a reviews/ "$$KEEP_DIR/reviews/"; fi; \
	for f in assets/profile.jpg assets/profile.jpeg assets/profile.png assets/profile.webp assets/profile.gif; do \
		if [ -f "$$f" ]; then cp "$$f" "$$KEEP_DIR/assets/"; fi; \
	done; \
	echo "[5/9] Exportando upstream/$(TEMPLATE_BRANCH) a directorio temporal..."; \
	git archive "upstream/$(TEMPLATE_BRANCH)" | tar -x -C "$$TMP_DIR"; \
	echo "[6/9] Sincronizando archivos de plantilla (preservando datos)..."; \
	rsync -a --delete \
		--exclude ".git/" \
		--exclude "info/" \
		--exclude "reviews/" \
		--exclude "assets/profile.jpg" \
		--exclude "assets/profile.jpeg" \
		--exclude "assets/profile.png" \
		--exclude "assets/profile.webp" \
		--exclude "assets/profile.gif" \
		"$$TMP_DIR"/ ./; \
	echo "[7/9] Restaurando datos locales respaldados..."; \
	mkdir -p info reviews assets; \
	if [ -d "$$KEEP_DIR/info" ]; then rsync -a "$$KEEP_DIR/info/" info/; fi; \
	if [ -d "$$KEEP_DIR/reviews" ]; then rsync -a "$$KEEP_DIR/reviews/" reviews/; fi; \
	for f in "$$KEEP_DIR"/assets/profile.*; do \
		if [ -f "$$f" ]; then cp "$$f" assets/; fi; \
	done; \
	echo "[8/9] Creando commit de sincronización (si hay cambios)..."; \
	git add -A; \
	if git diff --cached --quiet; then \
		echo "Sin cambios para commitear."; \
	else \
		git commit -m "Sync template from upstream/$(TEMPLATE_BRANCH) (preserve data files)"; \
	fi; \
	echo "[9/9] Publicando main (forzado, sin editor)..."; \
	git push -u origin main --force; \
	echo "Listo. main sincronizado con upstream/$(TEMPLATE_BRANCH), preservando info/, reviews/ y assets/profile.*."; \
	echo "Rama activa: $$(git branch --show-current)"
