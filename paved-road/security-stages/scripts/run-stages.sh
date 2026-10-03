#!/usr/bin/env bash
# Runs the paved-road security stages on one folder and decides pass or fail.
#
# Settings come from environment variables (action.yml sets them from its inputs):
#   SCAN_PATH        folder to scan (default: .)
#   SECRETS_MODE     block | warn | off   (default: block)  gitleaks
#   SCA_MODE         block | warn | off   (default: warn)   osv-scanner
#   SAST_MODE        block | warn | off   (default: warn)   semgrep
#   GITLEAKS_CONFIG  gitleaks config file (default: ../gitleaks.toml)
#   SEMGREP_CONFIG   semgrep rules: a file, or a registry name like p/default (default: ../semgrep-rules/default.yml)
#   TOOLS_DIR        where install-tools.sh put the tools (bin/ is added to PATH)
#   REPORT_DIR       where to keep the JSON reports (default: a temp folder)
#
# Each stage ends as: pass, findings, error (the tool itself failed), or off.
# A stage in block mode fails the run on findings or error (fail closed).
# A stage in warn mode never fails the run (fail open); it still reports.
# On GitHub Actions it writes a job summary and step outputs.
#
# Exit codes: 0 = nothing blocked, 1 = a blocking stage failed, 2 = bad settings.
set -uo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
scan_path=${SCAN_PATH:-.}
gitleaks_config=${GITLEAKS_CONFIG:-$here/gitleaks.toml}
semgrep_config=${SEMGREP_CONFIG:-$here/semgrep-rules/default.yml}
report_dir=${REPORT_DIR:-$(mktemp -d)}
[ -n "${TOOLS_DIR:-}" ] && PATH="$TOOLS_DIR/bin:$PATH"
summary=${GITHUB_STEP_SUMMARY:-/dev/null}
outputs=${GITHUB_OUTPUT:-/dev/null}

declare -A mode result count
mode[secrets]=${SECRETS_MODE:-block}
mode[sca]=${SCA_MODE:-warn}
mode[sast]=${SAST_MODE:-warn}

for s in secrets sca sast; do
  case "${mode[$s]}" in
    block|warn|off) ;;
    *) echo "run-stages.sh: ${s} mode must be block, warn or off (got '${mode[$s]}')" >&2; exit 2 ;;
  esac
done
if [ ! -d "$scan_path" ]; then
  echo "run-stages.sh: no such folder: $scan_path" >&2
  exit 2
fi
mkdir -p "$report_dir"

# record STAGE EXIT_CODE PASS_CODE FINDINGS_CODE [EXTRA_PASS_CODE]
record() {
  local s=$1 rc=$2
  if [ "$rc" -eq "$3" ] || { [ $# -ge 5 ] && [ "$rc" -eq "$5" ]; }; then result[$s]=pass
  elif [ "$rc" -eq "$4" ]; then result[$s]=findings
  else result[$s]=error
  fi
}

# Secrets: gitleaks on the files in the folder. --redact keeps secret values out of the log.
run_secrets() {
  local report=$report_dir/gitleaks.json rc
  echo "::group::secrets (gitleaks, ${mode[secrets]})"
  gitleaks dir "$scan_path" --config "$gitleaks_config" --redact --no-banner --verbose \
    --exit-code 1 --report-format json --report-path "$report"
  rc=$?
  record secrets "$rc" 0 1
  count[secrets]=$(jq 'length' "$report" 2>/dev/null || echo "?")
  echo "::endgroup::"
}

# SCA: osv-scanner on the lockfiles in the folder. Exit 128 means no lockfiles were found.
run_sca() {
  local report=$report_dir/osv-scanner.json rc
  echo "::group::sca (osv-scanner, ${mode[sca]})"
  osv-scanner scan source --recursive --format json --output-file "$report" "$scan_path"
  rc=$?
  record sca "$rc" 0 1 128
  count[sca]=$(jq '[.results[]?.packages[]?.vulnerabilities[]?.id] | unique | length' "$report" 2>/dev/null || echo 0)
  jq -r '.results[]?.packages[]? | . as $p | .vulnerabilities[]?
         | "\($p.package.name)@\($p.package.version): \(.id) \(.summary // "")"' "$report" 2>/dev/null
  echo "::endgroup::"
}

# SAST: semgrep with a local ruleset. --metrics=off keeps scan data on the runner.
run_sast() {
  local report=$report_dir/semgrep.json rc
  echo "::group::sast (semgrep, ${mode[sast]})"
  semgrep scan --config "$semgrep_config" --error --metrics=off --disable-version-check \
    --quiet --json-output="$report" --text "$scan_path"
  rc=$?
  record sast "$rc" 0 1
  count[sast]=$(jq '.results | length' "$report" 2>/dev/null || echo "?")
  echo "::endgroup::"
}

for s in secrets sca sast; do
  if [ "${mode[$s]}" = off ]; then result[$s]=off; count[$s]=-; continue; fi
  case $s in
    secrets) run_secrets ;;
    sca)     run_sca ;;
    sast)    run_sast ;;
  esac
done

blocked=()
{
  echo "### Security stages: \`$scan_path\`"
  echo
  echo "| Stage | Tool | Mode | Result | Findings |"
  echo "|---|---|---|---|---|"
} >> "$summary"
for s in secrets sca sast; do
  case $s in secrets) tool=gitleaks ;; sca) tool=osv-scanner ;; sast) tool=semgrep ;; esac
  verdict=${result[$s]}
  if [ "${mode[$s]}" = block ] && { [ "$verdict" = findings ] || [ "$verdict" = error ]; }; then
    blocked+=("$s"); verdict="$verdict (blocks)"
  elif [ "${mode[$s]}" = warn ] && [ "$verdict" != pass ]; then
    verdict="$verdict (warning only)"
  fi
  echo "| $s | $tool | ${mode[$s]} | $verdict | ${count[$s]} |" >> "$summary"
  echo "$s: mode=${mode[$s]} result=${result[$s]} findings=${count[$s]}"
  {
    echo "$s-result=${result[$s]}"
    echo "$s-count=${count[$s]}"
  } >> "$outputs"
done

if [ ${#blocked[@]} -gt 0 ]; then
  {
    echo
    echo "Blocked by: ${blocked[*]}. See the step log for details. To accept a risk, use the exception register."
  } >> "$summary"
  echo "::error::Blocked by: ${blocked[*]}"
  exit 1
fi
echo >> "$summary"
echo "Nothing blocked." >> "$summary"
exit 0
