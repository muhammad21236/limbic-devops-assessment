"""
App 2 - Python Flask API Service

This application provides a simple REST API with endpoints to:
- Return service status
- Provide health information
- Demonstrate microservices architecture

Part of Limbic Capital DevOps Technical Assessment
Protected by Cloudflare Zero Trust Access
"""

import os
import platform
import sys
import time
from datetime import datetime

from flask import Flask, jsonify, request

# Initialize Flask app
app = Flask(__name__)

# Configuration
PORT = int(os.getenv("PORT", 5000))
FLASK_ENV = os.getenv("FLASK_ENV", "development")
LOG_LEVEL = os.getenv("LOG_LEVEL", "info")

# Application metadata
APP_VERSION = "1.0.0"
APP_NAME = "app2-api-service"
START_TIME = time.time()

# ============================================================================
# Utility Functions
# ============================================================================


def get_uptime():
    """Calculate application uptime in seconds"""
    return time.time() - START_TIME


def format_uptime(seconds):
    """Format uptime in human-readable format"""
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)

    parts = []
    if days > 0:
        parts.append(f"{days}d")
    if hours > 0:
        parts.append(f"{hours}h")
    if minutes > 0:
        parts.append(f"{minutes}m")
    parts.append(f"{secs}s")

    return " ".join(parts)


def log_request():
    """Log incoming request details"""
    forwarded_by = request.headers.get("X-Forwarded-By", "unknown")
    print(
        f"[App2] {request.method} {request.path} - Forwarded by: {forwarded_by}",
        flush=True,
    )


# ============================================================================
# Routes
# ============================================================================


@app.route("/")
def home():
    """Root endpoint - Service information"""
    log_request()

    return jsonify(
        {
            "service": APP_NAME,
            "version": APP_VERSION,
            "message": "App 2 API Service - Limbic Capital DevOps Assessment",
            "status": "running",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "endpoints": [
                {"path": "/", "method": "GET", "description": "Service information"},
                {"path": "/status", "method": "GET", "description": "Service status"},
                {
                    "path": "/health",
                    "method": "GET",
                    "description": "Detailed health check",
                },
                {"path": "/info", "method": "GET", "description": "System information"},
            ],
            "protection": "Cloudflare Zero Trust Access",
        }
    )


@app.route("/status")
def status():
    """Status endpoint - Simple status check"""
    log_request()

    uptime_seconds = get_uptime()

    return jsonify(
        {
            "service": "app2",
            "status": "ok",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "uptime_seconds": round(uptime_seconds, 2),
            "uptime": format_uptime(uptime_seconds),
            "version": APP_VERSION,
            "environment": FLASK_ENV,
        }
    )


@app.route("/health")
def health():
    """Health check endpoint - Detailed health information"""
    log_request()

    uptime_seconds = get_uptime()

    return jsonify(
        {
            "status": "healthy",
            "service": APP_NAME,
            "version": APP_VERSION,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "uptime": {
                "seconds": round(uptime_seconds, 2),
                "formatted": format_uptime(uptime_seconds),
                "started_at": datetime.fromtimestamp(START_TIME).isoformat() + "Z",
            },
            "environment": {
                "flask_env": FLASK_ENV,
                "python_version": sys.version.split()[0],
                "platform": platform.platform(),
                "log_level": LOG_LEVEL,
            },
            "system": {"python_path": sys.executable, "working_directory": os.getcwd()},
            "checks": {
                "api_responsive": True,
                "can_connect": True,
                "environment_loaded": True,
            },
        }
    )


@app.route("/info")
def info():
    """Information endpoint - Service metadata"""
    log_request()

    return jsonify(
        {
            "service_name": APP_NAME,
            "version": APP_VERSION,
            "description": "Python Flask API service for Limbic Capital DevOps Assessment",
            "author": "Limbic Capital",
            "environment": FLASK_ENV,
            "port": PORT,
            "python_version": sys.version,
            "flask_version": Flask.__version__,
            "architecture": {
                "layer": "Application Layer",
                "host": "LXD container (app-host)",
                "runtime": "Docker",
                "network": "internal_net (Docker bridge)",
                "exposure": "Cloudflare Tunnel with Zero Trust Access",
                "communication": "Called by app1 via Docker DNS",
            },
            "security": {
                "authentication": "Cloudflare Access",
                "encryption": "TLS via Cloudflare",
                "non_root_user": True,
                "minimal_privileges": True,
            },
            "features": [
                "RESTful API",
                "JSON responses",
                "Health monitoring",
                "Service-to-service communication",
                "Cloudflare Zero Trust integration",
            ],
        }
    )


@app.route("/ping")
def ping():
    """Simple ping endpoint"""
    log_request()

    return jsonify(
        {
            "message": "pong",
            "service": "app2",
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
    )


# ============================================================================
# Error Handlers
# ============================================================================


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify(
        {
            "error": "Not Found",
            "message": f"Route {request.method} {request.path} not found",
            "status_code": 404,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "available_endpoints": [
                "GET /",
                "GET /status",
                "GET /health",
                "GET /info",
                "GET /ping",
            ],
        }
    ), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return jsonify(
        {
            "error": "Internal Server Error",
            "message": "Something went wrong",
            "status_code": 500,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
    ), 500


@app.errorhandler(Exception)
def handle_exception(error):
    """Handle all other exceptions"""
    print(f"[App2] Error: {str(error)}", flush=True)

    return jsonify(
        {
            "error": "Internal Server Error",
            "message": str(error)
            if FLASK_ENV == "development"
            else "Something went wrong",
            "status_code": 500,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        }
    ), 500


# ============================================================================
# Request/Response Middleware
# ============================================================================


@app.before_request
def before_request():
    """Log before each request"""
    request.start_time = time.time()


@app.after_request
def after_request(response):
    """Log after each request and add headers"""
    # Add custom headers
    response.headers["X-Service"] = APP_NAME
    response.headers["X-Version"] = APP_VERSION

    # Calculate request duration
    if hasattr(request, "start_time"):
        duration = time.time() - request.start_time
        response.headers["X-Response-Time"] = f"{duration:.3f}s"

    # Log response
    if FLASK_ENV == "development":
        print(
            f"[App2] Response: {response.status_code} - {response.headers.get('X-Response-Time', 'N/A')}",
            flush=True,
        )

    return response


# ============================================================================
# Application Startup
# ============================================================================


def print_banner():
    """Print startup banner"""
    print("=" * 60)
    print("🐍 App 2 - Python Flask API Service")
    print("=" * 60)
    print(f"Service: {APP_NAME}")
    print(f"Version: {APP_VERSION}")
    print(f"Environment: {FLASK_ENV}")
    print(f"Port: {PORT}")
    print(f"Python: {sys.version.split()[0]}")
    try:
        import flask

        print(f"Flask: {flask.__version__}")
    except:
        print("Flask: (version unavailable)")
    print(f"Started: {datetime.utcnow().isoformat()}Z")
    print("=" * 60)
    print("Available endpoints:")
    print("  GET  /           - Service information")
    print("  GET  /status     - Service status")
    print("  GET  /health     - Detailed health check")
    print("  GET  /info       - System information")
    print("  GET  /ping       - Simple ping")
    print("=" * 60)
    print("🔒 Protected by Cloudflare Zero Trust Access")
    print("=" * 60)


if __name__ == "__main__":
    print_banner()

    # Run Flask app
    app.run(
        host="0.0.0.0",
        port=PORT,
        debug=(FLASK_ENV == "development"),
        use_reloader=False,  # Disable reloader in production
    )
