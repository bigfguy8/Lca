#!/usr/bin/env sh
# lca tool layer (public, MIT) — executed by the core, sandboxed by the launcher.
# POSIX sh: no local, no BASH_SOURCE. Each tool returns a short observation;
# the core truncates to 2500 bytes.

lca_run_tool() {
  _line="$1"
  _tool="${_line%% *}"
  # if there's a space, _arg is everything after it; else empty
  case "${_line}" in
    *" "*) _arg="${_line#* }" ;;
    *)     _arg="" ;;
  esac
  # strip optional surrounding quotes
  _arg="${_arg#\"}"; _arg="${_arg%\"}"
  case "${_tool}" in
    ls)
      ls -la "${_arg:-.}" 2>&1 | head -n 40 ;;
    cat)
      sed -n "1,200p" "${_arg}" 2>&1 ;;
    grep)
      grep -n "${_arg}" 2>&1 | head -n 25 ;;
    write)
      # arg format: <path>|<content>. Path is up to the first '|'.
      # (toybox parameter-expansion with '|' patterns is unreliable; use cut)
      _path="$(printf '%s' "${_arg}" | cut -d'|' -f1)"
      _content="$(printf '%s' "${_arg}" | cut -d'|' -f2-)"
      # only under CWD, 16 KB cap
      case "${_path}" in
        ./*) : ;;
        "")  echo "Refusing: empty path"; return 1 ;;
        *)   echo "Refusing write outside CWD: ${_path}"; return 1 ;;
      esac
      mkdir -p "$(dirname "${_path}")" 2>/dev/null
      _len="${#_content}"
      if [ "${_len}" -gt 16384 ]; then
        echo "Refusing: content exceeds 16KB cap for one-line write"; return 1
      fi
      printf '%s\n' "${_content}" > "${_path}"
      echo "wrote ${_path} (${_len} bytes)" ;;
    writef)
      # multi-line safe: base64 content. arg = <path>|<base64>
      _path="$(printf '%s' "${_arg}" | cut -d'|' -f1)"
      _b64="$(printf '%s' "${_arg}" | cut -d'|' -f2-)"
      case "${_path}" in
        ./*) : ;;
        *) echo "Refusing write outside CWD: ${_path}"; return 1 ;;
      esac
      printf '%s' "${_b64}" | base64 -d > "${_path}" 2>/dev/null \
        && echo "wrote ${_path} (base64)" \
        || echo "base64 decode failed for ${_path}" ;;
    shell)
      # refuse: pipes, redirects, sudo, rm -rf with / or /*, and common destructive patterns
      case "${_arg}" in
        *"|"*|*">"*|*"<<"*|*sudo*|*"rm -rf /"*|*"rm -rf /*"*|*"rm -rf \"/*\""*|*"rm -rf '/*'"*)
          echo "Refusing: pipes/redirects/sudo/dangerous not allowed"; return 1 ;;
      esac
      ( eval "${_arg}" ) 2>&1 | head -n 40 ;;
    done)
      echo "DONE" ;;
    *)
      echo "Unknown tool: ${_tool}" ;;
  esac
}
