#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/../src/tash.sh"

tash_init "$@"

# WARNING: Because Tash uses item blocks, you can indent them
# with tabs and that makes the code more readable. But this is
# unusual shell syntax! Your formatter might reformat the whole thing 
# to be flat on save! Please figure out how to disable it,
# because there are a lot of formatters out there.
#
# For my fellow LazyVim users (like me):
# :lua vim.b.autoformat = false


# prettier-ignore
# shfmt:off
item "internal"
	item "tash__is_valid_name"	
		item "valid_name"
			run tash__is_valid_name "valid_name"
			assert -z stdout
			assert -z stderr
			assert exitcode -eq 0
		end
		item "invalid_name"
			run tash__is_valid_name "invalid-name"
			assert -z stdout
			assert -z stderr
			assert exitcode -eq 1
		end
	end
	item "tash__mk_temp"
		run tash__mk_temp
		file=$(tash_print stdout)
		if ! [ -f "$file" ]; then fail "expected tash__mk_temp to create the file"; fi
		assert -z stderr 
		assert -n stdout
		assert exitcode -eq 0
	end
	item "tash__scope_is_descendant_of"
		item "is_descendant"
			run tash__scope_is_descendant_of "$TASH_SCOPE" "tests::internal::tash__scope_is_descendant_of"
			assert -z stdout
			assert -z stderr
			assert exitcode -eq 0
		end

		item "is_not_descendant"
			run tash__scope_is_descendant_of "$TASH_SCOPE" "tests::internal::tash__mk_temp"
			assert -z stdout
			assert -z stderr
			assert exitcode -eq 1
		end
	end
	item "tash__should_log"
		item "should_log"
			run tash__should_log
			assert -z stdout
			assert -z stderr
			assert exitcode -eq 0 # Kind of a redundancy here:
								  # inspecting this will make tash__should_log
#								  # return 0, and without inspecting this should 
#								  # also return 0. if inspecting something else,
#								  # this is never ran and thus this will be ok.
		end
	end
	item "tash__failure_message"
		item "zero"
			run tash__failure_message "stdout" "-z" "not_important_here" "something_else"
			assert stdout = "expected stdout to be empty, but it was \"something_else\""
			assert -z stderr
			assert exitcode -eq 0
		end
		item "non_zero"
			run tash__failure_message "stdout" "-n"
			assert stdout = "expected stdout to be non-empty, but it was empty"
			assert -z stderr
			assert exitcode -eq 0
		end
		item "string_equality"
			run tash__failure_message "stdout" "=" "expected" "actual"
			assert stdout = "expected stdout = \"expected\", but stdout is \"actual\""
			assert -z stderr
			assert exitcode -eq 0
		end
		item "string_inequality"
			run tash__failure_message "stdout" "!=" "expected" "expected"
			assert stdout = "expected stdout != \"expected\", but stdout is \"expected\""
			assert -z stderr
			assert exitcode -eq 0
		end
		item "contains"
			run tash__failure_message "stdout" "contains" "hello" "bye"
			assert stdout = "expected stdout contains \"hello\", but stdout is \"bye\""
			assert -z stderr
			assert exitcode -eq 0
		end
		item "eq"
			run tash__failure_message "exitcode" "-eq" "1" "0"
			assert stdout = "expected exitcode == 1, but exitcode is 0"	
			assert -z stderr
			assert exitcode -eq 0
		end
		item "ne"		
			run tash__failure_message "exitcode" "-ne" "1" "1"
			assert stdout = "expected exitcode != 1, but exitcode is 1"	
			assert -z stderr
			assert exitcode -eq 0
		end
		item "gt" 
			run tash__failure_message "exitcode" "-gt" "1" "0"
			assert stdout = "expected exitcode > 1, but exitcode is 0"	
			assert -z stderr
			assert exitcode -eq 0
		end
		item "lt"	
			run tash__failure_message "exitcode" "-lt" "1" "2"
			assert stdout = "expected exitcode < 1, but exitcode is 2"	
			assert -z stderr
			assert exitcode -eq 0
		end
		item "ge"
			run tash__failure_message "exitcode" "-ge" "1" "0"
			assert stdout = "expected exitcode >= 1, but exitcode is 0"	
			assert -z stderr
			assert exitcode -eq 0
		end
		item "le"
			run tash__failure_message "exitcode" "-le" "1" "2"
			assert stdout = "expected exitcode <= 1, but exitcode is 2"	
			assert -z stderr
			assert exitcode -eq 0
		end
		item "default"	
			run tash__failure_message "exitcode" "unknown" "1" "2"
			assert stdout = "expected exitcode unknown 1, but exitcode is 2"	
			assert -z stderr
			assert exitcode -eq 0
		end
	end
	item "tash__op_to_words"
		item "eq"
			run tash__op_to_words "-eq"
			assert stdout = "=="
			assert -z stderr
			assert exitcode -eq 0
		end
		item "ne"
			run tash__op_to_words "-ne"
			assert stdout = "!="
			assert -z stderr
			assert exitcode -eq 0
		end
		item "gt"
			run tash__op_to_words "-gt"
			assert stdout = ">"
			assert -z stderr
			assert exitcode -eq 0
		end
		item "lt"
			run tash__op_to_words "-lt"
			assert stdout = "<"
			assert -z stderr
			assert exitcode -eq 0
		end
		item "ge"
			run tash__op_to_words "-ge"
			assert stdout = ">="
			assert -z stderr
			assert exitcode -eq 0
		end
		item "le"
			run tash__op_to_words "-le"
			assert stdout = "<="
			assert -z stderr
			assert exitcode -eq 0
		end
	end
	item "tash__preview_is_last" 
		item "is_not_last"
			TEMP_TASH_ITEM_PATHS=$TASH_ITEM_PATHS # make --preview still work, otherwise it would overwrite it 
			TASH_ITEM_PATHS="tests::internal::tash__preview_is_last::is_not_last tests::internal::tash__preview_is_last::is_last"
			run tash__preview_is_last "tests::internal::tash__preview_is_last::is_not_last"
			assert -z stdout
			assert -z stderr
			assert exitcode -eq 1
			TASH_ITEM_PATHS=$TEMP_TASH_ITEM_PATHS
		end
		item "is_last"
			TEMP_TASH_ITEM_PATHS=$TASH_ITEM_PATHS
			TASH_ITEM_PATHS="tests::internal::tash__preview_is_last::is_not_last tests::internal::tash__preview_is_last::is_last"
			run tash__preview_is_last "tests::internal::tash__preview_is_last::is_last"
			assert -z stdout
			assert -z stderr
			assert exitcode -eq 0
			TASH_ITEM_PATHS=$TEMP_TASH_ITEM_PATHS
		end
	end
	item "tash__preview_tree"
		run tash__preview_tree
		# do a few checks, otherwise the check would be fragile
		assert stdout contains "tash__preview_tree"
		assert stdout contains "tests"
		assert stdout contains "|"
		assert stdout contains "+"
		assert stdout contains "-"
		assert -z stderr
		assert exitcode -eq 0
	end
	item "tash__window"
		run tash__window "test" "line"
		assert stdout contains "test"
		assert stdout contains "line"
		assert stdout contains "+"
		assert stdout contains "-"
		assert stdout contains "|"
		assert -z stderr
		assert exitcode -eq 0
	end
	item "tash__var_name"
		# We have no reliable way of checking here, because
		# run itself uses tash__var_name before we can check. This is one of 
		# those 1/1_000_000 cases where this happens. We'll use manual testing instead
		tash__var_name "tests::hello::something"
		if ! [ "$tash__vn" = "TASH_VAR_tests__hello__something" ]; then
			fail "expected tash__vn = \"TASH_VAR_tests__hello__something\", but tash__vn is $tash__vn";
		fi
		# We have no reliable way of checking stdout, stderr, and exitcode... 
		# so we use a quick workaround
		item make_me_a_test
			value 0
		end
		assert make_me_a_test -eq 0
	end

	item "tash__set"
		tash__set "tests::misc::something" "5"
		if ! [ "$TASH_VAR_tests__misc__something" = "5" ]; then
			fail "expected TASH_VAR_tests__misc__something = \"5\", but TASH_VAR_tests__misc__something is $TASH_VAR_tests__misc__something";
		fi		
		item make_me_a_test
			value 0
		end
		assert make_me_a_test -eq 0
	end

	item "tash__get"
		# We'll test from the value set with tash__set
		tash__get "tests::misc::something" 
		if ! [ "$tash__gv" = "5" ]; then
			fail "expected tash_gv = \"5\", but tash_gv is \"$tash_gv\""
		fi
		item make_me_a_test
			value 0
		end
		assert make_me_a_test -eq 0
	end
	
	item "tash__log"
		item "test_stdout"
			run tash__log "test" "$TASH_BOLD_GREEN" "tash is cool!" 
			assert stdout contains "tash is cool"
			assert stdout contains "test"
			assert -z stderr
			assert exitcode -eq 0
		end
		item "test_stderr"
			run tash__log "test" "$TASH_BOLD_GREEN" "tash is cool!" 1
			assert -z stdout
			assert stderr contains "tash is cool!"
			assert stderr contains "test"
			assert exitcode -eq 0	
		end
	end

	item "tash__success"
		run tash__success "this is a test!"	
		assert stdout contains "this is a test!"
		assert stdout contains "ok"
		assert -z stderr 
		assert exitcode -eq 0
	end


	item "tash__error"
		run tash__error "this is a test!"
		assert stderr contains "this is a test!"
		assert stderr contains "err"
		assert -z stdout
		assert exitcode -eq 0
	end

	item "tash__results"	
		run tash__results "this is a test!"	
		assert stdout contains "this is a test!"
		assert stdout contains "results"
		assert -z stderr 
		assert exitcode -eq 0
	end

	item "tash__hint"	
		run tash__hint "this is a test!"	
		assert stdout contains "this is a test!"
		assert stdout contains "hint"
		assert -z stderr 
		assert exitcode -eq 0
	end

	item "tash__failure"	
		run tash__failure "this is a test!"
		assert stderr contains "this is a test!"
		assert stderr contains "failure"
		assert -z stdout
		assert exitcode -eq 0
	end

	item "tash__terminate"
		# Need to run it in a real subshell like this,
		# otherwise Tash terminates.
		run sh -c '. "'"$SCRIPT_DIR"'/../src/tash.sh"; tash__terminate ${TASH_E_ASSERT_ARGUMENT_COUNT}'
		assert stderr contains "terminated"
		assert stderr contains "E009"
		assert -z stdout
		# Finally, we can assert the exitcode with something
		# else than 0.
		assert exitcode -eq 9
	end
end

if [ $TASH_COUNT_FAILED -eq 0 ]; then
    printf "tash ${TASH_BOLD_GREEN}finished${TASH_COLOR_RESET} internal checks without any errors!\n"
fi


item "external"
    item "item" 
        item "argument_count"      
		    run sh -c '. "'"$SCRIPT_DIR"'/../src/tash.sh"; item'
            assert stderr contains "terminated"
            assert stderr contains "E001"
            assert stderr contains "expected exactly one argument"
            assert -z stdout
            assert exitcode -eq 1
        end
        item "invalid_name"
		    run sh -c '. "'"$SCRIPT_DIR"'/../src/tash.sh"; item "invalid-name::"'
            assert stderr contains "terminated"
            assert stderr contains "E002"
            assert stderr contains "name must match"
            assert stdout contains "don't use spaces, colons or slashes"
            assert exitcode -eq 2 
        end
        item "test"
            case " $TASH_ITEM_PATHS " in
            *" $TASH_SCOPE "*) ;;
            *) fail "expected item to add $TASH_SCOPE to TASH_ITEM_PATHS" ;;
            esac
            item make_me_a_test
                value 0
            end
            assert make_me_a_test -eq 0 
        end 

        item "make_me_a_test"
            value 0
        end
        assert make_me_a_test -eq 0
    end
    item "end"
        item "argument_count" 
		    run sh -c '. "'"$SCRIPT_DIR"'/../src/tash.sh"; end test'
            assert stderr contains "terminated"
            assert stderr contains "E003"
            assert stderr contains "expected zero arguments"
            assert -z stdout
            assert exitcode -eq 3 
        end
        item "invalid_scope"
            run sh -c '. "'"$SCRIPT_DIR"'/../src/tash.sh"; end'
            assert stderr contains "terminated"
            assert stderr contains "E004"
            assert stderr contains "cannot exit out of the global scope"
            assert -z stdout
            assert exitcode -eq 4
        end
        # Same here again, we can't really test 
        # end, so we catch it in a subshell
        temp=$(tash__mk_temp) # Safe to use here, because it is already testsed
        TEMP_TASH_SCOPE=$TASH_SCOPE
        ERR=""
        {
            TEMP_TASH_COUNT_SUCCEEDED=$TASH_COUNT_SUCCEEDED
            item "log_success" 
                item "make_me_a_test"
                     value 0
                end
                assert make_me_a_test -eq 0 
            end 
            if [ $((TEMP_TASH_COUNT_SUCCEEDED + 1)) -ne $TASH_COUNT_SUCCEEDED ]; then
                ERR="expected end to increase TASH_COUNT_SUCCEEDED by one" 
            else 
                TASH_COUNT_SUCCEEDED=$((TASH_COUNT_SUCCEEDED-1))
            fi 
            
        } > "$temp"
        
        contents=$(cat "$temp")
        rm -f "$temp"
        case "$contents" in
        *"log_success succeeded"*) ;;
        *) fail "expected end to print a success message, but got: $contents" ;;
        esac

        if [ "$TEMP_TASH_SCOPE" != "$TASH_SCOPE" ]; then
            fail "expected end to end $TASH_SCOPE 'log_success' scope"
        fi

        if [ -n "$ERR" ]; then
            fail "$ERR"
        fi
        temp=$(tash__mk_temp)
        TEMP_TASH_SCOPE=$TASH_SCOPE
        ERR=""
        {
            TEMP_TASH_COUNT_FAILED=$TASH_COUNT_FAILED
            item "log_failure"
                item "make_me_a_test"
                    value 0
                end
                assert make_me_a_test -eq 1
            end
            if [ $((TEMP_TASH_COUNT_FAILED + 1)) -ne $TASH_COUNT_FAILED  ]; then
                ERR="expected end to increase TASH_COUNT_FAILED by one"
            else 
                TASH_COUNT_FAILED=$((TASH_COUNT_FAILED-1))
            fi 
            
            case "$TASH_FAILED_TESTS" in
            *"${TASH_SCOPE}::log_failure"*) ;;
            *) ERR="expected end to add log_failure to TASH_FAILED_TESTS, but TASH_FAILED_TESTS is $TASH_FAILED_TESTS" ;; 
            esac
            
            
        } 2> "$temp"

        contents=$(cat "$temp") 
        rm -f "$temp"
        case "$contents" in
        *"expected make_me_a_test == 1, but make_me_a_test is 0"*) ;;
        *) fail "expected end to print a failure message, but got: $contents" ;;
        esac

        if [ -n "$ERR" ]; then
            fail "$ERR"
        fi

        if [ "$TEMP_TASH_SCOPE" != "$TASH_SCOPE" ]; then
            fail "expected end to end $TASH_SCOPE 'log_failure' scope"
        fi
        
        temp=$(tash__mk_temp)
        TEMP_TASH_MODE=$TASH_MODE
        TEMP_TASH_SCOPE=$TASH_SCOPE
        ERR=""
        {
            TEMP_TASH_COUNT_IGNORED="$TASH_COUNT_IGNORED"  
            TASH_MODE="inspect"
            item "should_not_log_inspect" 
                item "make_me_a_test"
                    value 0
                end
                assert make_me_a_test -eq 0
            end

            if [ $((TEMP_TASH_COUNT_IGNORED + 1)) -ne $TASH_COUNT_IGNORED ]; then
                ERR="expected end to increase TASH_COUNT_IGNORED by one"
            else 
                TASH_COUNT_IGNORED=$((TASH_COUNT_IGNORED-1))
            fi

            
        } >"$temp"
        TASH_MODE=$TEMP_TASH_MODE

        contents=$(cat "$temp") 
        rm -f "$temp"
        
        if [ -n "$ERR" ]; then
            fail "$ERR"
        fi
        
        if [ "$TEMP_TASH_SCOPE" != "$TASH_SCOPE" ]; then
            fail "expected end to end $TASH_SCOPE 'should_not_log_inspect' scope"
        fi

    end
    item "value" 
        item "argument_count"  
		    run sh -c '. "'"$SCRIPT_DIR"'/../src/tash.sh"; value'
            assert stderr contains "terminated"
            assert stderr contains "E005"
            assert stderr contains "expected exactly one argument"
            assert -z stdout
            assert exitcode -eq 5
        end
        item "test"
            value 0
        end
        case "$TASH_ITEM_PATHS" in
        *"$TASH_SCOPE::test"*) ;;
        *) fail "expected value to add $TASH_SCOPE::test to TASH_ITEM_PATHS, but TASH_ITEM_PATHS is $TASH_ITEM_PATHS" ;;
        esac
        
        tash__get "$TASH_SCOPE::test"
        if [ "$tash__gv" -ne 0 ]; then
            fail "expected value to make $TASH_SCOPE::test 0, but $TASH_SCOPE::test is $tash__gv"
        fi
        
        assert test -eq 0
    end
    item "run"
        item "argument_count" 
		    run sh -c '. "'"$SCRIPT_DIR"'/../src/tash.sh"; run'
            assert stderr contains "terminated"
            assert stderr contains "E006"
            assert stderr contains "expected atleast one argument (command...)"
            assert -z stdout
            assert exitcode -eq 6
        end
        # We cannot do run run echo "something" here, because run itself
        # sets exitcode and co, so it just overwrites it
        item "preview"
            TEMP_TASH_MODE=$TASH_MODE
            TASH_MODE="preview"
            run echo "something"
            assert -z stdout
            assert -z stderr
            assert -z exitcode
            TASH_MODE=$TEMP_TASH_MODE
        end
        item "inspect_runs"
            TEMP_TASH_MODE=$TASH_MODE
            TEMP_TASH_INSPECTING_TEST=$TASH_INSPECTING_TEST
            TASH_INSPECTING_TEST="$TASH_SCOPE"
            TASH_MODE="inspect"
            run echo "something"
            TASH_MODE=$TEMP_TASH_MODE
            TASH_INSPECTING_TEST=$TEMP_TASH_INSPECTING_TEST
            assert stdout = "something"
            assert -z stderr
            assert exitcode -eq 0
        end
        item "inspect_skips"
            TEMP_TASH_MODE=$TASH_MODE
            TEMP_TASH_INSPECTING_TEST=$TASH_INSPECTING_TEST
            TASH_MODE="inspect"
            TASH_INSPECTING_TEST="tests::some_other_test"
            tmpfile=$(tash__mk_temp) # when skipping over, assert itself also skips over so we cannot
                                     # rely on that
            rm -f "$tmpfile"
            run touch "$tmpfile"
            TASH_MODE=$TEMP_TASH_MODE
            TASH_INSPECTING_TEST=$TEMP_TASH_INSPECTING_TEST
            if [ -f "$tmpfile" ]; then
                fail "expected run to skip execution when scope doesn't match TASH_INSPECTING_TEST"
            fi
            item "make_me_a_test"
                value 0
            end
            assert make_me_a_test -eq 0
        end
        run echo "something"
        assert stdout = "something" 
        assert -z stderr
        assert exitcode -eq 0
    end

    item "fail"

    end
end


tash_end
