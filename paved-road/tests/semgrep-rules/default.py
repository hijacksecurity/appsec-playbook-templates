# Test cases for ../../security-stages/semgrep-rules/default.yml (semgrep --test).
# "ruleid" lines must match the rule; "ok" lines must not.
import pickle
import subprocess

import requests
import yaml


def run(user_input, blob, doc, url):
    # ruleid: python-subprocess-shell-true
    subprocess.run("ls " + user_input, shell=True)
    # ruleid: python-subprocess-shell-true
    subprocess.check_output(f"grep {user_input} log.txt", shell=True)
    # ok: python-subprocess-shell-true
    subprocess.run(["ls", user_input])

    # ruleid: python-eval-exec
    eval(user_input)
    # ruleid: python-eval-exec
    exec(blob)
    # ok: python-eval-exec
    eval("1 + 1")

    # ruleid: python-yaml-unsafe-load
    yaml.load(doc)
    # ruleid: python-yaml-unsafe-load
    yaml.unsafe_load(doc)
    # ok: python-yaml-unsafe-load
    yaml.load(doc, Loader=yaml.SafeLoader)
    # ok: python-yaml-unsafe-load
    yaml.safe_load(doc)

    # ruleid: python-pickle-load
    pickle.loads(blob)

    # ruleid: python-requests-verify-false
    requests.get(url, verify=False)
    # ok: python-requests-verify-false
    requests.get(url, timeout=5)
