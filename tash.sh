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

TASH_VALUE_PATHS=""
# Converts "tests::hello::something" to "TASH_VAR_tests__hello__something", which is valid as an
# environment variable
tash__var_name() {
	printf "%s" "TASH_VAR_$(printf "%s" "$1" | sed 's/::/__/g')"
}

tash__set() {
	var=$(tash__var_name "$1")
	eval "$var=\$2"               # From my LSP: "Don't use $ on the left side of assignments.". Therefore, this is in an eval command.
	case " $TASH_VALUE_PATHS " in # Add the value to TASH_VALUE_PATHS if it doesn't already exist, for preview mode
	*" $1 "*) ;;
	*) TASH_VALUE_PATHS="$TASH_VALUE_PATHS $1" ;;
	esac
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
tash__failure() {
	tash__log "failure" "$TASH_BOLD_RED" "$*"
}

# Terminates with an error code. In Tash, the exit code correlates directly with an error code.
# For example, E000 correlates with 0, which means success. Another example is that
# E017 correlates to 17. This neat mechanism makes it that you can search up your error
# in Tash's documentation directly from the exit code.
tash__terminate() {
	code="$1"
	printf "tash ${TASH_BOLD_RED}terminated${TASH_COLOR_RESET} with error code ${TASH_BOLD_WHITE}E%03d${TASH_COLOR_RESET}\n" "$code"
	printf "info: visit ${TASH_BOLD_WHITE}https://tash.dev/error/E%03d${TASH_COLOR_RESET} for more information\n" "$code"

	exit "$code"
}
TASH_E_ITEM_ARGUMENT_COUNT=1 # e.g. https://tash.dev/error/E001
TASH_E_ITEM_INVALID_NAME=2
TASH_E_END_ARGUMENT_COUNT=3
TASH_E_END_GLOBAL_SCOPE=4
TASH_E_VALUE_ARGUMENT_COUNT=5
TASH_E_RUN_ARGUMENT_COUNT=6
TASH_E_ASSERT_EQ_ARGUMENT_COUNT=7
TASH_E_ASSERT_EQ_INVALID_SCOPE=8
TASH_E_TASH_INIT_UNKNOWN_ARGUMENT=9
TASH_E_TASH_END_INVALID_SCOPE=10
# In Bash, you would use an array, but since Tash should work with **any**
# POSIX-compliant shell, we can't use any of the Bash extensions, including arrays.
TASH_SCOPE="tests" # Start at the tests scope. Treat this as the global scope for everything.
TASH_MODE="run"

# Use this to declare an item inside of the current scope. The item could be anything.
# Example:
# ```sh
# #!/bin/sh
# # --snip--
#
# item my_item # Create item "my_item" inside of the scope "tests"
#
# end
#
# # --snip--
# ```
TASH_ITEM_PATHS=""
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
	case " $TASH_ITEM_PATHS " in # This will add the tash scope to TASH_ITEM_PATHS if it doesn't already exist.
	*" $TASH_SCOPE "*) ;;
	*) TASH_ITEM_PATHS="$TASH_ITEM_PATHS $TASH_SCOPE" ;;
	esac
}

# Use this to end an items scope.
# Example:
# ```sh
# #!/bin/sh
#
# # --snip--
# # Scope is "tests"
#
# item my_test
#
# # Scope is "tests::my_test"
#
# end # End my_test's scope.
#
# # Scope is "tests"
#
# # --snip--
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

	case " $TASH_TESTS " in
	*" $TASH_SCOPE "*)
		if [ "$(tash__get "${TASH_SCOPE}::__failed")" = "1" ]; then
			TASH_COUNT_FAILED=$((TASH_COUNT_FAILED + 1))
			TASH_FAILED_TESTS="$TASH_FAILED_TESTS $TASH_SCOPE"
			tash__failure "$TASH_SCOPE $(tash__get "${TASH_SCOPE}::__failmsg")"
		else
			TASH_COUNT_SUCCEEDED=$((TASH_COUNT_SUCCEEDED + 1))
			tash__success "$TASH_SCOPE succeeded!"
		fi

		;;
	esac
	TASH_SCOPE="${TASH_SCOPE%::*}"
}

# Use this to set the current scope to a value. This is implicitly used by `run` to write ::exitcode, ::stdout and ::stderr.
# This is an immediate operation.
# Example:
# ```sh
# #!/bin/sh
# # --snip--
# item my_value
#     value 5 # tests::my_value is now set to 5
# end
# # --snip--
# ```
value() {
	if [ $# -ne 1 ]; then
		tash__error "value: expected exactly one argument (value)"
		tash__terminate "$TASH_E_VALUE_ARGUMENT_COUNT"
	fi

	tash__set "$TASH_SCOPE" "$1"
}

# Use this to run a command and set ::exitcode, ::stdout and ::stderr of the current
# scope. This is an immediate operation.
# Example:
# ```sh
# #!/bin/sh
# # --snip--
#
# item my_test
#    run ./myscript.sh arg1 arg2 # my_test::stdout, my_test::stderr and my_test::exitcode are all set after this command
# end
#
# ```
run() {
	if [ $# -eq 0 ]; then
		tash__error "run: expected atleast one argument (command...)"
		tash__terminate "$TASH_E_RUN_ARGUMENT_COUNT"
	fi

	if [ "$TASH_MODE" = "preview" ]; then
		return # We don't want to run any command in preview mode.
	fi

	#TODO: There might be some better way to do this.
	# This creates two temporary files on each run command, which is, slow.
	tmp_stdout=$(mktemp)
	tmp_stderr=$(mktemp)
	"$@" 1>"$tmp_stdout" 2>"$tmp_stderr" # Temporarily move 1 (stdout) to a temporary file made with mktemp, the same for
	# with 2 (stderr)

	code=$?
	item "exitcode"
	value "$code"
	end
	item "stdout"
	value "$(cat "$tmp_stdout")"
	end
	item "stderr"
	value "$(cat "$tmp_stderr")"
	end
	rm -f "$tmp_stdout" "$tmp_stderr"

}

# Use this to compare an item relative to the scope, with a value. Fails the test if this the comparison
# is not true. This turns the current scope into a test, if not already.
# Example:
# ```sh
# #!/bin/sh
#
# # --snip--
# item "my_test"
#	 run echo "hello" # Creates subitems stdout, stderr and exitcode.
#	 assert_eq stdout "hello" # my_test is now a test
# end
# # --snip--
# ```
TASH_TESTS=""
TASH_FAILED_TESTS=""
TASH_COUNT_SUCCEEDED=0
TASH_COUNT_FAILED=0
TASH_COUNT_IGNORED=0 #TODO
assert_eq() {
	if [ $# -ne 2 ]; then
		tash__error "assert_eq: expected exactly two arguments (item, expected_value)"
		tash__terminate "$TASH_E_ASSERT_EQ_ARGUMENT_COUNT"
	fi

	if [ "$TASH_SCOPE" = "tests" ]; then
		tash__error "assert_eq: cannot assert globally"
		tash__hint "assert_eq: create an item and assert in there"
		tash__terminate "$TASH_E_ASSERT_EQ_INVALID_SCOPE"
	fi

	# Yes, you can assert_eq and do runs in global tests scope. Nothing is stopping you.
	case " $TASH_TESTS " in
	*" $TASH_SCOPE "*) ;;
	*) TASH_TESTS="$TASH_TESTS $TASH_SCOPE" ;;
	esac

	if [ "$(tash__get "${TASH_SCOPE}::__failed")" = "1" ]; then
		return 0 # If already failed, you skip the remaining asserts
	fi

	item=$1
	expected_value=$2
	actual_value=$(tash__get "${TASH_SCOPE}::${item}")

	if [ "$actual_value" = "$expected_value" ]; then
		return 0
	fi

	tash__set "${TASH_SCOPE}::__failed" "1"
	tash__set "${TASH_SCOPE}::__failmsg" "panicked at assert_eq $item \"${expected_value}\""

}

# Use this to initialize Tash, preferably with all the arguments of your program passed into it.
# Example:
# ```sh
# #!/bin/sh
# tash_init "$@" # Pass all your arguments with it
#
# # --snip--
# ```
tash_init() {
	for arg in "$@"; do
		case "$arg" in
		--preview) TASH_MODE="preview" ;;
		-V | --version)
			tash__error "todo"
			exit 0
			;;
		-h | --help)
			tash__success "todo" # The help message uses docopt, a command line interface description language.
			exit 0               # If you're intrested: https://docopt.org
			;;
		*)
			tash__error "tash_init: unknown argument '$arg'"
			tash__hint "tash_init: run $0 --help|-h for help"
			tash__terminate "$TASH_E_TASH_INIT_UNKNOWN_ARGUMENT"
			;;
		esac

	done
}

# Use this to end Tash, after you are done with it.
# Example:
# ```sh
# #!/bin/sh
# tash_init "$@"
# # --snip--
# tash_end # When you are done with it
#
# ```
tash_end() {
	if ! [ "$TASH_SCOPE" = "tests" ]; then
		tash__error "tash_end: scope must be exactly \"tests\""
		tash__hint "tash_end: did you forget to end one of your items?"
		tash__terminate "$TASH_E_TASH_END_INVALID_SCOPE"
	fi
}
