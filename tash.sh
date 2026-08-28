#!/bin/sh

#********************************************************************************************************#
# TASH
# Test Automation for Shell
#
# A testing framework that doesn't throw your tests in the trash.
#
# This test framework is POSIX-compliant, which
# means it should work with zsh, ksh, dash, bash, ...
#
# Tash is documented at https://github.com/emielster/tash
#********************************************************************************************************#

# Checks if a string is valid for Tash (item names, ...)
tash__is_valid_name() {
	case $1 in
	'') return 1 ;;
	*[!A-Za-z0-9_]*) return 1 ;;
	*) return 0 ;;
	esac
}

# We use a var-type of registry because this is POSIX compliant, we can't use
# Bash arrays or anything similar.

# Converts "tests::hello::something" to "TASH_VAR_tests__hello__something", which is valid as an
# environment variable
tash__var_name() {
	printf "%s" "TASH_VAR_$(printf "%s" "$1" | sed 's/::/__/g')"
}

tash__set() {
	var=$(tash__var_name "$1")
	eval "$var=\$2" # From my LSP: "Don't use $ on the left side of assignments.". Therefore, this is in an eval command.
}
tash__get() {
	var=$(tash__var_name "$1")
	eval "printf '%s\n' \"\$$var\""
}

# See more at: https://gist.github.com/JBlond/2fea43a3049b38287e5e9cefc87b2124 (\e means \033, \e is a Bash/zsh extension)
TASH_BOLD_RED="\033[1;31m" # NOTE: not all colors are defined, only the colors that Tash needs
TASH_BOLD_GREEN="\033[1;32m"
TASH_BOLD_YELLOW="\033[1;33m"
TASH_BOLD_WHITE="\033[1;37m"
TASH_COLOR_RESET="\033[0m"

tash__log() {
	label="$1"
	color="$2"
	message="$3"
	printf "${TASH_BOLD_WHITE}[${color}${label}${TASH_BOLD_WHITE}] ${TASH_COLOR_RESET}%s\n" "$message"
}
tash__success() {
	tash__log "ok" "$TASH_BOLD_GREEN" "$*"
}
tash__error() {
	tash__log "err" "$TASH_BOLD_RED" "$*"
}
tash__hint() {
	tash__log "hint" "$TASH_BOLD_YELLOW" "$*"
}

# Terminates with an error code. In Tash, the exit code correlates directly with an error code.
# For example, E000 correlates with 0, which means success. Another example is that
# E017 correlates to 17. This neat mechanism makes it that you can search up your error
# in Tash's documentation directly from the exit code.
tash__terminate() {
	code="$1"
	printf "tash terminated with error code E%03d\n" "$code"
	printf "info: visit https://tash.dev/error/E%03d for more information\n" "$code"

	exit "$code"
}
TASH_E_ITEM_ARGUMENT_COUNT=1 # e.g. https://tash.dev/error/E001
TASH_E_ITEM_INVALID_NAME=2
TASH_E_END_ARGUMENT_COUNT=3
TASH_E_END_GLOBAL_SCOPE=4
TASH_E_VALUE_ARGUMENT_COUNT=5
TASH_E_TASH_RUN_INVALID_SCOPE=6
# In Bash, you would use an array, but since Tash should work with **any**
# POSIX-compliant shell, we can't use any of the Bash extensions, including arrays.
TASH_SCOPE="tests" # Start at the tests scope. Treat this as the global scope for everything.

# Use this to declare an item inside of the current scope. The item could be anything.
# Example:
# ```sh
# #!/bin/sh
#
# item my_item # Create item "my_item" inside of the scope "tests"
#
# end
# ```
item() {
	if [ $# -ne 1 ]; then
		tash__error "item: expected exactly one argument (name)"
		tash__terminate "$TASH_E_ITEM_ARGUMENT_COUNT"
	fi

	if ! tash__is_valid_name "$1"; then
		tash__error "item: name must match [A-Za-z0-9_]+"
		tash__hint "item: don't use spaces, colons or slashes or anything similar"
		tash__terminate "$TASH_E_ITEM_INVALID_NAME"
	fi
	TASH_SCOPE="${TASH_SCOPE}::$1"
}

# Use this to end an items scope.
# Example:
# ```sh
# #!/bin/sh
#
# # Scope is "tests"
#
# item my_test
#
# # Scope is "tests::my_test"
#
# end # End my_test's scope.
#
# # Scope is "tests"
# ```
end() {
	if [ $# -ne 0 ]; then
		tash__error "end: expected zero arguments"
		tash__terminate "$TASH_E_END_ARGUMENT_COUNT"
	fi

	if [ "$TASH_SCOPE" = "tests" ]; then
		tash__error "end: cannot exit out of the global scope"
		tash__terminate "$TASH_E_END_GLOBAL_SCOPE"
	fi

	TASH_SCOPE="${TASH_SCOPE%::*}"
}

# Use this to set the current scope to a value. This is implicitly used by `run` to write ::exit_code, ::stdout and ::stderr.
# This is an immediate operation.
# Example:
# ```sh
# #!/bin/sh
# item my_value
#     value 5 # tests::my_value is now set to 5
# end
# ```
value() {
	if [ $# -ne 1 ]; then
		tash__error "value: expected exactly one argument (value)"
		tash__terminate "$TASH_E_VALUE_ARGUMENT_COUNT"
	fi

	tash__set "$TASH_SCOPE" "$1"
}

# Use this to run Tash, preferably with all the arguments of your program passed into it.
# Example:
# ```sh
# #!/bin/sh
# item my_test
#
# end
# tash_run "$@" # Pass all your arguments with it
# ```
tash_run() {
	if ! [ "$TASH_SCOPE" = "tests" ]; then
		tash__error "tash_run: scope must be exactly \"tests\""
		tash__hint "tash_run: did you forget to end one of your items?"
		tash__terminate "$TASH_E_TASH_RUN_INVALID_SCOPE"
	fi
}
