WHAT_BREAKS="on bash < 4.4 \"\${arr[@]}\" on an empty array is an unbound-variable error under set -u; the sweep would abort mid-run after some deletions had already happened, leaving a partially reaped host"
setup() {
  defer "host bash is $BASH_VERSION; no bash < 4.4 available to exercise the set -u interaction. Needs a container with bash 4.2/4.3 to run for real."
}
assert() { :; }
