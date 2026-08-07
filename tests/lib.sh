# Assertion helpers sourced by *.test.sh files. A test file passes iff it exits 0.

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() { # expected actual label
  [ "$1" = "$2" ] || fail "$3: expected $(printf '%q' "$1"), got $(printf '%q' "$2")"
}

assert_exit() { # expected-code label cmd [args...]
  local expected=$1 label=$2 status=0
  shift 2
  "$@" >/dev/null 2>&1 || status=$?
  [ "$status" -eq "$expected" ] || fail "$label: expected exit $expected, got $status"
}

assert_contains() { # haystack needle label
  case "$1" in
    *"$2"*) ;;
    *) fail "$3: output does not contain $(printf '%q' "$2")" ;;
  esac
}

assert_not_contains() { # haystack needle label
  case "$1" in
    *"$2"*) fail "$3: output unexpectedly contains $(printf '%q' "$2")" ;;
  esac
}
