"use strict";

const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { createApp } = require("../src/index");
const { MemoryStore } = require("../src/store");

let server;
let baseUrl;

before(async () => {
  // Ephemeral port + in-memory store: the full API surface, no database.
  const app = createApp(new MemoryStore());
  await new Promise((resolve) => {
    server = app.listen(0, resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

async function api(path, options = {}) {
  return fetch(`${baseUrl}${path}`, {
    headers: { "content-type": "application/json" },
    ...options,
  });
}

test("GET /health returns 200 with status ok", async () => {
  const res = await api("/health");
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.status, "ok");
  assert.equal(typeof body.uptime, "number");
});

test("tasks CRUD lifecycle", async () => {
  // Create
  let res = await api("/api/tasks", {
    method: "POST",
    body: JSON.stringify({ title: "Write the tests" }),
  });
  assert.equal(res.status, 201);
  const created = await res.json();
  assert.equal(created.title, "Write the tests");
  assert.equal(created.done, false);
  assert.ok(created.id);

  // List contains the new task
  res = await api("/api/tasks");
  assert.equal(res.status, 200);
  const list = await res.json();
  assert.ok(list.some((t) => t.id === created.id));

  // Patch: mark done
  res = await api(`/api/tasks/${created.id}`, {
    method: "PATCH",
    body: JSON.stringify({ done: true }),
  });
  assert.equal(res.status, 200);
  const updated = await res.json();
  assert.equal(updated.done, true);
  assert.equal(updated.title, "Write the tests");

  // Patch: rename
  res = await api(`/api/tasks/${created.id}`, {
    method: "PATCH",
    body: JSON.stringify({ title: "Write better tests" }),
  });
  assert.equal(res.status, 200);
  assert.equal((await res.json()).title, "Write better tests");

  // Delete
  res = await api(`/api/tasks/${created.id}`, { method: "DELETE" });
  assert.equal(res.status, 204);

  // Gone from the list
  res = await api("/api/tasks");
  const after = await res.json();
  assert.ok(!after.some((t) => t.id === created.id));

  // Deleting again is a 404
  res = await api(`/api/tasks/${created.id}`, { method: "DELETE" });
  assert.equal(res.status, 404);
});

test("POST /api/tasks validates the title", async () => {
  const res = await api("/api/tasks", {
    method: "POST",
    body: JSON.stringify({}),
  });
  assert.equal(res.status, 400);
});

test("GET /metrics exposes http_requests_total", async () => {
  const res = await api("/metrics");
  assert.equal(res.status, 200);
  const text = await res.text();
  assert.match(text, /http_requests_total/);
});
