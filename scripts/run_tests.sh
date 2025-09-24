#!/usr/bin/env bash
set -euo pipefail

# CookSavvy test runner
# Usage examples:
#   scripts/run_tests.sh
#   scripts/run_tests.sh --scheme CookSavvy --device "iPhone 15" --os latest
#   scripts/run_tests.sh --test-plan DefaultTestPlan
#   scripts/run_tests.sh --list-schemes
#   scripts/run_tests.sh --clean

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_FILE="${PROJECT_ROOT}/CookSavvy.xcodeproj"
DEFAULT_SCHEME="CookSavvy"
DEFAULT_TEST_PLAN="DefaultTestPlan"
DEFAULT_DEVICE="iPhone 16"
DEFAULT_OS="latest"
RESULTS_DIR="${PROJECT_ROOT}/TestResults"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RESULT_BUNDLE_PATH="${RESULTS_DIR}/CookSavvyTests-${TIMESTAMP}.xcresult"
TEMP_ROOT="${PROJECT_ROOT}/.tmp-tests/${TIMESTAMP}"

SCHEME="${DEFAULT_SCHEME}"
TEST_PLAN="${DEFAULT_TEST_PLAN}"
DEVICE="${DEFAULT_DEVICE}"
OS_VER="${DEFAULT_OS}"
CLEAN="false"
LIST_SCHEMES="false"
COMPACT="true"
ONLY_TESTS=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      SCHEME="$2"; shift 2 ;;
    --test-plan)
      TEST_PLAN="$2"; shift 2 ;;
    --device)
      DEVICE="$2"; shift 2 ;;
    --os)
      OS_VER="$2"; shift 2 ;;
    --clean)
      CLEAN="true"; shift ;;
    --list-schemes)
      LIST_SCHEMES="true"; shift ;;
    --verbose)
      COMPACT="false"; shift ;;
    --only)
      ONLY_TESTS="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
CookSavvy test runner

Options:
  --scheme <name>       Scheme to test (default: ${DEFAULT_SCHEME})
  --test-plan <name>    Test plan to use (default: ${DEFAULT_TEST_PLAN})
  --device <name>       Simulator device name (default: "${DEFAULT_DEVICE}")
  --os <version>        Simulator OS version (default: ${DEFAULT_OS})
  --clean               Run a clean build before testing
  --list-schemes        List schemes in the project and exit
  --verbose             verbose output
  --only <identifier>   Run only specific tests (e.g., CookSavvyTests/CSVZipAdapterTests)
  -h, --help            Show this help

Examples:
  scripts/run_tests.sh
  scripts/run_tests.sh --scheme CookSavvy --device "iPhone 15" --os latest
  scripts/run_tests.sh --test-plan DefaultTestPlan
EOF
      exit 0 ;;
    *)
      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not installed or not in PATH." >&2
  exit 1
fi

if [[ "${LIST_SCHEMES}" == "true" ]]; then
  echo "Listing schemes in project: ${PROJECT_FILE}" >&2
  xcodebuild -list -project "${PROJECT_FILE}"
  exit 0
fi

mkdir -p "${RESULTS_DIR}"
mkdir -p "${TEMP_ROOT}"

DESTINATION="platform=iOS Simulator,name=${DEVICE},OS=${OS_VER}"

CMD=(xcodebuild \
  -project "${PROJECT_FILE}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -resultBundlePath "${RESULT_BUNDLE_PATH}" \
  -enableCodeCoverage YES)

if [[ -n "${TEST_PLAN}" ]]; then
  CMD+=( -testPlan "${TEST_PLAN}" )
fi

# If a specific test identifier was provided, forward to xcodebuild
if [[ -n "${ONLY_TESTS}" ]]; then
  # Support comma-separated multiple identifiers
  IFS=',' read -r -a ONLY_ARR <<< "${ONLY_TESTS}"
  for ident in "${ONLY_ARR[@]}"; do
    CMD+=( -only-testing "${ident}" )
  done
fi

if [[ "${CLEAN}" == "true" ]]; then
  CMD+=( clean test )
else
  CMD+=( test )
fi

echo "Running: TMPDIR=${TEMP_ROOT} ${CMD[*]}" >&2

# Use xcpretty if available for nicer output
if command -v xcpretty >/dev/null 2>&1; then
  set +e
  if [[ "${COMPACT}" == "true" ]]; then
    TMPDIR="${TEMP_ROOT}" "${CMD[@]}" | xcpretty --color --no-utf --simple --report junit --output "${RESULTS_DIR}/junit-${TIMESTAMP}.xml"
  else
    TMPDIR="${TEMP_ROOT}" "${CMD[@]}" | xcpretty --color --report junit --output "${RESULTS_DIR}/junit-${TIMESTAMP}.xml"
  fi
  STATUS=${PIPESTATUS[0]}
  set -e
else
  # Without xcpretty: optionally compact the raw xcodebuild output
  if [[ "${COMPACT}" == "true" ]]; then
    RAW_OUT="$(mktemp -t cooksavvy-xcbuild-raw.XXXXXX)"
    set +e
    TMPDIR="${TEMP_ROOT}" "${CMD[@]}" >"${RAW_OUT}" 2>&1
    STATUS=$?
    set -e
    # Filter verbose/perf/debug lines and truncate very long lines to 200 chars
    cat "${RAW_OUT}" \
      | sed -E \
        -e '/IDETestOperationsObserverDebug/d' \
        -e '/measured \[Time, seconds\]/d' \
        -e '/XCTPerformanceMetric_/d' \
        -e '/Resolve Package Graph/!p' -n \
      | awk '{ if (length($0) > 200) printf "%s...\n", substr($0,1,200); else print }'
    rm -f "${RAW_OUT}"
  else
    TMPDIR="${TEMP_ROOT}" "${CMD[@]}"
    STATUS=$?
  fi
fi

if [[ ${STATUS} -eq 0 ]]; then
  echo "✅ Tests passed. Result bundle: ${RESULT_BUNDLE_PATH}"
else
  echo "❌ Tests failed with status ${STATUS}. Result bundle: ${RESULT_BUNDLE_PATH}" >&2
fi

# Print a quick summary if xcrun xcresulttool is available
if command -v xcrun >/dev/null 2>&1; then
  if xcrun xcresulttool get --path "${RESULT_BUNDLE_PATH}" --format json >/dev/null 2>&1; then
    echo "\nSummary:" 
    # Count tests and failures from the summary JSON when available
    xcrun xcresulttool get --path "${RESULT_BUNDLE_PATH}" --format json \
      | /usr/bin/python3 - "$STATUS" <<'PY'
import json, sys
j=json.load(sys.stdin)
# Navigate to metrics if available
def find_summaries(obj):
    if isinstance(obj, dict):
        for k,v in obj.items():
            if k == 'testsCount' or k == 'testsFailedCount':
                return obj
            r = find_summaries(v)
            if r: return r
    elif isinstance(obj, list):
        for it in obj:
            r = find_summaries(it)
            if r: return r
    return None
s=find_summaries(j) or {}
print(f"  Tests: {s.get('testsCount','?')}  Failures: {s.get('testsFailedCount','?')}")
PY
  fi
fi

exit ${STATUS}
