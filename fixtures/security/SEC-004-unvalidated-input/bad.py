import os
from flask import request, send_file

# Bad: user-controlled path with no validation (SEC-004)
def read_file():
    filename = request.args.get("file")
    path = os.path.join("/var/app/data", filename)
    with open(path) as f:
        return f.read()

def download():
    user_file = request.form.get("filename")
    return send_file(user_file)
