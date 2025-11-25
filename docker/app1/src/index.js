/**
 * App 1 - Node.js Web Application
 *
 * This application provides a simple web interface with endpoints to:
 * - Serve a welcome page
 * - Provide health check endpoint
 * - Make internal calls to App 2 via Docker network
 *
 * Part of Limbic Capital DevOps Technical Assessment
 */

const express = require("express");
const axios = require("axios");
const helmet = require("helmet");
const morgan = require("morgan");
const cors = require("cors");

// Initialize Express app
const app = express();

// Configuration
const PORT = process.env.PORT || 3000;
const APP2_URL = process.env.APP2_URL || "http://app2:5000";
const NODE_ENV = process.env.NODE_ENV || "development";

// Middleware
app.use(helmet()); // Security headers
app.use(cors()); // CORS support
app.use(express.json()); // Parse JSON bodies
app.use(morgan("combined")); // Request logging

// ============================================================================
// Routes
// ============================================================================

/**
 * GET / - Welcome page
 * Returns HTML with information about the service
 */
app.get("/", (req, res) => {
  const html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Limbic Capital - App 1</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 20px;
        }
        .container {
          background: white;
          border-radius: 20px;
          padding: 40px;
          max-width: 800px;
          box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
          color: #333;
          margin-bottom: 10px;
          font-size: 2.5em;
        }
        .subtitle {
          color: #666;
          margin-bottom: 30px;
          font-size: 1.1em;
        }
        .info {
          background: #f8f9fa;
          border-left: 4px solid #667eea;
          padding: 15px;
          margin: 20px 0;
          border-radius: 4px;
        }
        .endpoints {
          margin: 20px 0;
        }
        .endpoint {
          background: #e9ecef;
          padding: 12px;
          margin: 10px 0;
          border-radius: 8px;
          font-family: 'Courier New', monospace;
          display: flex;
          align-items: center;
        }
        .method {
          background: #28a745;
          color: white;
          padding: 4px 12px;
          border-radius: 4px;
          margin-right: 10px;
          font-weight: bold;
          font-size: 0.85em;
        }
        .path {
          color: #333;
          font-weight: 500;
        }
        .description {
          color: #666;
          margin-top: 5px;
          font-size: 0.9em;
        }
        .status {
          display: inline-block;
          background: #28a745;
          color: white;
          padding: 6px 16px;
          border-radius: 20px;
          font-size: 0.9em;
          font-weight: 500;
        }
        .button {
          display: inline-block;
          background: #667eea;
          color: white;
          padding: 12px 24px;
          border-radius: 8px;
          text-decoration: none;
          margin: 10px 10px 0 0;
          transition: background 0.3s;
        }
        .button:hover {
          background: #764ba2;
        }
        footer {
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid #e9ecef;
          color: #666;
          font-size: 0.9em;
          text-align: center;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🚀 App 1 - Web Service</h1>
        <p class="subtitle">Limbic Capital DevOps Technical Assessment</p>
        
        <div class="info">
          <strong>Status:</strong> <span class="status">✓ Running</span><br>
          <strong>Environment:</strong> ${NODE_ENV}<br>
          <strong>Container:</strong> app1<br>
          <strong>Network:</strong> internal_net
        </div>

        <h2>📡 Available Endpoints</h2>
        <div class="endpoints">
          <div class="endpoint">
            <span class="method">GET</span>
            <div>
              <div class="path">/</div>
              <div class="description">This welcome page</div>
            </div>
          </div>
          
          <div class="endpoint">
            <span class="method">GET</span>
            <div>
              <div class="path">/ping</div>
              <div class="description">Health check endpoint</div>
            </div>
          </div>
          
          <div class="endpoint">
            <span class="method">GET</span>
            <div>
              <div class="path">/call-app2</div>
              <div class="description">Calls App 2 internally and returns response</div>
            </div>
          </div>
        </div>

        <h2>🧪 Test the Endpoints</h2>
        <a href="/ping" class="button">Test /ping</a>
        <a href="/call-app2" class="button">Test /call-app2</a>

        <footer>
          <strong>Limbic Capital DevOps Assessment</strong><br>
          LXD → Docker → Cloudflare Tunnel Architecture
        </footer>
      </div>
    </body>
    </html>
  `;

  res.send(html);
});

/**
 * GET /ping - Health check endpoint
 * Returns simple health status
 */
app.get("/ping", (req, res) => {
  res.json({
    status: "ok",
    service: "app1",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    message: "pong",
  });
});

/**
 * GET /call-app2 - Internal service communication
 * Makes an HTTP request to App 2 using Docker DNS
 */
app.get("/call-app2", async (req, res) => {
  try {
    console.log(`[App1] Making request to App 2 at: ${APP2_URL}/status`);

    const startTime = Date.now();
    const response = await axios.get(`${APP2_URL}/status`, {
      timeout: 5000,
      headers: {
        "X-Forwarded-By": "app1",
      },
    });
    const responseTime = Date.now() - startTime;

    console.log(`[App1] Received response from App 2 in ${responseTime}ms`);

    res.json({
      success: true,
      message: "Successfully called App 2",
      app1_timestamp: new Date().toISOString(),
      app2_response: response.data,
      response_time_ms: responseTime,
      connection: {
        from: "app1",
        to: "app2",
        url: `${APP2_URL}/status`,
        method: "GET",
        network: "internal_net (Docker bridge)",
      },
    });
  } catch (error) {
    console.error("[App1] Error calling App 2:", error.message);

    res.status(503).json({
      success: false,
      message: "Failed to call App 2",
      error: error.message,
      app1_timestamp: new Date().toISOString(),
      connection: {
        from: "app1",
        to: "app2",
        url: `${APP2_URL}/status`,
        attempted: true,
      },
      troubleshooting: {
        check_docker_network: "Ensure both containers are on internal_net",
        check_app2_running: "Verify app2 container is running: docker ps",
        check_app2_health: "Check app2 logs: docker logs app2",
      },
    });
  }
});

/**
 * GET /health - Detailed health check
 * Returns comprehensive health information
 */
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    service: "app1",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
    uptime_seconds: process.uptime(),
    memory: process.memoryUsage(),
    environment: NODE_ENV,
    dependencies: {
      app2: {
        url: APP2_URL,
        configured: true,
      },
    },
  });
});

/**
 * GET /info - Service information
 * Returns metadata about the service
 */
app.get("/info", (req, res) => {
  res.json({
    service_name: "app1-web-service",
    version: "1.0.0",
    description: "Web application for Limbic Capital DevOps Assessment",
    environment: NODE_ENV,
    port: PORT,
    endpoints: [
      { path: "/", method: "GET", description: "Welcome page" },
      { path: "/ping", method: "GET", description: "Health check" },
      {
        path: "/call-app2",
        method: "GET",
        description: "Call App 2 internally",
      },
      { path: "/health", method: "GET", description: "Detailed health info" },
      { path: "/info", method: "GET", description: "Service information" },
    ],
    architecture: {
      host: "LXD container (app-host)",
      runtime: "Docker",
      network: "internal_net (Docker bridge)",
      exposure: "Cloudflare Tunnel only",
    },
  });
});

// ============================================================================
// Error Handling
// ============================================================================

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: "Not Found",
    message: `Route ${req.method} ${req.path} not found`,
    available_endpoints: [
      "GET /",
      "GET /ping",
      "GET /call-app2",
      "GET /health",
      "GET /info",
    ],
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error("[App1] Error:", err);
  res.status(500).json({
    error: "Internal Server Error",
    message: NODE_ENV === "development" ? err.message : "Something went wrong",
  });
});

// ============================================================================
// Server Startup
// ============================================================================

const server = app.listen(PORT, "0.0.0.0", () => {
  console.log("=".repeat(60));
  console.log(`🚀 App 1 - Web Service`);
  console.log("=".repeat(60));
  console.log(`Environment: ${NODE_ENV}`);
  console.log(`Port: ${PORT}`);
  console.log(`App2 URL: ${APP2_URL}`);
  console.log(`Server started: ${new Date().toISOString()}`);
  console.log("=".repeat(60));
  console.log("Available endpoints:");
  console.log("  GET  /           - Welcome page");
  console.log("  GET  /ping       - Health check");
  console.log("  GET  /call-app2  - Call App 2 internally");
  console.log("  GET  /health     - Detailed health info");
  console.log("  GET  /info       - Service information");
  console.log("=".repeat(60));
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("[App1] SIGTERM received, shutting down gracefully...");
  server.close(() => {
    console.log("[App1] Server closed");
    process.exit(0);
  });
});

process.on("SIGINT", () => {
  console.log("[App1] SIGINT received, shutting down gracefully...");
  server.close(() => {
    console.log("[App1] Server closed");
    process.exit(0);
  });
});

module.exports = app;
