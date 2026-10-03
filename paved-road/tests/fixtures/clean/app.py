"""Fixture: a small service with nothing for any stage to find."""
import json
import subprocess


def list_files(folder):
    return subprocess.run(["ls", folder], capture_output=True, check=True).stdout


def parse(body):
    return json.loads(body)
