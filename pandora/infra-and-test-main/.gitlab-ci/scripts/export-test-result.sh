#!/bin/bash
# Exports unit test results (JSON/XML) to TestRail
# Dependencies: curl, jq, python3 (optional for XML parsing)

set -o pipefail

# Directory of the script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Source logger if available
if [[ -f "${DIR}/logger.sh" ]]; then
    source "${DIR}/logger.sh"
else
    # Simple fallback logging if logger.sh is missing
    function log_info() { echo "[INFO] $1"; }
    function log_warn() { echo "[WARN] $1"; }
    function log_error() { echo "[ERROR] $1"; }
    function log_debug() { [[ "${VERBOSE}" == "1" ]] && echo "[DEBUG] $1"; }
fi

# Constants & Defaults
RUN_DESC_DEFAULT="Automated test execution"
TESTRAIL_URL_DEFAULT="https://esabgrnd.testrail.com"
TESTRAIL_USERNAME_DEFAULT="team-godzilla@esab.onmicrosoft.com"
TESTRAIL_PROJECT_ID_DEFAULT=34
TESTRAIL_SUITE_ID_DEFAULT=3767
TESTRAIL_SECTION_NAME_DEFAULT="Unit Tests"
TESTRAIL_MILESTONE_ID_DEFAULT=265

RUN_NAME_TEMPLATE_DEFAULT="Automated {TESTRAIL_SECTION_NAME} run - {timestamp} - {CI_COMMIT_REF_NAME}"
RUN_DESC_TEMPLATE_DEFAULT="Automated {TESTRAIL_SECTION_NAME} test execution"
RUN_DESC_DEFAULT="Automated test execution"

# TestRail Status IDs
STATUS_PASSED=1
STATUS_BLOCKED=2
STATUS_UNTESTED=3
STATUS_FAILED=5
STATUS_SKIPPED=6

# Helper Functions

function check_dependencies() {
    local missing=0
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Dependency '$cmd' not found. Please install it."
            missing=1
        fi
    done
    if [[ $missing -eq 1 ]]; then
        exit 1
    fi
}

function usage() {
    echo "Usage: $0 --report <path> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --report <path>   Path to test report file (XML or JSON) [REQUIRED]"
    echo "  -v, --verbose     Enable verbose logging"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Required: TESTZILLA_TESTRAIL_API_KEY environment variable"
    echo "Optional: TESTRAIL_URL, TESTRAIL_USERNAME, TESTRAIL_PROJECT_ID, etc."
    echo ""
    echo "Example: $0 --report test-results.xml"
    exit 1
}

function convert_xml_to_json_python() {
    local xml_file="$1"
    python3 -c '
import sys
import json
import xml.etree.ElementTree as ET

def parse_xml_report(report_path):
    try:
        tree = ET.parse(report_path)
        root = tree.getroot()
    except ET.ParseError:
        with open(report_path, "r", encoding="utf-8") as f:
            text = f.read()
        import re
        def _repl(match):
            attr, val = match.groups()
            if "<" in val or ">" in val:
                val = val.replace("<", "&lt;").replace(">", "&gt;")
            return f"{attr}=\"{val}\""
        sanitized = re.sub(r"(\w+)=\"([^\"]*)\"", _repl, text)
        root = ET.fromstring(sanitized)

    tests = []
    total_duration = 0.0
    passed = failed = skipped = errors = 0

    testsuites = root.findall(".//testsuite")
    if not testsuites:
        testsuites = [root] if root.tag == "testsuite" else []

    for suite in testsuites:
        suite_name = suite.get("name", "unknown")
        for case in suite.findall("testcase"):
            classname = case.get("classname", "")
            test_name = case.get("name", "unknown_test")
            duration = float(case.get("time", 0))

            status = "passed"
            msg = "Test passed"
            trace = ""

            # Check children
            failure = case.find("failure")
            error = case.find("error")
            skipped_node = case.find("skipped")

            if failure is not None:
                status = "failed"
                msg = failure.get("message", "Test failed")
                trace = failure.text or ""
                failed += 1
            elif error is not None:
                status = "failed"
                msg = error.get("message", "Test error")
                trace = error.text or ""
                errors += 1
            elif skipped_node is not None:
                status = "skipped"
                msg = skipped_node.get("message", "Test skipped")
                skipped += 1
            else:
                passed += 1

            total_duration += duration

            module = classname
            if "/" in classname:
                module = classname.split("/")[-1]
            module = module.replace("/build/", "").replace("/source/", "")

            desc = f"Test from {suite_name}"
            if classname and classname != suite_name:
                desc += f"\\nClass: {classname}"

            tests.append({
                "name": test_name,
                "status": status,
                "duration": duration,
                "message": msg,
                "traceback": trace,
                "description": desc,
                "module": module
            })

    summary = {
        "total": len(tests),
        "passed": passed,
        "failed": failed + errors,
        "skipped": skipped,
        "duration": total_duration
    }
    print(json.dumps({"tests": tests, "summary": summary}))

parse_xml_report(sys.argv[1])
' "$xml_file"
}

function convert_xml_to_json_awk() {
    local xml_file="$1"
    sed 's/>/>\n/g' "$xml_file" \
    | sed 's/</\n</g' | grep -v '^\s*$' \
    | awk '
    BEGIN {
        in_test = 0
        current_suite = "unknown"
        total=0; passed=0; failed=0; skipped=0; duration=0
    }

    /<testsuite / {
        # match name="..."
        if (match($0, /name="([^"]*)"/, m)) {
           current_suite = substr($0, m[1, "start"], m[1, "length"])
        } else if (match($0, /name='\''([^'\'']*)'\''/, m)) {
           current_suite = substr($0, m[1, "start"], m[1, "length"])
        }
    }

    /<testcase / {
        in_test = 1
        name="unknown"; classname=""; time="0"; status="passed"; msg="";

        if (match($0, /name="([^"]*)"/, m)) name = substr($0, m[1, "start"], m[1, "length"])
        if (match($0, /classname="([^"]*)"/, m)) classname = substr($0, m[1, "start"], m[1, "length"])
        if (match($0, /time="([^"]*)"/, m)) time = substr($0, m[1, "start"], m[1, "length"])

        if ($0 ~ /\/>/) {
            print_json()
            in_test = 0
        }
    }

    /<\/testcase>/ {
        if (in_test) {
            print_json()
            in_test = 0
        }
    }

    /<failure/ || /<error/ {
        if (in_test) {
            status = "failed"
            if (match($0, /message="([^"]*)"/, m)) msg = substr($0, m[1, "start"], m[1, "length"])
        }
    }

    /<skipped/ {
        if (in_test) {
            status = "skipped"
            if (match($0, /message="([^"]*)"/, m)) msg = substr($0, m[1, "start"], m[1, "length"])
        }
    }

    function print_json() {
        total++
        duration += time + 0
        if (status == "passed") passed++
        else if (status == "skipped") skipped++
        else failed++

        gsub(/"/, "\\\"", name)
        gsub(/"/, "\\\"", msg)
        gsub(/"/, "\\\"", classname)

        printf "{\"name\": \"%s\", \"status\": \"%s\", \"duration\": %s, \"message\": \"%s\", \"classname\": \"%s\", \"suite\": \"%s\"}\n", name, status, time, msg, classname, current_suite
    }
    ' | jq -s '
    {
        tests: .,
        summary: {
            total: length,
            passed: ([.[] | select(.status=="passed")] | length),
            failed: ([.[] | select(.status=="failed")] | length),
            skipped: ([.[] | select(.status=="skipped")] | length),
            duration: ([.[].duration] | add)
        }
    }'
}

function convert_xml_to_json() {
    local xml_file="$1"
    if command -v python3 &> /dev/null; then
        log_debug "Using Python3 for XML parsing"
        convert_xml_to_json_python "$xml_file"
    else
        log_warn "Python3 not found. Using fallback Awk XML parser (Basic support)."
        convert_xml_to_json_awk "$xml_file"
    fi
}

function api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local url="${TESTRAIL_URL}/index.php?/api/v2/${endpoint}"
    local curl_cmd=(curl -s -H "Content-Type: application/json" -u "${TESTRAIL_USERNAME}:${TESTRAIL_API_KEY}")

    if [[ "$method" != "GET" ]]; then
        curl_cmd+=(-X "$method")
    fi

    if [[ -n "$data" ]]; then
        curl_cmd+=(-d "$data")
    fi

    log_debug "API ${method} ${endpoint}"

    local response
    response=$("${curl_cmd[@]}" "$url")

    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local err_msg
        err_msg=$(echo "$response" | jq -r '.error')
        log_error "API Error: $err_msg"
        return 1
    fi

    echo "$response"
}

function map_status_to_id() {
    local status
    status=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$status" in
        passed|pass|success) echo $STATUS_PASSED ;;
        failed|fail|error)   echo $STATUS_FAILED ;;
        skipped|skip)        echo $STATUS_SKIPPED ;;
        blocked)             echo $STATUS_BLOCKED ;;
        untested)            echo $STATUS_UNTESTED ;;
        *)                   echo $STATUS_UNTESTED ;;
    esac
}

# Logic Functions

function load_configuration() {
    TESTRAIL_URL="${TESTRAIL_URL:-$TESTRAIL_URL_DEFAULT}"
    TESTRAIL_USERNAME="${TESTRAIL_USERNAME:-$TESTRAIL_USERNAME_DEFAULT}"
    TESTRAIL_API_KEY="${TESTZILLA_TESTRAIL_API_KEY:-$TESTRAIL_API_KEY}"
    TESTRAIL_PROJECT_ID="${TESTRAIL_PROJECT_ID:-$TESTRAIL_PROJECT_ID_DEFAULT}"
    TESTRAIL_SUITE_ID="${TESTRAIL_SUITE_ID:-$TESTRAIL_SUITE_ID_DEFAULT}"
    TESTRAIL_SECTION_NAME="${TESTRAIL_SECTION_NAME:-$TESTRAIL_SECTION_NAME_DEFAULT}"
    TESTRAIL_MILESTONE_ID="${TESTRAIL_MILESTONE_ID:-$TESTRAIL_MILESTONE_ID_DEFAULT}"
    RUN_NAME_TEMPLATE="${RUN_NAME_TEMPLATE:-$RUN_NAME_TEMPLATE_DEFAULT}"
    RUN_DESC_TEMPLATE="${RUN_DESC_TEMPLATE:-$RUN_DESC_TEMPLATE_DEFAULT}"
    RUN_DESC="${RUN_DESC:-$RUN_DESC_DEFAULT}"
}

function get_or_create_section() {
    local project_id="$1"
    local suite_id="$2"
    local section_name="$3"

    log_info "Looking for section: $section_name"
    local response
    response=$(api_request "GET" "get_sections/${project_id}&suite_id=${suite_id}")

    local section_id
    section_id=$(echo "$response" | jq -r --arg name "$section_name" '.sections[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id' | head -n 1)

    if [[ -n "$section_id" && "$section_id" != "null" ]]; then
        log_info "Found existing section ID: $section_id"
        echo "$section_id"
        return
    fi

    log_info "Creating new section: $section_name"
    local payload
    payload=$(jq -n \
        --arg name "$section_name" \
        --argjson suite_id "$suite_id" \
        --arg desc "Automated ${section_name} test cases" \
        '{suite_id: $suite_id, name: $name, description: $desc}'
    )

    local create_resp
    create_resp=$(api_request "POST" "add_section/${project_id}" "$payload")
    section_id=$(echo "$create_resp" | jq -r '.id')

    log_info "Created section ID: $section_id"
    echo "$section_id"
}

function fetch_existing_cases() {
    local project_id="$1"
    local suite_id="$2"

    log_info "Fetching existing test cases..."
    local response
    response=$(api_request "GET" "get_cases/${project_id}&suite_id=${suite_id}")

    local cases_json
    cases_json=$(echo "$response" | jq -c 'if .cases then .cases else . end')

    echo "$cases_json"
}

function create_or_update_cases() {
    local tests_file="$1"
    local section_id="$2"
    local existing_cases_file="$3"
    local commit_sha="${4:-unknown}"

    local map_file
    map_file=$(mktemp)
    local dict_file
    dict_file=$(mktemp)

    jq -r '.[] | "\(.title | ascii_downcase)\t\(.id)"' "$existing_cases_file" > "$dict_file"
    local temp_dir
    temp_dir=$(mktemp -d)

    jq -c '.[]' "$tests_file" > "${temp_dir}/tests.jsonl"

    while IFS= read -r test_json; do
        [[ -z "$test_json" ]] && continue

        local name
        name=$(echo "$test_json" | jq -r '.name // "unknown"')
        local description
        description=$(echo "$test_json" | jq -r '.description // empty')
        local module
        module=$(echo "$test_json" | jq -r '.module // empty')

        # Create unique title by prefixing with module name if available
        local unique_title="$name"
        if [[ -n "$module" && "$module" != "$name" ]]; then
            unique_title="${module} - ${name}"
        fi
        local title_lower
        title_lower=$(echo "$unique_title" | tr '[:upper:]' '[:lower:]')

        local custom_preconds=""
        if [[ -n "$description" ]]; then custom_preconds+="${description}"; fi
        if [[ -n "$module" ]]; then custom_preconds+=$'\n'"**Module:** ${module}"; fi

        local case_id
        case_id=$(grep "^$(printf '%s\t' "$title_lower")" "$dict_file" | cut -f2 | head -n1)

        if [[ -n "$case_id" ]]; then
            log_debug "Updating case '${unique_title}' ($case_id)"
            local payload
            payload=$(jq -n \
                --arg ref "$commit_sha" \
                --arg pre "$custom_preconds" \
                --arg rev "$commit_sha" \
                '{type_id: 1, refs: $ref, custom_preconds: $pre, custom_tcrevision: $rev, custom_steps_separated: []}'
            )
            api_request "POST" "update_case/${case_id}" "$payload" >/dev/null
        else
            log_info "Creating case '${unique_title}'"
            local payload
            payload=$(jq -n \
                --arg title "$unique_title" \
                --argjson sec "$section_id" \
                --arg ref "$commit_sha" \
                --arg pre "$custom_preconds" \
                --arg rev "$commit_sha" \
                '{title: $title, section_id: $sec, type_id: 1, refs: $ref, custom_preconds: $pre, custom_tcrevision: $rev, custom_steps_separated: []}'
            )
            local resp
            resp=$(api_request "POST" "add_case/${section_id}" "$payload")
            case_id=$(echo "$resp" | jq -r '.id')
            if [[ -z "$case_id" || "$case_id" == "null" ]]; then
                log_warn "Failed to create case '${unique_title}'. Response: $resp"
            else
                log_debug "Created case '${unique_title}' with ID: $case_id"
                echo "${title_lower}	${case_id}" >> "$dict_file"
            fi
        fi

        if [[ -n "$case_id" && "$case_id" != "null" ]]; then
            log_debug "Adding to map: '${unique_title}'=${case_id}"
            echo "${unique_title}=${case_id}" >> "$map_file"
        else
            log_warn "Skipping map entry for '${unique_title}' - invalid case_id: ${case_id}"
        fi
    done < "${temp_dir}/tests.jsonl"

    cat "$map_file"
    rm "$map_file" "$dict_file"
    rm -rf "$temp_dir"
}

function process_template() {
    local template="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local result="$template"

    result="${result//\{timestamp\}/$timestamp}"

    local tokens
    if command -v grep &> /dev/null; then
         # Extract tokens like {VAR_NAME}
         tokens=$(echo "$result" | grep -oE '\{[a-zA-Z_][a-zA-Z0-9_]*\}' | sort -u)
    else
         # Fallback if grep -oE is somehow missing (unlikely): just do specific known ones?
         # Or loop through common ones?
         # The user asked for generic env support, so we assume grep is present.
         log_warn "grep not found or limited; generic env substitution might fail."
         tokens=""
    fi

    for token in $tokens; do
        local var_name="${token:1:-1}"

        if [[ -n "${!var_name+x}" ]]; then
            local value="${!var_name}"
            result="${result//$token/$value}"
        else
             result="${result//$token/}"
        fi
    done

    result=$(echo "$result" | sed 's/  -/ -/g' | sed 's/ - - / - /g' | sed 's/^ - //g' | sed 's/ - $//g')

    echo "$result"
}

# Main Execution

check_dependencies

REPORT_PATH=""
VERBOSE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --report)
            REPORT_PATH="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

if [[ -z "$REPORT_PATH" ]]; then
    log_warn "Missing report argument."
    usage
fi

if [[ ! -f "$REPORT_PATH" ]]; then
    log_error "Report file not found: $REPORT_PATH"
    exit 1
fi

load_configuration

if [[ -z "$TESTRAIL_API_KEY" ]]; then
    log_error "Missing required TestRail API key. Set TESTZILLA_TESTRAIL_API_KEY environment variable."
    exit 1
fi

# Verify other required config
if [[ -z "$TESTRAIL_URL" || -z "$TESTRAIL_USERNAME" || -z "$TESTRAIL_PROJECT_ID" ]]; then
    log_error "Missing required TestRail configuration. Check environment variables."
    exit 1
fi

log_info "TestRail URL: $TESTRAIL_URL"
log_info "Project ID: $TESTRAIL_PROJECT_ID, Suite ID: $TESTRAIL_SUITE_ID"

section_start "load_report" "Loading Test Report"
TMP_REPORT_JSON=$(mktemp)

if [[ "$REPORT_PATH" == *".xml" ]]; then
    log_info "Parsing XML report..."
    convert_xml_to_json "$REPORT_PATH" > "$TMP_REPORT_JSON"
else
    log_info "Parsing JSON report..."
    cp "$REPORT_PATH" "$TMP_REPORT_JSON"
fi

TEST_COUNT=$(jq '.tests | length' "$TMP_REPORT_JSON")
log_info "Loaded $TEST_COUNT tests."
section_end "load_report"

if [[ "$TEST_COUNT" -eq 0 ]]; then
    log_warn "No tests to export."
    rm "$TMP_REPORT_JSON"
    exit 0
fi

section_start "sync_cases" "Syncing Test Cases"

SECTION_ID=$(get_or_create_section "$TESTRAIL_PROJECT_ID" "$TESTRAIL_SUITE_ID" "$TESTRAIL_SECTION_NAME")

EXISTING_CASES_JSON=$(mktemp)
fetch_existing_cases "$TESTRAIL_PROJECT_ID" "$TESTRAIL_SUITE_ID" > "$EXISTING_CASES_JSON"

TESTS_ARRAY_JSON=$(mktemp)
jq -c '.tests' "$TMP_REPORT_JSON" > "$TESTS_ARRAY_JSON"

CASE_MAP_FILE=$(mktemp)
create_or_update_cases "$TESTS_ARRAY_JSON" "$SECTION_ID" "$EXISTING_CASES_JSON" "${CI_COMMIT_SHA:-unknown}" > "$CASE_MAP_FILE"

rm "$EXISTING_CASES_JSON" "$TESTS_ARRAY_JSON"
section_end "sync_cases"

section_start "create_run" "Creating Test Run"

RUN_NAME=$(process_template "$RUN_NAME_TEMPLATE")
RUN_DESC=$(process_template "$RUN_DESC_TEMPLATE")

if [[ "${CI:-false}" == "true" ]]; then
    RUN_DESC+=$'\n\n'"Test executed in GitLab environment"
    if [[ -n "${CI_JOB_URL}" ]]; then RUN_DESC+=$'\n'"Job URL: ${CI_JOB_URL}"; fi
    if [[ -n "${CI_PIPELINE_URL}" ]]; then RUN_DESC+=$'\n'"Pipeline URL: ${CI_PIPELINE_URL}"; fi
    if [[ -n "${CI_PIPELINE_ID}" ]]; then RUN_DESC+=$'\n'"Pipeline ID: ${CI_PIPELINE_ID}"; fi
    if [[ -n "${CI_JOB_ID}" ]]; then RUN_DESC+=$'\n'"Job ID: ${CI_JOB_ID}"; fi
    if [[ -n "${CI_COMMIT_SHA}" ]]; then RUN_DESC+=$'\n'"Commit SHA: ${CI_COMMIT_SHA}"; fi
    if [[ -n "${CI_COMMIT_REF_NAME}" ]]; then RUN_DESC+=$'\n'"Commit Reference: ${CI_COMMIT_REF_NAME}"; fi
    if [[ -n "${CI_COMMIT_MESSAGE}" ]]; then RUN_DESC+=$'\n'"Commit Message: ${CI_COMMIT_MESSAGE}"; fi
    if [[ -n "${CI_COMMIT_AUTHOR}" ]]; then RUN_DESC+=$'\n'"Commit Author: ${CI_COMMIT_AUTHOR}"; fi
fi

CASE_IDS=$(rev "$CASE_MAP_FILE" | cut -d'=' -f1 | rev | grep -v '^$' | grep -E '^[0-9]+$' | jq -R 'tonumber' | jq -s .)

CASE_COUNT=$(echo "$CASE_IDS" | jq 'length')
if [[ "$CASE_COUNT" -eq 0 ]]; then
    log_error "No valid test cases were created. Cannot create test run."
    rm "$TMP_REPORT_JSON" "$CASE_MAP_FILE"
    exit 1
fi

log_info "Creating test run with $CASE_COUNT test cases"

RUN_PAYLOAD=$(jq -n \
    --argjson suite "$TESTRAIL_SUITE_ID" \
    --arg name "$RUN_NAME" \
    --arg desc "$RUN_DESC" \
    --argjson cases "$CASE_IDS" \
    '{suite_id: $suite, name: $name, description: $desc, case_ids: $cases, include_all: false}'
)

if [[ -n "$TESTRAIL_MILESTONE_ID" && "$TESTRAIL_MILESTONE_ID" != "null" ]]; then
    RUN_PAYLOAD=$(echo "$RUN_PAYLOAD" | jq --argjson m "$TESTRAIL_MILESTONE_ID" '. + {milestone_id: $m}')
fi

RESP_RUN=$(api_request "POST" "add_run/${TESTRAIL_PROJECT_ID}" "$RUN_PAYLOAD")
RUN_ID=$(echo "$RESP_RUN" | jq -r '.id')
RUN_URL=$(echo "$RESP_RUN" | jq -r '.url')

if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
    log_error "Failed to create test run. Response: $RESP_RUN"
    rm "$TMP_REPORT_JSON" "$CASE_MAP_FILE"
    exit 1
fi

log_info "Created Test Run: $RUN_ID"
log_info "URL: $RUN_URL"
section_end "create_run"

section_start "add_results" "Adding Test Results"

TESTS_IN_RUN_RESP=$(api_request "GET" "get_tests/${RUN_ID}")
TEST_ID_MAP=$(mktemp)
echo "$TESTS_IN_RUN_RESP" | jq -r 'if .tests then .tests else . end | .[] | "\(.case_id)=\(.id)"' > "$TEST_ID_MAP"

# Iterate and post results
jq -c '.tests[]' "$TMP_REPORT_JSON" | while read -r test_item; do
    t_name=$(echo "$test_item" | jq -r '.name')
    t_status=$(echo "$test_item" | jq -r '.status')
    t_msg=$(echo "$test_item" | jq -r '.message // empty')
    t_trace=$(echo "$test_item" | jq -r '.traceback // empty')
    t_dur=$(echo "$test_item" | jq -r '.duration // 0')
    t_module=$(echo "$test_item" | jq -r '.module // empty')

    # Reconstruct the same unique title used during case creation
    t_unique_title="$t_name"
    if [[ -n "$t_module" && "$t_module" != "$t_name" ]]; then
        t_unique_title="${t_module} - ${t_name}"
    fi

    case_id=$(grep -F "${t_unique_title}=" "$CASE_MAP_FILE" | head -n1 | rev | cut -d'=' -f1 | rev)

    if [[ -z "$case_id" ]]; then
        log_warn "Could not find Case ID for '$t_unique_title'. Skipping result."
        continue
    fi

    test_id=$(grep -F "${case_id}=" "$TEST_ID_MAP" | head -n1 | rev | cut -d'=' -f1 | rev)

    if [[ -z "$test_id" ]]; then
        log_warn "Could not find Test ID for '$t_unique_title' (Case $case_id). Skipping."
        continue
    fi

    status_id=$(map_status_to_id "$t_status")

    elapsed=""
    if [[ -n "$t_dur" && "$t_dur" != "0" && "$t_dur" != "null" ]]; then
        val=$(printf "%.0f" "$t_dur" 2>/dev/null || echo "0")
        [[ "$val" -lt 1 ]] && val=1
        elapsed="${val}s"
    fi

    comment="Test: ${t_name}"
    if [[ -n "$t_msg" ]]; then comment="${comment}"$'\n'"Message: ${t_msg}"; fi
    if [[ -n "$t_trace" ]]; then comment="${comment}"$'\n'"Traceback: ${t_trace}"; fi

    log_info "Adding result for '$t_unique_title' ($status_id)"

    payload=$(jq -n \
        --argjson s "$status_id" \
        --arg c "$comment" \
        '{status_id: $s, comment: $c}')

    if [[ -n "$elapsed" ]]; then
        payload=$(echo "$payload" | jq --arg e "$elapsed" '. + {elapsed: $e}')
    fi

    api_request "POST" "add_result/${test_id}" "$payload" >/dev/null
done

rm "$TEST_ID_MAP"
section_end "add_results"

section_start "close_run" "Closing Test Run"
api_request "POST" "close_run/${RUN_ID}" "{}" >/dev/null
log_info "Test Run Closed."
section_end "close_run"

rm "$TMP_REPORT_JSON" "$CASE_MAP_FILE"

echo "Done. View run at: $RUN_URL"
