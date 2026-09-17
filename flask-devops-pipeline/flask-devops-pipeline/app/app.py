"""Simple Flask service used to demonstrate a full DevOps pipeline."""
import os
import platform
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template

APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")


def create_app() -> Flask:
    app = Flask(__name__)

    @app.route("/")
    def index():
        return render_template(
            "index.html",
            version=APP_VERSION,
            environment=ENVIRONMENT,
            hostname=socket.gethostname(),
        )

    @app.route("/health")
    def health():
        """Liveness probe used by Docker HEALTHCHECK and the Jenkins smoke test."""
        return jsonify(status="healthy", version=APP_VERSION), 200

    @app.route("/api/info")
    def info():
        return jsonify(
            app="flask-devops-pipeline",
            version=APP_VERSION,
            environment=ENVIRONMENT,
            hostname=socket.gethostname(),
            python=platform.python_version(),
            served_at=datetime.now(timezone.utc).isoformat(),
        )

    @app.errorhandler(404)
    def not_found(_):
        return jsonify(error="not found"), 404

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)))
