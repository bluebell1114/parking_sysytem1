import express from "express";
import cors from "cors";
import pg from "pg";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

const { Pool } = pg;
const PORT = Number(process.env.PORT || 4000);
const DATABASE_URL = process.env.DATABASE_URL;
const JWT_SECRET = process.env.JWT_SECRET || "dev-secret";

if (!DATABASE_URL) {
  console.error("DATABASE_URL required");
  process.exit(1);
}

const pool = new Pool({ connectionString: DATABASE_URL });
const app = express();
app.use(cors());
app.use(express.json({ limit: "1mb" }));

async function migrate() {
  await pool.query(`CREATE EXTENSION IF NOT EXISTS "pgcrypto";`);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      name TEXT NOT NULL DEFAULT '',
      is_admin BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS user_cars (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL DEFAULT '',
      plate TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (user_id, plate)
    );
    CREATE TABLE IF NOT EXISTS user_locations (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      lat DOUBLE PRECISION NOT NULL,
      lng DOUBLE PRECISION NOT NULL,
      accuracy_m REAL,
      label TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS parking_spots (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL DEFAULT 'Зогсоол',
      lat DOUBLE PRECISION NOT NULL,
      lng DOUBLE PRECISION NOT NULL,
      address TEXT,
      price_per_hour INT DEFAULT 0,
      total INT DEFAULT 0,
      available INT DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'free',
      is_available BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_user_locations_user ON user_locations(user_id, created_at DESC);
    CREATE TABLE IF NOT EXISTS payments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_ref TEXT NOT NULL,
      user_email TEXT,
      amount INT NOT NULL,
      hours INT NOT NULL DEFAULT 1,
      method TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      note TEXT,
      spot_id TEXT,
      approved_by UUID REFERENCES users(id),
      approved_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status, created_at DESC);
  `);

  // Wallet: add columns/tables safely for existing DBs
  await pool.query(
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS wallet_balance INT NOT NULL DEFAULT 0;`
  );
  await pool.query(`
    CREATE TABLE IF NOT EXISTS wallet_transactions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      kind TEXT NOT NULL, -- 'topup' | 'spend' | 'adjust'
      amount INT NOT NULL,
      method TEXT,
      note TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_wallet_tx_user ON wallet_transactions(user_id, created_at DESC);
  `);

  // Parking bookings (no hours chosen). Pay later based on duration.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS bookings (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      spot_id UUID NOT NULL REFERENCES parking_spots(id) ON DELETE RESTRICT,
      car_id UUID REFERENCES user_cars(id) ON DELETE SET NULL,
      car_plate TEXT NOT NULL DEFAULT '',
      spot_name TEXT NOT NULL,
      price_per_hour INT NOT NULL DEFAULT 0,
      started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      ended_at TIMESTAMPTZ,
      status TEXT NOT NULL DEFAULT 'active' -- 'active' | 'paid' | 'cancelled'
    );
    CREATE INDEX IF NOT EXISTS idx_bookings_user_active ON bookings(user_id, status, started_at DESC);
    CREATE INDEX IF NOT EXISTS idx_bookings_spot_active ON bookings(spot_id, status, started_at DESC);
  `);

  // For existing DBs where bookings already exists (safe no-op for new installs).
  await pool.query(
    `ALTER TABLE bookings ADD COLUMN IF NOT EXISTS car_id UUID REFERENCES user_cars(id) ON DELETE SET NULL;`
  );
  await pool.query(
    `ALTER TABLE bookings ADD COLUMN IF NOT EXISTS car_plate TEXT NOT NULL DEFAULT '';`
  );
}

async function seed() {
  const admins = await pool.query(
    `SELECT id FROM users WHERE is_admin = TRUE LIMIT 1`
  );
  if (admins.rows.length === 0) {
    const hash = await bcrypt.hash("admin123", 10);
    await pool.query(
      `INSERT INTO users (email, password_hash, name, is_admin)
       VALUES ($1, $2, $3, TRUE)
       ON CONFLICT (email) DO NOTHING`,
      ["admin@greenpark.com", hash, "Админ"]
    );
  }

  const spots = await pool.query(`SELECT id FROM parking_spots LIMIT 1`);
  if (spots.rows.length === 0) {
    const demo = [
      ["Сүхбаатар талбай ойролцоо", 47.918873, 106.917701, 2000, 50],
      ["Шангри-La / Central tower", 47.9169, 106.9215, 2500, 40],
      ["Их дэлгүүр орчим", 47.9225, 106.915, 1500, 60],
      ["Богд хаан ордон ойролцоо", 47.925, 106.908, 1800, 30],
    ];
    for (const [name, lat, lng, price, total] of demo) {
      await pool.query(
        `INSERT INTO parking_spots (name, lat, lng, address, price_per_hour, total, available, status, is_available)
         VALUES ($1, $2, $3, $4, $5, $6, $6, 'free', TRUE)`,
        [name, lat, lng, "Улаанбаатар (жишээ)", price, total]
      );
    }
    console.log("Seeded demo parking_spots");
  }
}

function signToken(userRow) {
  return jwt.sign(
    {
      sub: userRow.id,
      email: userRow.email,
      isAdmin: userRow.is_admin,
    },
    JWT_SECRET,
    { expiresIn: "30d" }
  );
}

function authMiddleware(required = true) {
  return (req, res, next) => {
    const h = req.headers.authorization;
    if (!h?.startsWith("Bearer ")) {
      if (required) return res.status(401).json({ error: "token_required" });
      req.user = null;
      return next();
    }
    try {
      const payload = jwt.verify(h.slice(7), JWT_SECRET);
      req.user = {
        id: payload.sub,
        email: payload.email,
        isAdmin: payload.isAdmin === true,
      };
      next();
    } catch {
      if (required) return res.status(401).json({ error: "invalid_token" });
      req.user = null;
      next();
    }
  };
}

function requireAdmin(req, res, next) {
  if (!req.user?.isAdmin) {
    return res.status(403).json({ error: "admin_only" });
  }
  next();
}

app.get("/health", (_, res) => res.json({ ok: true }));

app.post("/auth/register", async (req, res) => {
  try {
    const email = String(req.body.email || "")
      .trim()
      .toLowerCase();
    const password = String(req.body.password || "");
    const name = String(req.body.name || "").trim();
    if (!email || !password || password.length < 6) {
      return res.status(400).json({ error: "invalid_input" });
    }
    const hash = await bcrypt.hash(password, 10);
    const ins = await pool.query(
      `INSERT INTO users (email, password_hash, name)
       VALUES ($1, $2, $3)
       RETURNING id, email, name, is_admin`,
      [email, hash, name]
    );
    const row = ins.rows[0];
    const token = signToken(row);
    return res.status(201).json({
      token,
      user: {
        id: row.id,
        email: row.email,
        name: row.name,
        isAdmin: row.is_admin === true,
      },
    });
  } catch (e) {
    if (e.code === "23505") {
      return res.status(409).json({ error: "email_in_use" });
    }
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  }
});

app.post("/auth/login", async (req, res) => {
  try {
    const email = String(req.body.email || "")
      .trim()
      .toLowerCase();
    const password = String(req.body.password || "");
    const q = await pool.query(
      `SELECT id, email, name, password_hash, is_admin FROM users WHERE email = $1`,
      [email]
    );
    if (q.rows.length === 0) {
      return res.status(401).json({ error: "invalid_credentials" });
    }
    const row = q.rows[0];
    const ok = await bcrypt.compare(password, row.password_hash);
    if (!ok) {
      return res.status(401).json({ error: "invalid_credentials" });
    }
    const token = signToken(row);
    return res.json({
      token,
      user: {
        id: row.id,
        email: row.email,
        name: row.name,
        isAdmin: row.is_admin === true,
      },
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  }
});

app.get("/auth/me", authMiddleware(true), async (req, res) => {
  const q = await pool.query(
    `SELECT id, email, name, is_admin, wallet_balance, created_at FROM users WHERE id = $1`,
    [req.user.id]
  );
  if (q.rows.length === 0) return res.status(404).json({ error: "not_found" });
  const u = q.rows[0];
  res.json({
    id: u.id,
    email: u.email,
    name: u.name,
    isAdmin: u.is_admin,
    walletBalance: u.wallet_balance,
    createdAt: u.created_at,
  });
});

// ---------- Wallet (mobile user) ----------
app.get("/wallet/me", authMiddleware(true), async (req, res) => {
  const u = await pool.query(
    `SELECT wallet_balance FROM users WHERE id = $1`,
    [req.user.id]
  );
  if (u.rows.length === 0) return res.status(404).json({ error: "not_found" });
  const tx = await pool.query(
    `SELECT id, kind, amount, method, note, created_at
     FROM wallet_transactions
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT 20`,
    [req.user.id]
  );
  res.json({ balance: u.rows[0].wallet_balance, transactions: tx.rows });
});

app.post("/wallet/topup", authMiddleware(true), async (req, res) => {
  const amount = Number(req.body.amount);
  if (!Number.isFinite(amount) || amount < 1) {
    return res.status(400).json({ error: "invalid_amount" });
  }
  const method = req.body.method != null ? String(req.body.method) : null;
  const note = req.body.note != null ? String(req.body.note) : null;
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      `UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2`,
      [amount, req.user.id]
    );
    await client.query(
      `INSERT INTO wallet_transactions (user_id, kind, amount, method, note)
       VALUES ($1, 'topup', $2, $3, $4)`,
      [req.user.id, amount, method, note]
    );
    const u = await client.query(
      `SELECT wallet_balance FROM users WHERE id = $1`,
      [req.user.id]
    );
    await client.query("COMMIT");
    return res.status(201).json({ ok: true, balance: u.rows[0].wallet_balance });
  } catch (e) {
    await client.query("ROLLBACK");
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  } finally {
    client.release();
  }
});

// ---------- Cars (mobile) ----------
app.get("/cars", authMiddleware(true), async (req, res) => {
  const q = await pool.query(
    `SELECT id, name, plate, created_at
     FROM user_cars
     WHERE user_id = $1
     ORDER BY created_at DESC`,
    [req.user.id]
  );
  res.json({ items: q.rows });
});

app.post("/cars", authMiddleware(true), async (req, res) => {
  const name = String(req.body.name || "").trim();
  const plateRaw = String(req.body.plate || "").trim();
  const plate = plateRaw.replace(/\s+/g, "").toUpperCase();
  if (!plate) return res.status(400).json({ error: "plate_required" });
  if (plate.length > 20) return res.status(400).json({ error: "plate_too_long" });
  try {
    const ins = await pool.query(
      `INSERT INTO user_cars (user_id, name, plate)
       VALUES ($1, $2, $3)
       RETURNING id, name, plate, created_at`,
      [req.user.id, name, plate]
    );
    res.status(201).json(ins.rows[0]);
  } catch (e) {
    if (String(e?.code) === "23505") {
      return res.status(409).json({ error: "plate_exists" });
    }
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  }
});

app.patch("/cars/:id", authMiddleware(true), async (req, res) => {
  const id = String(req.params.id || "").trim();
  const fields = [];
  const vals = [];
  let i = 1;

  if (req.body.name != null) {
    fields.push(`name = $${i++}`);
    vals.push(String(req.body.name || "").trim());
  }
  if (req.body.plate != null) {
    const plateRaw = String(req.body.plate || "").trim();
    const plate = plateRaw.replace(/\s+/g, "").toUpperCase();
    if (!plate) return res.status(400).json({ error: "plate_required" });
    if (plate.length > 20) return res.status(400).json({ error: "plate_too_long" });
    fields.push(`plate = $${i++}`);
    vals.push(plate);
  }
  if (!fields.length) return res.status(400).json({ error: "no_fields" });

  vals.push(req.user.id);
  vals.push(id);
  try {
    const q = await pool.query(
      `UPDATE user_cars
       SET ${fields.join(", ")}
       WHERE user_id = $${i++} AND id::text = $${i}
       RETURNING id, name, plate, created_at`,
      vals
    );
    if (!q.rows.length) return res.status(404).json({ error: "not_found" });
    return res.json(q.rows[0]);
  } catch (e) {
    if (String(e?.code) === "23505") {
      return res.status(409).json({ error: "plate_exists" });
    }
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  }
});

app.delete("/cars/:id", authMiddleware(true), async (req, res) => {
  const id = String(req.params.id || "").trim();
  const r = await pool.query(
    `DELETE FROM user_cars WHERE user_id = $1 AND id::text = $2`,
    [req.user.id, id]
  );
  if (!r.rowCount) return res.status(404).json({ error: "not_found" });
  res.json({ ok: true });
});

app.post("/locations", authMiddleware(true), async (req, res) => {
  const lat = Number(req.body.lat);
  const lng = Number(req.body.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return res.status(400).json({ error: "invalid_lat_lng" });
  }
  const accuracy_m =
    req.body.accuracy_m != null ? Number(req.body.accuracy_m) : null;
  const label = req.body.label != null ? String(req.body.label) : null;
  await pool.query(
    `INSERT INTO user_locations (user_id, lat, lng, accuracy_m, label)
     VALUES ($1, $2, $3, $4, $5)`,
    [req.user.id, lat, lng, Number.isFinite(accuracy_m) ? accuracy_m : null, label]
  );
  res.status(201).json({ ok: true });
});

app.get("/locations", authMiddleware(true), async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 100, 500);
  const q = await pool.query(
    `SELECT id, lat, lng, accuracy_m, label, created_at
     FROM user_locations WHERE user_id = $1
     ORDER BY created_at DESC LIMIT $2`,
    [req.user.id, limit]
  );
  res.json({ items: q.rows });
});

app.get("/spots", async (_req, res) => {
  const q = await pool.query(
    `SELECT ps.id, ps.name, ps.lat, ps.lng, ps.address, ps.price_per_hour, ps.total, ps.available, ps.status, ps.is_available, ps.created_at,
            (SELECT b.car_plate
             FROM bookings b
             WHERE b.spot_id = ps.id AND b.status = 'active'
             ORDER BY b.started_at DESC
             LIMIT 1) AS current_car_plate
     FROM parking_spots ps
     WHERE status IS DISTINCT FROM 'deleted'
     ORDER BY created_at ASC`
  );
  res.json({ items: q.rows });
});

// ---------- Bookings (mobile) ----------
app.get("/bookings/active", authMiddleware(true), async (req, res) => {
  const q = await pool.query(
    `SELECT b.id, b.spot_id, b.spot_name, b.price_per_hour, b.started_at, b.status, b.car_id, b.car_plate
     FROM bookings b
     WHERE b.user_id = $1 AND b.status = 'active'
     ORDER BY b.started_at DESC
     LIMIT 1`,
    [req.user.id]
  );
  if (q.rows.length === 0) return res.json({ active: null });
  return res.json({ active: q.rows[0] });
});

app.post("/bookings/start", authMiddleware(true), async (req, res) => {
  const spotId = String(req.body.spot_id || "").trim();
  const carId = String(req.body.car_id || "").trim();
  if (!spotId) return res.status(400).json({ error: "spot_required" });
  if (!carId) return res.status(400).json({ error: "car_required" });

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Prevent multiple active bookings per user
    const has = await client.query(
      `SELECT id FROM bookings WHERE user_id = $1 AND status = 'active' LIMIT 1`,
      [req.user.id]
    );
    if (has.rows.length) {
      await client.query("ROLLBACK");
      return res.status(409).json({ error: "already_active" });
    }

    // Decrement availability
    const spot = await client.query(
      `UPDATE parking_spots
       SET available = GREATEST(available - 1, 0),
           is_available = (available - 1) > 0
       WHERE id::text = $1 AND available > 0
       RETURNING id, name, price_per_hour, available, total`,
      [spotId]
    );
    if (spot.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(409).json({ error: "spot_full" });
    }

    const cq = await client.query(
      `SELECT id, plate FROM user_cars WHERE user_id = $1 AND id::text = $2`,
      [req.user.id, carId]
    );
    if (cq.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "car_not_found" });
    }

    const s = spot.rows[0];
    const ins = await client.query(
      `INSERT INTO bookings (user_id, spot_id, car_id, car_plate, spot_name, price_per_hour)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, spot_id, spot_name, price_per_hour, started_at, status, car_id, car_plate`,
      [req.user.id, s.id, cq.rows[0].id, cq.rows[0].plate, s.name, s.price_per_hour || 0]
    );

    await client.query("COMMIT");
    return res.status(201).json({ booking: ins.rows[0] });
  } catch (e) {
    await client.query("ROLLBACK");
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  } finally {
    client.release();
  }
});

function ceilHours(startedAt) {
  const ms = Date.now() - new Date(startedAt).getTime();
  const h = Math.ceil(ms / 3600000);
  return Math.max(1, Math.min(h, 24));
}

app.post("/bookings/pay", authMiddleware(true), async (req, res) => {
  const bookingId = String(req.body.booking_id || "").trim();
  const method = req.body.method != null ? String(req.body.method) : "wallet";
  if (!bookingId) return res.status(400).json({ error: "booking_required" });

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const bq = await client.query(
      `SELECT * FROM bookings WHERE id::text = $1 AND user_id = $2`,
      [bookingId, req.user.id]
    );
    if (bq.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "not_found" });
    }
    const b = bq.rows[0];
    if (b.status !== "active") {
      await client.query("ROLLBACK");
      return res.status(409).json({ error: "not_active" });
    }

    const hours = ceilHours(b.started_at);
    const amount = Math.max(1, Number(b.price_per_hour || 0) * hours);

    // Check wallet balance
    const uq = await client.query(
      `SELECT wallet_balance, email FROM users WHERE id = $1`,
      [req.user.id]
    );
    if (uq.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "not_found" });
    }
    const balance = Number(uq.rows[0].wallet_balance || 0);
    if (balance < amount) {
      await client.query("ROLLBACK");
      return res.status(409).json({ error: "insufficient_balance", balance, amount });
    }

    // Deduct wallet + tx
    await client.query(
      `UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2`,
      [amount, req.user.id]
    );
    await client.query(
      `INSERT INTO wallet_transactions (user_id, kind, amount, method, note)
       VALUES ($1, 'spend', $2, $3, $4)`,
      [req.user.id, amount, method, `parking:${b.spot_name}`]
    );

    // Mark booking paid
    await client.query(
      `UPDATE bookings SET status = 'paid', ended_at = NOW() WHERE id = $1`,
      [b.id]
    );

    // Release spot availability back
    await client.query(
      `UPDATE parking_spots
       SET available = LEAST(available + 1, COALESCE(total, available + 1)),
           is_available = TRUE
       WHERE id = $1`,
      [b.spot_id]
    );

    // Create payment record (approved)
    await client.query(
      `INSERT INTO payments (user_ref, user_email, amount, hours, method, status, note, spot_id, approved_by, approved_at)
       VALUES ($1, $2, $3, $4, $5, 'approved', $6, $7, $8::uuid, NOW())`,
      [
        req.user.id, // user_ref (text)
        uq.rows[0].email,
        amount,
        hours,
        method,
        `booking:${b.id}`,
        String(b.spot_id),
        req.user.id, // approved_by (uuid)
      ]
    );

    const nb = await client.query(
      `SELECT wallet_balance FROM users WHERE id = $1`,
      [req.user.id]
    );
    await client.query("COMMIT");
    return res.json({
      ok: true,
      bookingId: b.id,
      hours,
      amount,
      balance: nb.rows[0].wallet_balance,
    });
  } catch (e) {
    await client.query("ROLLBACK");
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  } finally {
    client.release();
  }
});

// ---------- Admin (web) ----------
app.get("/admin/users", authMiddleware(true), requireAdmin, async (_req, res) => {
  const q = await pool.query(
    `SELECT id, email, name, is_admin, created_at
     FROM users
     ORDER BY created_at DESC`
  );
  res.json({ items: q.rows });
});

app.get("/admin/users/:id/details", authMiddleware(true), requireAdmin, async (req, res) => {
  const userId = String(req.params.id || "").trim();
  if (!userId) return res.status(400).json({ error: "user_required" });

  const u = await pool.query(
    `SELECT id, email, name, is_admin, created_at, wallet_balance
     FROM users WHERE id::text = $1`,
    [userId]
  );
  if (u.rows.length === 0) return res.status(404).json({ error: "not_found" });

  const cars = await pool.query(
    `SELECT id, name, plate, created_at
     FROM user_cars
     WHERE user_id = $1
     ORDER BY created_at DESC`,
    [u.rows[0].id]
  );

  const b = await pool.query(
    `SELECT id, spot_id, spot_name, price_per_hour, started_at, status, car_id, car_plate
     FROM bookings
     WHERE user_id = $1 AND status = 'active'
     ORDER BY started_at DESC
     LIMIT 1`,
    [u.rows[0].id]
  );

  let active = null;
  if (b.rows.length) {
    const row = b.rows[0];
    const hours = ceilHours(row.started_at);
    const amount = Math.max(1, Number(row.price_per_hour || 0) * hours);
    active = {
      ...row,
      hours,
      amount,
    };
  }

  res.json({
    user: u.rows[0],
    cars: cars.rows,
    activeBooking: active,
  });
});

app.post("/admin/spots", authMiddleware(true), requireAdmin, async (req, res) => {
  const lat = Number(req.body.lat);
  const lng = Number(req.body.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return res.status(400).json({ error: "invalid_lat_lng" });
  }
  const name = String(req.body.name || "Зогсоол").trim() || "Зогсоол";
  const pricePerHour = Number(req.body.price_per_hour) || 0;
  const totalNum = Number(req.body.total) || 0;
  const availRaw = Number(req.body.available);
  const availNum = Number.isFinite(availRaw) ? availRaw : totalNum;
  const ins = await pool.query(
    `INSERT INTO parking_spots (name, lat, lng, address, price_per_hour, total, available, status, is_available)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING *`,
    [
      name,
      lat,
      lng,
      req.body.address != null ? String(req.body.address) : null,
      pricePerHour,
      totalNum,
      availNum,
      req.body.status || "free",
      req.body.is_available !== false,
    ]
  );
  res.status(201).json(ins.rows[0]);
});

app.patch("/admin/spots/:id", authMiddleware(true), requireAdmin, async (req, res) => {
  const { id } = req.params;
  const fields = [];
  const vals = [];
  let i = 1;
  if (req.body.status != null) {
    fields.push(`status = $${i++}`); vals.push(String(req.body.status));
  }
  if (req.body.is_available != null) {
    fields.push(`is_available = $${i++}`); vals.push(!!req.body.is_available);
  }
  if (fields.length === 0) {
    return res.status(400).json({ error: "no_fields" });
  }
  vals.push(id);
  const q = await pool.query(
    `UPDATE parking_spots SET ${fields.join(", ")} WHERE id = $${i} RETURNING *`,
    vals
  );
  if (q.rows.length === 0) return res.status(404).json({ error: "not_found" });
  res.json(q.rows[0]);
});

app.delete("/admin/spots/:id", authMiddleware(true), requireAdmin, async (req, res) => {
  // IMPORTANT: don't hard-delete because existing bookings/payments may reference spot_id
  // (see bookings.spot_id ON DELETE RESTRICT). We "archive" the spot so it disappears
  // from /spots and cannot be booked anymore.
  const r = await pool.query(
    `UPDATE parking_spots
     SET status = 'deleted',
         is_available = FALSE,
         available = 0
     WHERE id = $1 AND status IS DISTINCT FROM 'deleted'`,
    [req.params.id]
  );
  if (r.rowCount === 0) return res.status(404).json({ error: "not_found" });
  res.json({ ok: true });
});

app.post("/payments", authMiddleware(false), async (req, res) => {
  const amount = Number(req.body.amount);
  if (!Number.isFinite(amount) || amount < 1) {
    return res.status(400).json({ error: "invalid_amount" });
  }
  const hours = Number(req.body.hours) || 1;
  const method = String(req.body.method || "unknown");
  const note = req.body.note != null ? String(req.body.note) : null;
  const spotId = req.body.spot_id != null ? String(req.body.spot_id) : "";
  let userRef = "guest";
  let userEmail = req.body.user_email != null ? String(req.body.user_email) : null;
  if (req.user) {
    userRef = req.user.id;
    if (!userEmail) {
      const u = await pool.query(`SELECT email FROM users WHERE id = $1`, [req.user.id]);
      userEmail = u.rows[0]?.email;
    }
  } else {
    userRef = `guest_${Date.now()}`;
    userEmail = userEmail || "";
  }
  // Захиалга үүсэх үед зогсоолын available-ийг 1-ээр бууруулна (spot_id байгаа үед).
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    if (spotId && spotId.trim()) {
      // Optimistic lock: only decrement if available > 0
      const up = await client.query(
        `UPDATE parking_spots
         SET available = GREATEST(available - 1, 0),
             is_available = (available - 1) > 0
         WHERE id::text = $1 AND available > 0
         RETURNING id, available, total`,
        [spotId.trim()]
      );
      if (up.rowCount === 0) {
        await client.query("ROLLBACK");
        return res.status(409).json({ error: "spot_full" });
      }
    }

    const ins = await client.query(
      `INSERT INTO payments (user_ref, user_email, amount, hours, method, status, note, spot_id)
       VALUES ($1, $2, $3, $4, $5, 'pending', $6, $7)
       RETURNING id, created_at`,
      [userRef, userEmail, amount, hours, method, note, spotId || null]
    );

    await client.query("COMMIT");
    return res.status(201).json(ins.rows[0]);
  } catch (e) {
    await client.query("ROLLBACK");
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  } finally {
    client.release();
  }
});

app.get("/admin/payments/pending", authMiddleware(true), requireAdmin, async (_req, res) => {
  const q = await pool.query(
    `SELECT * FROM payments WHERE status = 'pending' ORDER BY created_at DESC`
  );
  res.json({ items: q.rows });
});

app.get("/admin/payments", authMiddleware(true), requireAdmin, async (req, res) => {
  const status = req.query.status ? String(req.query.status) : "";
  if (status) {
    const q = await pool.query(
      `SELECT * FROM payments WHERE status = $1 ORDER BY created_at DESC`,
      [status]
    );
    return res.json({ items: q.rows });
  }
  const q = await pool.query(`SELECT * FROM payments ORDER BY created_at DESC`);
  return res.json({ items: q.rows });
});

app.patch("/admin/payments/:id", authMiddleware(true), requireAdmin, async (req, res) => {
  const action = String(req.body.action || "");
  if (action !== "approve" && action !== "reject") {
    return res.status(400).json({ error: "action_invalid" });
  }
  const status = action === "approve" ? "approved" : "rejected";
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const r = await client.query(
      `UPDATE payments
       SET status = $1, approved_by = $2, approved_at = NOW()
       WHERE id = $3 AND status = 'pending'
       RETURNING *`,
      [status, req.user.id, req.params.id]
    );
    if (r.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "not_found_or_not_pending" });
    }

    // Хэрвээ reject бол буцааж available+1 хийнэ (spot_id байгаа үед).
    const pay = r.rows[0];
    if (status === "rejected" && pay.spot_id) {
      await client.query(
        `UPDATE parking_spots
         SET available = LEAST(available + 1, COALESCE(total, available + 1)),
             is_available = TRUE
         WHERE id::text = $1`,
        [String(pay.spot_id)]
      );
    }

    await client.query("COMMIT");
    return res.json(pay);
  } catch (e) {
    await client.query("ROLLBACK");
    console.error(e);
    return res.status(500).json({ error: "server_error" });
  } finally {
    client.release();
  }
});

app.get("/admin/reports", authMiddleware(true), requireAdmin, async (req, res) => {
  const from = req.query.from ? new Date(req.query.from) : new Date(Date.now() - 7 * 864e5);
  const to = req.query.to ? new Date(req.query.to) : new Date();
  const q = await pool.query(
    `SELECT COUNT(*)::int AS count, COALESCE(SUM(amount),0)::int AS total_amount
     FROM payments
     WHERE status = 'approved' AND approved_at >= $1 AND approved_at <= $2`,
    [from, to]
  );
  res.json(q.rows[0]);
});

migrate()
  .then(seed)
  .then(() => {
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`mobile_bas2 API http://0.0.0.0:${PORT}`);
    });
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
