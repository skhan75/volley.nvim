NVIM ?= nvim
STYLUA_VERSION ?= 2.1.0
STYLUA := deps/bin/stylua

.PHONY: test test-ci test-file deps format lint demo clean

# Run every tests/test_*.lua file.
test: deps
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"

# CI: one process per file under a time limit, so a hang names its file.
# (perl's alarm is the portable timeout: macOS has no GNU timeout.)
test-ci: deps
	@fail=0; for f in tests/test_*.lua; do \
		echo "== $$f"; \
		perl -e 'alarm shift; exec @ARGV' 180 \
			$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run_file('$$f')" \
			|| { echo "!! $$f failed or timed out"; fail=1; }; \
	done; exit $$fail

# Run one file: make test-file FILE=tests/test_styles.lua
test-file: deps
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

deps: deps/mini.nvim

deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@

$(STYLUA):
	@mkdir -p deps/bin
	@os=$$(uname -s); arch=$$(uname -m); \
	case "$$os-$$arch" in \
		Darwin-arm64) asset=stylua-macos-aarch64.zip ;; \
		Darwin-x86_64) asset=stylua-macos.zip ;; \
		Linux-aarch64) asset=stylua-linux-aarch64.zip ;; \
		*) asset=stylua-linux-x86_64.zip ;; \
	esac; \
	curl -fsSL -o deps/stylua.zip "https://github.com/JohnnyMorganz/StyLua/releases/download/v$(STYLUA_VERSION)/$$asset" \
		&& unzip -o -q deps/stylua.zip -d deps/bin && rm deps/stylua.zip && chmod +x $@

format: $(STYLUA)
	$(STYLUA) lua plugin tests demo

lint: $(STYLUA)
	$(STYLUA) --check lua plugin tests demo

# Record the README GIFs into assets/ (needs vhs, zsh and Hack Nerd Font).
# Each tape gets a freshly built demo project: recordings must not inherit
# the file state a previous recording left behind.
demo:
	@for t in demo/tapes/[a-z]*.tape; do \
		echo "== $$t"; bash demo/setup.sh; \
		VOLLEY_ROOT=$(CURDIR) vhs $$t >/dev/null || exit 1; \
	done

clean:
	rm -rf deps
