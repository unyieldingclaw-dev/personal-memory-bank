import traceback
from flask import Flask, jsonify

app = Flask(__name__)

# Bad: full stack trace and internal path returned to user (SEC-008)
@app.route("/process")
def process():
    try:
        result = do_something()
        return jsonify(result)
    except Exception as e:
        return jsonify({
            "error": str(e),
            "traceback": traceback.format_exc(),
            "file": __file__,
            "python_path": __import__("sys").path
        }), 500
