#!/bin/sh

. ./tash.sh
tash_init "$@"

item "printf"
run printf "hello world"
assert stdout = "hello world"
assert -z stderr
assert exitcode -eq 0
end

item "true"
run true
assert -z stdout
assert -z stderr
assert exitcode -eq 0
end

item "false"
run false
assert -z stdout
assert -z stderr
assert exitcode -eq 1
end

item "echo"
run echo "hello world"
assert stdout = "hello world"
assert -z stderr
assert exitcode -eq 0
end

item "cat"
run printf "hello\nworld\n"
assert stdout = "hello\nworld"
assert -z stderr
assert exitcode -eq 0
end

item "grep"
run printf "apple\nbanana\napricot\n"
assert stdout contains "apple"
assert stdout contains "apricot"
assert stdout != "banana"
assert exitcode -eq 0
end

item "grep_no_match"
run sh -c 'printf "apple\nbanana\n" | grep orange'
assert -z stdout
assert exitcode -eq 1
end

item "sort"
run sh -c 'printf "zebra\napple\nbanana\n" | sort'
assert stdout = "apple\nbanana\nzebra"
assert exitcode -eq 0
end

item "wc"
run printf "one\ntwo\nthree\n"
assert stdout contains "one"
assert stdout contains "three"
assert exitcode -eq 0
end

item "mkdir"
run mkdir tash_test_directory
assert -z stdout
assert -z stderr
assert exitcode -eq 0
end

item "test_directory"
run test -d tash_test_directory
assert -z stdout
assert -z stderr
assert exitcode -eq 0
end

item "test_file"
run sh -c 'touch tash_test_file && test -f tash_test_file'
assert -z stdout
assert -z stderr
assert exitcode -eq 0
end

item "missing_file"
run cat definitely_does_not_exist
assert stdout = ""
assert stderr contains "No such file"
assert exitcode -ne 0
end

item "invalid_option"
run ls --definitely-not-an-option
assert stdout = ""
assert stderr contains "option"
assert exitcode -ne 0
end

rm -rf tash_test_directory tash_test_file
if [ "$TASH_COUNT_FAILED" -eq 0 ]; then
	echo "Congrats! You have a fully working Linux system."
fi
tash_end
