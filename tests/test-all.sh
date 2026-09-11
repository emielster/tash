#!/bin/sh

# Test tash-tests.sh for all POSIX-compatible shells,
# e.g. zsh, ksh, dash, bash...

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SHELLS="dash bash ksh zsh"
FAILED=0

GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
WHITE="\033[1;37m"
RESET="\033[0m"

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
	if ! command -v "$shell" >/dev/null 2>&1; then
		skip "skipping '${shell}' because it is not found on this system."
	fi
	doing "running under ${shell}"
	if "$shell" "$SCRIPT_DIR/tash-tests.sh"; then
		ok "${shell} passed"
	else
		fail "${shell} failed! ($?)"
		FAILED=1
	fi

done

if [ "$FAILED" -eq 0 ]; then
	ok "all shells passed!"
	exit 0
else
	fail "one or more shells failed..." 1>&2
	exit 1
fi
