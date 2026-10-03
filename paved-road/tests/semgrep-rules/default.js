// Test cases for ../../security-stages/semgrep-rules/default.yml (semgrep --test).
function handle(input) {
  // ruleid: js-eval
  eval(input);
  // ruleid: js-eval
  const f = new Function("a", input);
  // ok: js-eval
  eval("1 + 1");
  // ok: js-eval
  return JSON.parse(input) && f;
}
module.exports = { handle };
