"""Local-only UI for validating the NMMTools remote target framework."""

from __future__ import annotations

import logging
import os

from flask import Flask, jsonify, render_template, request

from targeting import TargetDiscovery, TargetValidationError


POWERSHELL_PATH = os.environ.get(
    "NMM_POWERSHELL_PATH",
    r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
)
DISCOVERY_TIMEOUT = int(os.environ.get("NMM_TARGET_TIMEOUT", "20"))
ALLOWED_CLIENTS = {"127.0.0.1", "::1"}

app = Flask(__name__)
discovery = TargetDiscovery(POWERSHELL_PATH, timeout=DISCOVERY_TIMEOUT)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
logger = logging.getLogger("NMMTargetDiscovery")


@app.before_request
def require_local_client():
    """Keep the unauthenticated prototype accessible only on its own workstation."""
    if request.remote_addr not in ALLOWED_CLIENTS:
        return jsonify({
            "success": False,
            "error": "This discovery prototype accepts localhost requests only.",
        }), 403
    return None


@app.get("/")
def index():
    return render_template("target_discovery.html")


@app.post("/api/target-status")
def target_status():
    """Perform validated, read-only DNS and management discovery."""
    if request.content_length and request.content_length > 4096:
        return jsonify({"success": False, "error": "Request is too large."}), 413

    data = request.get_json(silent=True) or {}
    try:
        status = discovery.discover(data.get("target_host"))
    except TargetValidationError as exc:
        return jsonify({"success": False, "error": str(exc)}), 400

    logger.info(
        "target=%s dns=%s winrm=%s interactive_user=%s",
        status["target"],
        status["dns_resolved"],
        status["winrm_available"],
        status.get("interactive_user"),
    )
    return jsonify({"success": True, "target": status})


@app.get("/health")
def health():
    return jsonify({
        "status": "healthy",
        "mode": "read-only",
        "binding": "localhost",
    })


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001, debug=False)
