Flood-It Game and Solver
========================

Currently this project contains a (okay) flood-it game solver, but no UI for it
(yet). All implementation is in coffeescript. The end result should run in any
decently modern webbrowser.

Installing Dependencies
-----------------------

On Debian you should install nodejs with `aptitude install nodejs
nodejs-legacy`.

On all systems, after you have nodejs installed, from within the repository,
`npm install` (does not need root) will install all additional dependencies
locally into `node_modules/`. You may need to use `npm install -f` to force a
complete installation.

Makefile Targets
----------------

* **all:** Running `make` with no arguments will lint the code, run unittests,
  and then build the browser version
* **browser:** Running `make browser` will use
  [browserify](https://github.com/substack/node-browserify) to build a
  browser-ready version of our code to `bin/`
* **test:** Running `make test` will run unit tests
* **lint:** Running `make lint` will run [coffeelint](http://coffeelint.org/)
  over the sourcecode to check that coding standards are being followed
* **clean:** Running `make clean` removes all binaries
