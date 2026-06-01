from flask import Flask, jsonify
import database

app = Flask(__name__)

# Bad: admin endpoint with no authentication check (SEC-005)
@app.route("/admin/users")
def list_all_users():
    users = database.get_all_users()
    return jsonify(users)

@app.route("/admin/delete/<user_id>", methods=["DELETE"])
def delete_user(user_id):
    database.delete_user(user_id)
    return jsonify({"deleted": user_id})
