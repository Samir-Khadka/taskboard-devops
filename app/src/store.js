"use strict";

/**
 * Task stores.
 *
 * One small interface, two implementations:
 *   - PostgresStore: durable storage when DATABASE_URL is set.
 *   - MemoryStore:   zero-dependency in-memory storage for local dev/tests.
 *
 * Interface (all methods async):
 *   init()                  -> prepare storage (create table, etc.)
 *   list()                  -> Task[]
 *   create(title)           -> Task
 *   update(id, patch)       -> Task | null   (patch: { title?, done? })
 *   remove(id)              -> boolean
 *   close()                 -> release resources
 *
 * Task shape: { id, title, done, created_at }
 */

class MemoryStore {
  constructor() {
    this.tasks = [];
    this.nextId = 1;
  }

  async init() {}

  async list() {
    return [...this.tasks].sort((a, b) => a.id - b.id);
  }

  async create(title) {
    const task = {
      id: this.nextId++,
      title,
      done: false,
      created_at: new Date().toISOString(),
    };
    this.tasks.push(task);
    return task;
  }

  async update(id, patch) {
    const task = this.tasks.find((t) => t.id === Number(id));
    if (!task) return null;
    if (patch.title !== undefined) task.title = patch.title;
    if (patch.done !== undefined) task.done = patch.done;
    return task;
  }

  async remove(id) {
    const idx = this.tasks.findIndex((t) => t.id === Number(id));
    if (idx === -1) return false;
    this.tasks.splice(idx, 1);
    return true;
  }

  async close() {}
}

class PostgresStore {
  constructor(connectionString) {
    // Lazy require so the in-memory path never loads the pg driver.
    const { Pool } = require("pg");
    this.pool = new Pool({ connectionString });
  }

  async init() {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS tasks (
        id         SERIAL PRIMARY KEY,
        title      TEXT NOT NULL,
        done       BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
  }

  async list() {
    const { rows } = await this.pool.query(
      "SELECT id, title, done, created_at FROM tasks ORDER BY id ASC"
    );
    return rows;
  }

  async create(title) {
    const { rows } = await this.pool.query(
      "INSERT INTO tasks (title) VALUES ($1) RETURNING id, title, done, created_at",
      [title]
    );
    return rows[0];
  }

  async update(id, patch) {
    const fields = [];
    const values = [];
    if (patch.title !== undefined) {
      values.push(patch.title);
      fields.push(`title = $${values.length}`);
    }
    if (patch.done !== undefined) {
      values.push(patch.done);
      fields.push(`done = $${values.length}`);
    }
    if (fields.length === 0) return null;
    values.push(Number(id));
    const { rows } = await this.pool.query(
      `UPDATE tasks SET ${fields.join(", ")} WHERE id = $${values.length} RETURNING id, title, done, created_at`,
      values
    );
    return rows[0] || null;
  }

  async remove(id) {
    const { rowCount } = await this.pool.query("DELETE FROM tasks WHERE id = $1", [
      Number(id),
    ]);
    return rowCount > 0;
  }

  async close() {
    await this.pool.end();
  }
}

/**
 * Pick a store based on the environment: Postgres when DATABASE_URL is
 * set, otherwise in-memory.
 */
function createStore(env = process.env) {
  if (env.DATABASE_URL) {
    return new PostgresStore(env.DATABASE_URL);
  }
  return new MemoryStore();
}

module.exports = { createStore, MemoryStore, PostgresStore };
