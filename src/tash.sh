#!/bin/sh
# Copyright (C) 2026 emielster
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://gnu.org>.

# NOTE: Tash is meant to be POSIX-compliant and to have zero dependencies, which means
# that it should work with ANY POSIX-compliant shell without installing **ANY** external dependencies.
# However, this also has a very big disadvantage: because we cannot use Bash extensions and we can't
# use any other non-POSIX command, we miss out on a lot of (performance) opportunities (for example, we have to use
# a string based array instead of a normal Bash array, we cannot have sub-second precision timing, ...).
#
# In a future version of Tash, I might develop an option called TASH_USE_BASH_EXTENSIONS that when set to 1,
# enables us to benefit of Bash's extensions.

# Checks if a string is valid for Tash (item names, ...)
tash__is_valid_name() {
	TASH__name=$1
	case $TASH__name in
	'') return 1 ;;
	*[!A-Za-z0-9_]*) return 1 ;;
	*) return 0 ;;
	esac
}

# A POSIX alternative to mktemp
tash__mk_temp() {
	TASH__dir=${TMPDIR:-/tmp}
	TASH__i=0

	while true; do
		TASH__file="$TASH__dir/tash-${$}-${TASH__i}"

		if (
			set -C           # Sets noclobber on
			: >"$TASH__file" # Creates $file
		) 2>/dev/null; then
			printf "%s\n" "$TASH__file"
			return 0
		fi

		TASH__i=$((TASH__i + 1))
	done
}

# Checks if a scope is an descendant of an ancestor
tash__scope_is_descendant_of() {
	TASH__scope=$1
	TASH__ancestor=$2
	case "$TASH__scope" in
	"$TASH__ancestor") return 0 ;;
	"$TASH__ancestor"::*) return 0 ;;
	*) return 1 ;;
	esac
}

# Checks if you should log information about the test based on the mode
tash__should_log() {
	case "$TASH_MODE" in
	preview) return 1 ;;
	inspect)
		[ "$TASH_SCOPE" = "$TASH_INSPECTING_TEST" ]
		;;
	*) return 0 ;;
	esac
}

# Creates a readable and natural failure message for the assert
tash__failure_message() {
	TASH__item=$1
	TASH__op=$2
	TASH__expected=$3
	TASH__actual=$4

	case "$TASH__op" in
	-z)
		printf "expected %s to be empty, but it was \"%s\"" "$TASH__item" "$TASH__actual"
		;;
	-n)
		printf "expected %s to be non-empty, but it was empty" "$TASH__item"
		;;
	= | !=)
		printf "expected %s %s \"%s\", but %s is \"%s\"" "$TASH__item" "$TASH__op" "$TASH__expected" "$TASH__item" "$TASH__actual"
		;;
	contains)
		printf "expected %s contains \"%s\", but %s is \"%s\"" "$TASH__item" "$TASH__expected" "$TASH__item" "$TASH__actual"
		;;
	-eq | -ne | -gt | -lt | -ge | -le)
		TASH__words=$(tash__op_to_words "$TASH__op")
		printf "expected %s %s %s, but %s is %s" "$TASH__item" "$TASH__words" "$TASH__expected" "$TASH__item" "$TASH__actual"
		;;
	*)
		printf "expected %s %s %s, but %s is %s" "$TASH__item" "$TASH__op" "$TASH__expected" "$TASH__item" "$TASH__actual"
		;;
	esac

}

tash__op_to_words() {
	TASH__op=$1
	case "$TASH__op" in
	-eq) printf "==" ;;
	-ne) printf "!=" ;;
	-gt) printf ">" ;;
	-lt) printf "<" ;;
	-ge) printf ">=" ;;
	-le) printf "<=" ;;
	esac
}

# Is the target the last child of the parent? Needed to decide whether to
# draw +-- or |--
tash__preview_is_last() {
	TASH__target=$1
	TASH__parent=${TASH__target%::*}
	TASH__last=""
	for TASH__p in $TASH_ITEM_PATHS; do
		TASH__p_parent=${TASH__p%::*}
		if [ "$TASH__p_parent" = "$TASH__parent" ]; then
			TASH__last=$TASH__p
		fi
	done
	[ "$TASH__last" = "$TASH__target" ]
}

# Used to render a tree in preview mode
tash__preview_tree() {
	TASH__stack=""
	printf "tests\n"
	for TASH__path in $TASH_ITEM_PATHS; do
		TASH__depth=0
		TASH__rest=$TASH__path
		# Calculate the depth by doing this kinda thing
		while [ "$TASH__rest" != "${TASH__rest#*::}" ]; do
			TASH__depth=$((TASH__depth + 1))
			TASH__rest=${TASH__rest#*::}
		done

		# Shrink the stack to the current depth
		TASH__new_stack=""
		TASH__i=1
		for TASH__flag in $TASH__stack; do
			if [ "$TASH__i" -ge "$TASH__depth" ]; then
				break
			fi
			TASH__new_stack="$TASH__new_stack $TASH__flag"
			TASH__i=$((TASH__i + 1))
		done
		TASH__stack=$TASH__new_stack

		# Check if the path is the last child of its parent
		if tash__preview_is_last "$TASH__path"; then
			TASH__branch="+-- "
			TASH__this_flag=1
		else
			TASH__branch="|-- "
			TASH__this_flag=0
		fi

		# For each flag in the stack, if it already ended (1) don't use
		# a pipe, otherwise (0) use a pipe
		TASH__prefix=""
		for TASH__flag in $TASH__stack; do
			if [ "$TASH__flag" = "1" ]; then
				TASH__prefix="${TASH__prefix}    "
			else
				TASH__prefix="${TASH__prefix}│   "
			fi
		done

		TASH__name=${TASH__path##*::}
		case " $TASH_VALUE_PATHS " in
		*" $TASH__path "*)
			tash__get "$TASH__path"
			printf "%s%s%s = %s\n" "$TASH__prefix" "$TASH__branch" "$TASH__name" "$TASH__gv"
			;;
		*)
			printf "%s%s%s\n" "$TASH__prefix" "$TASH__branch" "$TASH__name"
			;;
		esac

		TASH__stack="$TASH__stack $TASH__this_flag"
	done
}

# Prints a window like this:
# +---- title -----+
# + item
# +----------------+
#
# (no + on each line, because that requires way too much work and
# possible external dependencies to handle Unicode)
tash__window() {
	TASH__title=$1
	shift

	TASH__top="+-- $TASH__title -+"
	TASH__width=${#TASH__top}
	TASH__dash_count=$((TASH__width - 2))

	TASH__bottom="+"
	TASH__i=0
	while [ "$TASH__i" -lt "$TASH__dash_count" ]; do
		TASH__bottom="${TASH__bottom}-"
		TASH__i=$((TASH__i + 1))
	done
	TASH__bottom="${TASH__bottom}+"

	printf "%s\n" "$TASH__top"
	for TASH__line in "$@"; do
		printf "| %s\n" "$TASH__line"
	done
	printf "%s\n" "$TASH__bottom"
}

# We use a var type of registry because this is POSIX compliant, we can't use
# Bash arrays or anything similar.

TASH_VALUE_PATHS=""
# Converts "tests::hello::something" to "TASH_VAR_tests__hello__something", which is valid as an
# environment variable
tash__var_name() {
	TASH__name=$1
	TASH__result=""
	# This is much faster than launching a subshell everytime.
	while [ "$TASH__name" != "${TASH__name#*::}" ]; do
		TASH__result="${TASH__result}${TASH__name%%::*}__"
		TASH__name=${TASH__name#*::}
	done
	TASH__vn="TASH_VAR_${TASH__result}${TASH__name}"
}

tash__set() {
	tash__var_name "$1"
	eval "$TASH__vn=\$2"          # From my LSP: "Don't use $ on the left side of assignments.". Therefore, this is in an eval command.
	case " $TASH_VALUE_PATHS " in # Add the value to TASH_VALUE_PATHS if it doesn't already exist, for preview mode
	*" $1 "*) ;;
	*) TASH_VALUE_PATHS="$TASH_VALUE_PATHS $1" ;;
	esac
}
tash__get() {
	tash__var_name "$1"
	eval "TASH__gv=\$$TASH__vn"
}

# See more at: https://gist.github.com/JBlond/2fea43a3049b38287e5e9cefc87b2124 (\e means \033, \e is a Bash/zsh extension)
TASH_BOLD_RED="\033[1;31m" # NOTE: not all colors are defined, only the colors that Tash needs
TASH_BOLD_GREEN="\033[1;32m"
TASH_BOLD_YELLOW="\033[1;33m"
TASH_BOLD_WHITE="\033[1;37m"
TASH_COLOR_RESET="\033[0m"

tash__log() {
	TASH__label="$1"
	TASH__color="$2"
	TASH__message="$3"
	TASH__is_error="$4"
	if [ -n "$TASH__is_error" ]; then
		printf "${TASH_BOLD_WHITE}[${TASH__color}${TASH__label}${TASH_BOLD_WHITE}] ${TASH_COLOR_RESET}%s\n" "$TASH__message" >&2
	else
		printf "${TASH_BOLD_WHITE}[${TASH__color}${TASH__label}${TASH_BOLD_WHITE}] ${TASH_COLOR_RESET}%s\n" "$TASH__message"
	fi
}
tash__success() {
	tash__log "ok" "$TASH_BOLD_GREEN" "$*"
}
tash__error() {
	tash__log "err" "$TASH_BOLD_RED" "$*" 1
}
tash__results() {
	tash__log "results" "$TASH_BOLD_YELLOW" "$*"
}
tash__hint() {
	tash__log "hint" "$TASH_BOLD_YELLOW" "$*"
}
tash__failure() {
	tash__log "failure" "$TASH_BOLD_RED" "$*" 1
}

# Terminates with an error code. In Tash, the exit code correlates directly with an error code.
# For example, E000 correlates with 0, which means success. Another example is that
# E017 correlates to 17. This neat mechanism makes it that you can search up your error
# in Tash's documentation directly from the exit code.
tash__terminate() {
	TASH__code="$1"
	printf "tash ${TASH_BOLD_RED}terminated${TASH_COLOR_RESET} with error code ${TASH_BOLD_WHITE}E%03d${TASH_COLOR_RESET}\n" "$TASH__code" >&2
	printf "info: visit ${TASH_BOLD_WHITE}https://tash.dev/error/E%03d${TASH_COLOR_RESET} for more information\n" "$TASH__code" >&2

	exit "$TASH__code"
}
TASH_E_ITEM_ARGUMENT_COUNT=1 # e.g. https://tash.dev/error/E001
TASH_E_ITEM_INVALID_NAME=2
TASH_E_END_ARGUMENT_COUNT=3
TASH_E_END_INVALID_SCOPE=4
TASH_E_VALUE_ARGUMENT_COUNT=5
TASH_E_RUN_ARGUMENT_COUNT=6
TASH_E_FAIL_ARGUMENT_COUNT=7
TASH_E_FAIL_INVALID_SCOPE=8
TASH_E_ASSERT_ARGUMENT_COUNT=9
TASH_E_ASSERT_INVALID_SCOPE=10
TASH_E_ASSERT_UNKNOWN_OPERATOR=11
TASH_E_CHECK_ARGUMENT_COUNT=12
TASH_E_TASH_FMT_ARGUMENT_COUNT=13
TASH_E_TASH_PRINT_ARGUMENT_COUNT=14
TASH_E_TASH_INIT_UNKNOWN_ARGUMENT=15
TASH_E_TASH_INIT_ARGUMENT_COUNT=16
TASH_E_TASH_END_INVALID_SCOPE=17
TASH_E_TASH_END_ARGUMENT_COUNT=18
TASH_E_TASH_END_TESTS_FAILED=19
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
		tash__terminate "$TASH_E_END_INVALID_SCOPE"
	fi

	case " $TASH_TESTS " in
	*" $TASH_SCOPE "*)
		if [ "$TASH_MODE" = "inspect" ] && [ "$TASH_SCOPE" != "$TASH_INSPECTING_TEST" ]; then
			TASH_COUNT_IGNORED=$((TASH_COUNT_IGNORED + 1))
		elif tash__should_log; then
			case " $TASH_TESTS " in
			*" $TASH_SCOPE "*)
				tash__get "${TASH_SCOPE}::__failed"
				if [ "$TASH__gv" = "1" ]; then
					TASH_COUNT_FAILED=$((TASH_COUNT_FAILED + 1))
					TASH_FAILED_TESTS="$TASH_FAILED_TESTS $TASH_SCOPE"
					tash__get "${TASH_SCOPE}::__failmessage"
					tash__failure "$TASH__gv"
				else
					TASH_COUNT_SUCCEEDED=$((TASH_COUNT_SUCCEEDED + 1))
					tash__success "$TASH_SCOPE succeeded!"
				fi

				;;
			esac
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
TASH_TMP_STDOUT=""
TASH_TMP_STDERR=""
run() {
	if [ $# -eq 0 ]; then
		tash__error "run: expected atleast one argument (command...)"
		tash__terminate "$TASH_E_RUN_ARGUMENT_COUNT"
	fi

	if [ "$TASH_MODE" = "preview" ]; then
		item "exitcode"
		end
		item "stdout"
		end
		item "stderr"
		end
		return # We don't want to run any command in preview mode.
	fi

	if [ "$TASH_MODE" = "inspect" ] && ! tash__scope_is_descendant_of "$TASH_SCOPE" "$TASH_INSPECTING_TEST"; then
		return
	fi

	"$@" 1>"$TASH_TMP_STDOUT" 2>"$TASH_TMP_STDERR" # Temporarily move 1 (stdout) to a temporary file made with mktemp, the same for
	# with 2 (stderr)

	TASH__code=$?
	item "exitcode"
	value "$TASH__code"
	end
	item "stdout"
	value "$(cat "$TASH_TMP_STDOUT")"
	end
	item "stderr"
	value "$(cat "$TASH_TMP_STDERR")"
	end

}

# Use this to manually fail tests wiht a reason
# Example:
# ```sh
# #!/bin/sh
#
# # --snip--
#	run mktemp
#	file=$(tash_print stdout)
#	if ! [ -f $file ]; then fail "expected mktemp to create file"; fi
# # --snip--
# ```
TASH_TESTS=""
TASH_FAILED_TESTS=""
TASH_COUNT_SUCCEEDED=0
TASH_COUNT_FAILED=0
TASH_COUNT_IGNORED=0
fail() {
	if [ $# -lt 1 ]; then
		tash__error "fail: expected atleast one argument (reason)"
		tash__terminate "$TASH_E_FAIL_ARGUMENT_COUNT"
	fi

	if [ "$TASH_SCOPE" = "tests" ]; then
		tash__error "fail: cannot fail globally"
		tash__hint "fail: create an item and fail in there"
		tash__terminate "$TASH_E_FAIL_INVALID_SCOPE"
	fi

	case " $TASH_TESTS " in
	*" $TASH_SCOPE "*) ;;
	*) TASH_TESTS="$TASH_TESTS $TASH_SCOPE" ;;
	esac

	if [ "$TASH_MODE" = "inspect" ] && ! tash__scope_is_descendant_of "$TASH_SCOPE" "$TASH_INSPECTING_TEST"; then
		return
	fi

	tash__get "${TASH_SCOPE}::__failed"
	if [ "$TASH__gv" = "1" ] || [ "$TASH_MODE" = "preview" ]; then
		return 0
	fi

	tash__set "${TASH_SCOPE}::__failed" "1"
	tash__set "${TASH_SCOPE}::__failscope" "$TASH_SCOPE"
	tash__set "${TASH_SCOPE}::__failmessage" "$*"
}

# Use this to compare an item relative to the scope, with a value. Fails the test if this the comparison
# is not true. This turns the current scope into a test, if not already.
# Mimics POSIX test(1), plus contains for substrings
#	+-----operator-----+--------description------+
#	| = / !=           | string (in)equality	 |
#	| -eq -ne          | numeric (in)equality    |
#	| -gt -lt -ge -le  | numeric comparison      |
#	| -z -n            | empty / non-empty       |
#	| contains         | item contains substring |
#	+--------------------------------------------+
# Example:
# ```sh
# #!/bin/sh
#
# # --snip--
# item "my_test"
#	 run echo "hello" # Creates subitems stdout, stderr and exitcode.
#	 assert stdout = "hello" # my_test is now a test
#	 assert exitcode -eq 0
#	 asset stdout contains "lo"
# end
#
# # --snip--
# ```
assert() {
	if [ $# -lt 2 ]; then
		tash__error "assert: expected atleast two arguments (item, operator, [expected])"
		tash__terminate "$TASH_E_ASSERT_ARGUMENT_COUNT"
	fi

	if [ "$TASH_SCOPE" = "tests" ]; then
		tash__error "assert: cannot assert globally"
		tash__hint "assert: create an item and assert in there"
		tash__terminate "$TASH_E_ASSERT_INVALID_SCOPE"
	fi

	case " $TASH_TESTS " in
	*" $TASH_SCOPE "*) ;;
	*) TASH_TESTS="$TASH_TESTS $TASH_SCOPE" ;;
	esac

	if [ "$TASH_MODE" = "inspect" ] && ! tash__scope_is_descendant_of "$TASH_SCOPE" "$TASH_INSPECTING_TEST"; then
		return
	fi
	case $1 in
	-z | -n)
		TASH__op=$1
		TASH__item=$2
		TASH__expected=""
		;;
	*)
		TASH__item=$1
		TASH__op=$2
		TASH__expected=$3
		;;
	esac

	tash__get "${TASH_SCOPE}::__failed"
	if [ "$TASH__gv" = "1" ] || [ "$TASH_MODE" = "preview" ]; then
		return # If already failed, you skip the remaining asserts OR if mode is preview
	fi

	TASH__resolved="${TASH_SCOPE}::${TASH__item}"
	tash__get "$TASH__resolved"
	TASH__actual=$TASH__gv

	TASH__ok=0
	case "$TASH__op" in
	= | != | -eq | -ne | -gt | -lt | -ge | -le)
		[ "$TASH__actual" "$TASH__op" "$TASH__expected" ] && TASH__ok=1
		;;
	-z | -n)
		[ "$TASH__op" "$TASH__actual" ] && TASH__ok=1
		;;
	contains)
		case "$TASH__actual" in *"$TASH__expected"*) TASH__ok=1 ;; esac
		;;
	*)
		tash__error "assert: unknown operator '$TASH__op'"
		tash__terminate "$TASH_E_ASSERT_UNKNOWN_OPERATOR"
		;;
	esac

	if [ "$TASH__ok" = "1" ]; then return 0; fi

	fail "$(tash__failure_message "$TASH__item" "$TASH__op" "$TASH__expected" "$TASH__actual")"

}

# Use this to quickly assert stdout, stderr and
# exitcode in this order: check exitcode [stdout] [stderr].
# It is the equivalent to:
# assert exitcode -eq N
# assert stdout contains [...]
# assert stderr contains [...]
# Example:
# ```sh
# #!/bin/sh
# # --snip--
# run echo "hello"
# check 0 "hello"
# # --snip--
#
# ```
check() {
	if [ $# -lt 1 ] || [ $# -gt 3 ]; then
		tash__error "check: expected one to three arguments (exitcode, [stdout], [stderr])"
		tash__terminate "$TASH_E_CHECK_ARGUMENT_COUNT"
	fi

	assert exitcode -eq "$1"
	if [ $# -ge 2 ]; then
		assert stdout contains "$2"
	fi
	if [ $# -ge 3 ]; then
		assert stderr contains "$3"
	fi
}
# Use this to format and interpret \n, \t, ... inside a string
# Foreshadowing: it is just printf but different.
# This is because POSIX shell interprets this:
# ```sh
# #!/bin/sh
# # --snip--
#	assert stdout = "hello\nworld"
# # --snip--
# ```
# Literally as "hello\nworld" and not "hello
# world"
# printf fixes this, but it is a bit weird and unexplaining.
# Therefore, Tash provides a wrapper around it.
# Example:
# ```sh
# #!/bin/sh
# # --snip--
#	assert stdout = "$(tash_fmt "hello\nworld")" # launch it in a subshell
# # --snip--
# ```
tash_fmt() {
	if [ $# -ne 1 ]; then
		tash__error "tash_fmt: expected exactly one argument (string)"
		tash__terminate "$TASH_E_TASH_FMT_ARGUMENT_COUNT"
	fi
	printf '%b' "$1"
}

# Use this to print and internal variable of Tash.
# Example:
# ```
# #!/bin/sh
#
# # --snip--
#	run mktemp
#	file=$(tash_print stdout)
#
# # --snip--
# ```
tash_print() {
	if [ $# -ne 1 ]; then
		tash__error "tash_print: expected exactly one argument (item)"
		tash__terminate "$TASH_E_TASH_PRINT_ARGUMENT_COUNT"
	fi

	tash__get "${TASH_SCOPE}::$1"
	printf "%s\n" "$TASH__gv"
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
		--inspect)
			if [ "$#" -ne 2 ]; then
				tash__error "tash_init: you must specify exactly one test that you want to inspect"
				tash__hint "tash_init: run $0 -h | --help for help"
				tash__terminate "$TASH_E_TASH_INIT_ARGUMENT_COUNT"
			fi
			TASH_MODE="inspect"
			TASH_INSPECTING_TEST="$2"
			;;
		-V | --version)
			printf "tash ${TASH_BOLD_WHITE}v0.1.1${TASH_COLOR_RESET} (semver)\n"
			tash__hint "run $0 -h | --help for help"
			exit 0
			;;
		-h | --help)
			# The help message uses docopt, a command line interface description language.
			# If you are intrested: https://docopt.org
			printf "${TASH_BOLD_WHITE}Tash${TASH_COLOR_RESET}\n"
			printf "${TASH_BOLD_WHITE}T${TASH_COLOR_RESET}est ${TASH_BOLD_WHITE}A${TASH_COLOR_RESET}utomation for ${TASH_BOLD_WHITE}SH${TASH_COLOR_RESET}ell\n"
			printf "\n"
			printf "${TASH_BOLD_WHITE}Usage:${TASH_COLOR_RESET}\n"
			printf "\t$0 --preview\n"
			printf "\t$0 --inspect <test>\n"
			printf "\t$0 -V | --version\n"
			printf "\t$0 -h | --help\n"
			printf "${TASH_BOLD_WHITE}Options:${TASH_COLOR_RESET}\n"
			printf "\t-h --help\tShow this screen.\n"
			printf "\t-V --version\tShow version.\n"
			printf "\t--preview\tPreview tests in a tree instead of running them.\n"
			printf "\t--inspect\tInspect a test by only running that test.\n"
			tash__hint "GitHub repository at https://github.com/emielster/tash"
			tash__hint "documentation at https://tash.dev"
			exit 0 # If you're intrested: https://docopt.org
			;;
		*)
			if [ "$TASH_MODE" = "inspect" ]; then continue; fi
			tash__error "tash_init: unknown argument '$arg'"
			tash__hint "tash_init: run $0 -h | --help for help"
			tash__terminate "$TASH_E_TASH_INIT_UNKNOWN_ARGUMENT"
			;;
		esac

	done

	TASH_TMP_STDOUT=$(tash__mk_temp)
	TASH_TMP_STDERR=$(tash__mk_temp)

	trap 'rm -f "$TASH_TMP_STDOUT" "$TASH_TMP_STDERR"' 0 # Make sure they get cleaned up
	TASH_START=$(date +%s)
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
	if [ $# -ne 0 ]; then
		tash__error "tash_end: expected zero arguments"
		tash__terminate "$TASH_E_TASH_END_ARGUMENT_COUNT"
	fi
	if ! [ "$TASH_SCOPE" = "tests" ]; then
		tash__error "tash_end: scope must be exactly \"tests\""
		tash__hint "tash_end: did you forget to end one of your items?"
		tash__terminate "$TASH_E_TASH_END_INVALID_SCOPE"
	fi
	if [ "$TASH_MODE" = "preview" ]; then
		tash__preview_tree
		exit 0
	fi

	TASH_END=$(date +%s)
	TASH__elapsed=$((TASH_END - TASH_START))
	tash__results "${TASH_COUNT_SUCCEEDED} succeeded, ${TASH_COUNT_FAILED} failed, ${TASH_COUNT_IGNORED} ignored (took ${TASH__elapsed}s)"

	if [ "$TASH_MODE" = "inspect" ]; then
		for TASH__path in $TASH_ITEM_PATHS; do
			if tash__scope_is_descendant_of "$TASH__path" "$TASH_INSPECTING_TEST"; then
				case " $TASH_VALUE_PATHS " in
				*" $TASH__path "*)
					tash__get "$TASH__path"
					tash__window "inspection: $TASH__path" "${TASH__gv:-"(empty)"}"
					;;
				esac
			fi
		done

	else
		for TASH__path in $TASH_FAILED_TESTS; do
			tash__get "${TASH__path}::__failscope"
			TASH__run_scope=$TASH__gv
			tash__get "${TASH__run_scope}::stdout"
			TASH__stdout=$TASH__gv
			tash__get "${TASH__run_scope}::stderr"
			TASH__stderr=$TASH__gv
			if [ -n "$TASH__stdout" ] || [ -n "$TASH__stderr" ]; then
				tash__window "$TASH__path" \
					"$(printf "stdout: %s" "${TASH__stdout:-"(empty)"}")" \
					"$(printf "stderr: %s" "${TASH__stderr:-"(empty)"}")"
				printf "\n"
			fi
		done
	fi

	if [ "$TASH_COUNT_FAILED" -gt 0 ]; then
		exit "$TASH_E_TASH_END_TESTS_FAILED"
	else
		exit 0
	fi

}
