#!/bin/bash

# Copyright 2021 Matrix Origin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#===============================================================================
#
#          FILE: run_ut.sh
#   DESCRIPTION: 
#        AUTHOR: Matthew Li, lignay@me.com
#  ORGANIZATION: 
#       CREATED: 09/01/2021
#      REVISION:  ---
#===============================================================================

set -o nounset                                  # Treat unset variables as an error
#set -exuo pipefail

if (( $# == 0 )); then
    echo "Usage: $0 TestType SkipTest"
    echo "  TestType: UT|SCA"
    echo "  SkipTest: race"
    exit 1
fi

TEST_TYPE=$1
if [[ $# == 2 ]]; then 
    SKIP_TESTS=$2; 
else
    SKIP_TESTS="";
fi

source $HOME/.bash_profile
source ./utilities.sh

BUILD_WKSP=$(dirname "$PWD") && cd $BUILD_WKSP

UT_TIMEOUT=15
LOG="$G_TS-$TEST_TYPE.log"
SCA_REPORT="$G_WKSP/$G_TS-SCA-Report.out"
UT_REPORT="$G_WKSP/$G_TS-UT-Report.out"
UT_FILTER="$G_WKSP/$G_TS-UT-Filter.out"
UT_COUNT="$G_WKSP/$G_TS-UT-Count.out"
CODE_COVERAGE="$G_WKSP/$G_TS-UT-Coverage.html"
RAW_COVERAGE="coverage.out"

if [[ -f $SCA_REPORT ]]; then rm $SCA_REPORT; fi
if [[ -f $UT_REPORT ]]; then rm $UT_REPORT; fi
if [[ -f $UT_FILTER ]]; then rm $UT_FILTER; fi
if [[ -f $UT_COUNT ]]; then rm $UT_COUNT; fi


function logger(){
    local level=$1
    local msg=$2
    local log=$LOG
    logger_base "$level" "$msg" "$log"
}

function run_vet(){
    cd $BUILD_WKSP
    horiz_rule
    echo "#  BUILD WORKSPACE: $BUILD_WKSP"
    echo "#  SCA REPORT:      $SCA_REPORT"
    horiz_rule

    if [[ -f $SCA_REPORT ]]; then rm $SCA_REPORT; fi
    logger "INF" "Test is in progress... "
    go vet -unsafeptr=false ./pkg/... 2>&1 | tee $SCA_REPORT
    logger "INF" "Refer to $SCA_REPORT for details"

}

function run_tests(){
    cd $BUILD_WKSP
    horiz_rule
    echo "#  BUILD WORKSPACE: $BUILD_WKSP"
    echo "#  SKIPPED TEST:    $SKIP_TESTS"
    echo "#  UT REPORT:       $UT_REPORT"
    echo "#  COVERAGE REPORT: $CODE_COVERAGE"
    echo "#  UT TIMEOUT:      $UT_TIMEOUT"
    horiz_rule

    logger "INF" "Clean go test cache"
    go clean -testcache
    
    local test_scope=$(go list ./... | egrep -v "frontend")
    if [[ $SKIP_TESTS == 'race' ]]; then
        logger "INF" "Run UT without race check"
        go test -v -p 1 -timeout "${UT_TIMEOUT}m" -covermode=count -coverprofile=$RAW_COVERAGE $test_scope | tee $UT_REPORT
        local html_coverage="coverage.html"
        logger "INF" "Check on code coverage"
        go tool cover -o $CODE_COVERAGE -html=$RAW_COVERAGE
        cp -f $CODE_COVERAGE $html_coverage
    else
        logger "INF" "Run UT with race check"
        go test -v -p 1 -timeout "${UT_TIMEOUT}m" -race $test_scope | tee $UT_REPORT
    fi
    egrep -a '^=== RUN *Test[^\/]*$|^\-\-\- PASS: *Test|^\-\-\- FAIL: *Test'  $UT_REPORT > $UT_FILTER
    logger "INF" "Refer to $UT_REPORT for details"

}

function ut_summary(){
    cd $BUILD_WKSP
    local total=$(cat "$UT_FILTER" | egrep '^=== RUN *Test' | wc -l | xargs)
    local pass=$(cat "$UT_FILTER" | egrep "^\-\-\- PASS: *Test" | wc -l | xargs)
    local fail=$(cat "$UT_FILTER" | egrep "^\-\-\- FAIL: *Test" | wc -l | xargs)
    local unknown=$(cat "$UT_FILTER" | sed '/^=== RUN/{x;p;x;}' | sed -n '/=== RUN/N;/--- /!p' | grep -v '^$' | wc -l | xargs)
    cat << EOF > $UT_COUNT
# Total: $total; Passed: $pass; Failed: $fail; Unknown: $unknown
# 
# FAILED CASES:
# $(cat "$UT_FILTER" | egrep "^\-\-\- FAIL: *Test" | xargs)
# 
# UNKNOWN CASES:
# $(cat "$UT_FILTER" | sed '/^=== RUN/{x;p;x;}' | sed -n '/=== RUN/N;/--- /!p' | grep -v '^$' | xargs)
#
#
# Code Coverage
$(go tool cover -func=$RAW_COVERAGE)
#
EOF
    horiz_rule
    cat $UT_COUNT
    horiz_rule
    if (( $fail > 0 )) || (( $unknown > 0 )); then
      logger "INF" "UNIT TESTING FAILED !!!"
      exit 1
    else
      logger "INF" "UNIT TESTING SUCCEEDED !!!"
    fi
}

function post_test(){
    local aoe_test=$(find  pkg/vm/engine/aoe/test/* -type d -maxdepth 0)
    for dir in ${aoe_test[@]}; do
        logger "WRN" "Remove $dir"
        rm -rf $dir
    done
}

if [[ 'SCA' == $TEST_TYPE ]]; then
    horiz_rule
    echo "# Examining source code"
    horiz_rule
    run_vet
elif [[ 'UT' == $TEST_TYPE ]]; then
    horiz_rule
    echo "# Running UT"
    horiz_rule
    run_tests

    horiz_rule
    echo "# Post testing"
    horiz_rule
    post_test

    ut_summary
else
    logger "ERR" "Wrong test type"
    exit 1
fi
    
exit 0