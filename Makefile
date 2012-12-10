# Location of utilities
BROWSERIFY = node_modules/browserify/bin/cmd.js
JASMINENODE = node_modules/jasmine-node/bin/jasmine-node
COFFEELINT = node_modules/coffeelint/bin/coffeelint
NPM = npm
NODEJS = nodejs # might be `node` on some systems

# Directory locations
SRC_CS = src_cs
SPEC_CS = spec
SRC_STATIC = src_static
BIN = bin

# Environment variables
export NODE_PATH = .:$(SRC_CS)
export COFFEELINT_CONFIG = coffeelint.json

# Recursive wildcard function
# http://blog.jgc.org/2011/07/gnu-make-recursive-wildcard-function.html
rwildcard = $(foreach d,$(wildcard $1*),\
	$(call rwildcard,$d/,$2)$(filter $(subst *,%,$2),$d))

# Define compilation rules
all: lint test browser

browser: init
	# Copy static content
	cp -ra $(SRC_STATIC)/. $(BIN)
	# Compile game code
	$(BROWSERIFY) $(SRC_CS)/game.coffee -o $(BIN)/game-browser.js

init: clean
	mkdir $(BIN)

clean:
	rm -rf $(BIN)

lint:
	$(COFFEELINT) $(call rwildcard,$(SRC_CS),*.coffee) \
	              $(call rwildcard,$(SPEC_CS),*.coffee)

test:
	$(JASMINENODE) --coffee .
