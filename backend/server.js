const express = require("express");
const { Client } = require("pg");
const cors = require("cors");

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// 🔹 Database configuration (Docker-friendly)
const client = new Client({
  host: process.env.DB_HOST || "db",   // container name
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD || "postgres",
  database: process.env.DB_NAME || "postgres",
  port: process.env.DB_PORT || 5432
});

// 🔹 Connect to DB
client.connect()
  .then(() => console.log("✅ Connected to PostgreSQL"))
  .catch(err => console.error("❌ DB connection failed:", err));

// 🔹 Health endpoint (used by Kubernetes later)
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "UP",
    service: "backend",
    timestamp: new Date()
  });
});

// 🔹 Root endpoint
app.get("/", (req, res) => {
  res.send("🚀 Backend is running");
});

// 🔹 API endpoint (DB query)
app.get("/api/db", async (req, res) => {
  try {
    const result = await client.query("SELECT NOW()");
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error("DB query error:", err);
    res.status(500).json({
      success: false,
      error: err.message
    });
  }
});

// 🔹 Example endpoint (optional - shows DB table data)
app.get("/api/test", async (req, res) => {
  try {
    const result = await client.query("SELECT * FROM test");
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err.message
    });
  }
});

// 🔹 Start server
app.listen(port, () => {
  console.log(`🚀 Backend running on port ${port}`);
});