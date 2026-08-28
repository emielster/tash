#!/bin/sh

. ./tash.sh

item "a"
value 5
end
tash_run "$@"
