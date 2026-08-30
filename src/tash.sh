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

# NOTE: Tash is meant to be POSIX-compliant and dependency-less, which means
# that it should work with ANY POSIX-compliant shell without installing ANY external dependencies.
# However, this also has a big disadvantage: because we can't use Bash extensions and we can't
# use any other non-POSIX command, we miss out on a lot of (performance) opportunities (for example, we have to use
# a string-based array instead of a normal Bash-array, we cannot have sub-second precision timing, ...).
#
# In a future version of Tash, I might develop an option called TASH_USE_BASH_EXTENSIONS that when set to 1,
# enables us to benefit of Bash's extensions.

# Checks if a string is valid for Tash (item names, ...)
tash__is_valid_name() {
	name=$1
	case $name in
	'') return 1 ;;
	*[!A-Za-z0-9_]*) return 1 ;;
	*) return 0 ;;
	esac
}

# Checks if a scope is an descendant of an ancestor
tash__scope_is_descendant_of() {
	scope=$1
	ancestor=$2
	case "$scope" in
	"$ancestor") return 0 ;;
	"$ancestor"::*) return 0 ;;
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
	item=$1
	op=$2
	expected=$3
	actual=$4

	case "$op" in
	-z)
		printf "expected %s to be empty, but it was \"%s\"" "$item" "$actual"
		;;
	-n)
		printf "expected %s to be non-empty, but it was empty" "$item"
		;;
	= | !=)
		printf "expected %s %s \"%s\", but %s is \"%s\"" "$item" "$op" "$expected" "$item" "$actual"
		;;
	contains)
		printf "expected %s contains \"%s\", but %s is \"%s\"" "$item" "$expected" "$item" "$actual"
		;;
	-eq | -ne | -gt | -lt | -ge | -le)
		words=$(tash__op_to_words "$op")
		printf "expected %s %s %s, but %s is %s" "$item" "$words" "$expected" "$item" "$actual"
		;;
	*)
		printf "expected %s %s %s, but %s is %s" "$item" "$op" "$expected" "$item" "$actual"
		;;
	esac

}

tash__op_to_words() {
	case "$1" in
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
	target=$1
	parent=${target%::*}
	last=""
	for p in $TASH_ITEM_PATHS; do
		p_parent=${p%::*}
		if [ "$p_parent" = "$parent" ]; then
			last=$p
		fi
	done
	[ "$last" = "$target" ]
}

# Used to render a tree in preview mode
tash__preview_tree() {
	stack=""
	printf "tests\n"
	for path in $TASH_ITEM_PATHS; do
		depth=0
		rest=$path
		# Calculate the depth by doing this kinda thing
		while [ "$rest" != "${rest#*::}" ]; do
			depth=$((depth + 1))
			rest=${rest#*::}
		done

		# Shrink the stack to the current depth
		new_stack=""
		i=1
		for flag in $stack; do
			if [ "$i" -ge "$depth" ]; then
				break
			fi
			new_stack="$new_stack $flag"
			i=$((i + 1))
		done
		stack=$new_stack

		# Check if the path is the last child of its parent
		if tash__preview_is_last "$path"; then
			branch="+-- "
			this_flag=1
		else
			branch="|-- "
			this_flag=0
		fi

		# For each flag in the stack, if it already ended (1) don't use
		# a pipe, otherwise (0) use a pipe
		prefix=""
		for flag in $stack; do
			if [ "$flag" = "1" ]; then
				prefix="${prefix}    "
			else
				prefix="${prefix}│   "
			fi
		done

		name=${path##*::}
		case " $TASH_VALUE_PATHS " in
		*" $path "*)
			val=$(tash__get "$path")
			printf "%s%s%s = %s\n" "$prefix" "$branch" "$name" "$val"
			;;
		*)
			printf "%s%s%s\n" "$prefix" "$branch" "$name"
			;;
		esac

		stack="$stack $this_flag"
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
	title=$1
	shift

	top="+-- $title -+"
	width=${#top}
	dash_count=$((width - 2))

	bottom="+"
	i=0
	while [ "$i" -lt "$dash_count" ]; do
		bottom="${bottom}-"
		i=$((i + 1))
	done
	bottom="${bottom}+"

	printf "%s\n" "$top"
	for line in "$@"; do
		printf "| %s\n" "$line"
	done
	printf "%s\n" "$bottom"
}

# We use a var type of registry because this is POSIX compliant, we can't use
# Bash arrays or anything similar.

TASH_VALUE_PATHS=""
# Converts "tests::hello::something" to "TASH_VAR_tests__hello__something", which is valid as an
# environment variable
tash__var_name() {
	name=$1
	printf "%s" "TASH_VAR_$(printf "%s" "$name" | sed 's/::/__/g')"
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
tash__results() {
	tash__log "results" "$TASH_BOLD_YELLOW" "$*"
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
TASH_E_ASSERT_ARGUMENT_COUNT=7
TASH_E_ASSERT_INVALID_SCOPE=8
TASH_E_ASSERT_UNKNOWN_OPERATOR=9
TASH_E_TASH_INIT_UNKNOWN_ARGUMENT=10
TASH_E_TASH_INIT_ARGUMENT_COUNT=11
TASH_E_TASH_END_INVALID_SCOPE=12
TASH_E_TASH_END_TESTS_FAILED=13
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
		if [ "$TASH_MODE" = "inspect" ] && [ "$TASH_SCOPE" != "$TASH_INSPECTING_TEST" ]; then
			TASH_COUNT_IGNORED=$((TASH_COUNT_IGNORED + 1))
		elif tash__should_log; then
			case " $TASH_TESTS " in
			*" $TASH_SCOPE "*)
				if [ "$(tash__get "${TASH_SCOPE}::__failed")" = "1" ]; then
					TASH_COUNT_FAILED=$((TASH_COUNT_FAILED + 1))
					TASH_FAILED_TESTS="$TASH_FAILED_TESTS $TASH_SCOPE"
					failitem=$(tash__get "${TASH_SCOPE}::__failitem")
					failop=$(tash__get "${TASH_SCOPE}::__failop")
					failexpected=$(tash__get "${TASH_SCOPE}::__failexpected")
					failactual=$(tash__get "${TASH_SCOPE}::__failactual")
					tash__failure "$(tash__failure_message "$failitem" "$failop" "$failexpected" "$failactual")"
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

	#TODO: There might be some better way to do this.
	# This creates two temporary files on each run command, which is, slow.
	"$@" 1>"$TASH_TMP_STDOUT" 2>"$TASH_TMP_STDERR" # Temporarily move 1 (stdout) to a temporary file made with mktemp, the same for
	# with 2 (stderr)

	code=$?
	item "exitcode"
	value "$code"
	end
	item "stdout"
	value "$(cat "$TASH_TMP_STDOUT")"
	end
	item "stderr"
	value "$(cat "$TASH_TMP_STDERR")"
	end

}

# Use this to compare an item relative to the scope, with a value. Fails the test if this the comparison
# is not true. This turns the current scope into a test, if not already.
# Mimics POSIX test(1), plus :contains for substrings
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
TASH_TESTS=""
TASH_FAILED_TESTS=""
TASH_COUNT_SUCCEEDED=0
TASH_COUNT_FAILED=0
TASH_COUNT_IGNORED=0
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
		op=$1
		item=$2
		expected=""
		;;
	*)
		item=$1
		op=$2
		expected=$3
		;;
	esac

	if [ "$(tash__get "${TASH_SCOPE}::__failed")" = "1" ] || [ "$TASH_MODE" = "preview" ]; then
		return 0 # If already failed, you skip the remaining asserts OR if mode is preview
	fi

	resolved="${TASH_SCOPE}::${item}"
	actual=$(tash__get "$resolved")

	ok=0
	case "$op" in
	= | != | -eq | -ne | -gt | -lt | -ge | -le)
		[ "$actual" "$op" "$expected" ] && ok=1
		;;
	-z | -n)
		[ "$op" "$actual" ] && ok=1
		;;
	contains)
		case "$actual" in *"$expected"*) ok=1 ;; esac
		;;
	*)
		tash__error "assert: unknown opertor '$op'"
		tash__terminate "$TASH_E_ASSERT_UNKNOWN_OPERATOR"
		;;
	esac

	if [ "$ok" = "1" ]; then return 0; fi

	tash__set "${TASH_SCOPE}::__failed" "1"
	tash__set "${TASH_SCOPE}::__failpath" "$resolved"
	tash__set "${TASH_SCOPE}::__failitem" "$item"
	tash__set "${TASH_SCOPE}::__failop" "$op"
	tash__set "${TASH_SCOPE}::__failexpected" "$expected"
	tash__set "${TASH_SCOPE}::__failactual" "$actual"

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
			TASH_INSPECTING_TEST="tests::$2"
			;;
		-V | --version)
			printf "tash ${TASH_BOLD_WHITE}v0.0.1${TASH_COLOR_RESET} (semver)\n"
			tash__hint "run $0 --h | --help for help"
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

	TASH_TMP_STDOUT=$(mktemp)
	TASH_TMP_STDERR=$(mktemp)

	trap 'rm -rf "$TASH_TMP_STDOUR" "$TASH_TMP_STDERR"' EXIT # Make sure they get cleaned up
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
	elapsed=$((TASH_END - TASH_START))
	tash__results "${TASH_COUNT_SUCCEEDED} succeeded, ${TASH_COUNT_FAILED} failed, ${TASH_COUNT_IGNORED} ignored (took ${elapsed}s)"

	if [ "$TASH_MODE" = "inspect" ]; then
		for path in $TASH_ITEM_PATHS; do
			if tash__scope_is_descendant_of "$path" "$TASH_INSPECTING_TEST"; then
				case " $TASH_VALUE_PATHS " in
				*" $path "*)
					value=$(tash__get $path)
					tash__window "inspection: $path" "${value:-(empty)}"
					;;
				esac
			fi
		done

	else
		for path in $TASH_FAILED_TESTS; do
			failpath=$(tash__get "${path}::__failpath")
			run_scope=${failpath%::*}
			stdout=$(tash__get "${run_scope}::stdout")
			stderr=$(tash__get "${run_scope}::stderr")
			if [ -n "$stdout" ] || [ -n "$stderr" ]; then
				tash__window "$failpath" \
					"$(printf "stdout: %s" "${stdout:-(empty)}")" \
					"$(printf "stderr: %s" "${stderr:-(empty)}")"
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
