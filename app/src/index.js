"use strict";

const express = require("express");
const promClient = require("prom-client");
const { createStore } = require("./store");

/**
 * Build the Express app around a store. Exported separately from the
 * listener so tests can bind an ephemeral port.
 */
function createApp(store) {
  const app = express();

  // --- Prometheus metrics -------------------------------------------------
  const registry = new promClient.Registry();
  promClient.collectDefaultMetrics({ register: registry });

  const httpRequestsTotal = new promClient.Counter({
    name: "http_requests_total",
    help: "Total number of HTTP requests",
    labelNames: ["method", "route", "status"],
    registers: [registry],
  });

  const httpRequestDuration = new promClient.Histogram({
    name: "http_request_duration_seconds",
    help: "HTTP request duration in seconds",
    labelNames: ["method", "route", "status"],
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
    registers: [registry],
  });

  app.use(express.json());

  // Observe every request once it finishes so we know the final status.
  app.use((req, res, next) => {
    const start = process.hrtime.bigint();
    res.on("finish", () => {
      const route = req.route ? req.route.path : req.path;
      const labels = {
        method: req.method,
        route,
        status: String(res.statusCode),
      };
      httpRequestsTotal.inc(labels);
      httpRequestDuration.observe(
        labels,
        Number(process.hrtime.bigint() - start) / 1e9
      );
    });
    next();
  });

  // --- Health & metrics ---------------------------------------------------
  app.get("/health", (req, res) => {
    res.json({ status: "ok", uptime: process.uptime() });
  });

  app.get("/metrics", async (req, res) => {
    res.set("Content-Type", registry.contentType);
    res.end(await registry.metrics());
  });

  // --- Tasks API ----------------------------------------------------------
  app.get("/api/tasks", async (req, res, next) => {
    try {
      res.json(await store.list());
    } catch (err) {
      next(err);
    }
  });

  app.post("/api/tasks", async (req, res, next) => {
    try {
      const title = typeof req.body?.title === "string" ? req.body.title.trim() : "";
      if (!title) {
        return res.status(400).json({ error: "title is required" });
      }
      const task = await store.create(title);
      return res.status(201).json(task);
    } catch (err) {
      return next(err);
    }
  });

  app.patch("/api/tasks/:id", async (req, res, next) => {
    try {
      const patch = {};
      if (req.body?.title !== undefined) {
        if (typeof req.body.title !== "string" || !req.body.title.trim()) {
          return res.status(400).json({ error: "title must be a non-empty string" });
        }
        patch.title = req.body.title.trim();
      }
      if (req.body?.done !== undefined) {
        if (typeof req.body.done !== "boolean") {
          return res.status(400).json({ error: "done must be a boolean" });
        }
        patch.done = req.body.done;
      }
      if (Object.keys(patch).length === 0) {
        return res.status(400).json({ error: "nothing to update" });
      }
      const task = await store.update(req.params.id, patch);
      if (!task) return res.status(404).json({ error: "task not found" });
      return res.json(task);
    } catch (err) {
      return next(err);
    }
  });

  app.delete("/api/tasks/:id", async (req, res, next) => {
    try {
      const removed = await store.remove(req.params.id);
      if (!removed) return res.status(404).json({ error: "task not found" });
      return res.status(204).end();
    } catch (err) {
      return next(err);
    }
  });

  app.use((req, res) => res.status(404).json({ error: "not found" }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ error: "internal server error" });
  });

  return app;
}

async function main() {
  const port = Number(process.env.PORT || 3000);
  const store = createStore();
  await store.init();

  const app = createApp(store);
  const server = app.listen(port, () => {
    console.log(`taskboard-api listening on :${port}`);
  });

  // Graceful shutdown: stop accepting connections, drain, close the store.
  let shuttingDown = false;
  async function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`${signal} received, shutting down gracefully...`);
    server.close(async () => {
      try {
        await store.close();
      } finally {
        process.exit(0);
      }
    });
    // Don't hang forever if a connection refuses to close.
    setTimeout(() => process.exit(1), 10_000).unref();
  }

  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}

if (require.main === module) {
  main().catch((err) => {
    console.error("failed to start:", err);
    process.exit(1);
  });
}

module.exports = { createApp };
