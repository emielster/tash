#!/bin/sh

. ./tash.sh
tash_init "$@"

item "a::"
run echo "hello"
assert_eq stdout "hello"
end

assert_eq a::stdout "hello"
# echo $TASH_VAR_tests__a should work here!

tash_end
