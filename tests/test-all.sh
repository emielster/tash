#!/bin/sh

# Test tash-tests.sh for all POSIX-compatible shells,
# e.g. zsh, ksh, dash, bash...

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SHELLS="dash bash ksh zsh mksh yash"
FAILED=0

GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
WHITE="\033[1;37m"
RESET="\033[0m"

run_under() {
	if ! command -v "$1" >/dev/null 2>&1; then
		skip "skipping '${1}' because it is not found on this system."
		return
	fi
	doing "running under $*"
	if "$@" "$SCRIPT_DIR/tash-tests.sh"; then
		ok "$* passed"
	else
		fail "$* failed! ($?)"
		FAILED=1
	fi
}

skip() {
	printf "${WHITE}[${YELLOW}SHELL SKIP${WHITE}]${RESET} %s\n" "$*"
}

doing() {
	printf "${WHITE}[${YELLOW}SHELL DOING${WHITE}]${RESET} %s\n" "$*"
}

ok() {
	printf "${WHITE}[${GREEN}SHELL SUCCESS${WHITE}]${RESET} %s\n" "$*"
}

fail() {
	printf "${WHITE}[${RED}SHELL FAIL${WHITE}]${RESET} %s\n" "$*" 1>&2
}

for shell in $SHELLS; do
	run_under "$shell"
done
run_under busybox ash

if [ "$FAILED" -eq 0 ]; then
	ok "all shells passed!"
	exit 0
else
	fail "one or more shells failed..." 1>&2
	exit 1
fi
