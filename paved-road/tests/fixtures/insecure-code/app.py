"""Fixture: a handler with a command injection the SAST stage must find."""
import subprocess


def archive(request):
    name = request.args["name"]
    subprocess.run("tar czf /tmp/out.tgz " + name, shell=True, check=True)
