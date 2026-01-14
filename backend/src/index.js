const express = require('express');
const cors = require('cors');
require('dotenv').config();

const pino = require('pino');
const pinoHttp = require('pino-http');

const userRoutes = require('./routes/userRoutes');
const subscriptionRoutes = require('./routes/subscriptionRoutes');
const classRoutes = require('./routes/classRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const authRoutes = require('./routes/authRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

/* =========================
   LOGGER CONFIG
========================= */
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: {
    pid: process.pid,
    hostname: process.env.HOSTNAME, // injecté par Docker
  },
});

/* =========================
   MIDDLEWARES
========================= */

// HTTP structured logs
app.use(
  pinoHttp({
    logger,
    customProps: (req) => ({
      method: req.method,
      url: req.url,
      instance: process.env.INSTANCE_ID || process.env.HOSTNAME,
    }),
    customLogLevel: function (res, err) {
      if (err || res.statusCode >= 500) return 'error';
      if (res.statusCode >= 400) return 'warn';
      return 'info';
    },
    customSuccessMessage: function (req, res) {
      return `${req.method} ${req.url} -> ${res.statusCode}`;
    },
  })
);

// CORS
app.use(
  cors({
    origin: process.env.FRONTEND_URL || 'http://localhost:8080',
    credentials: true,
  })
);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

/* =========================
   ROUTES
========================= */

app.use('/api/users', userRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/classes', classRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/auth', authRoutes);

/* =========================
   HEALTH / WHOAMI
========================= */

// Health check (CI + Traefik)
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
  });
});

// Scaling / load-balancing check
app.get('/whoami', (req, res) => {
  res.json({
    hostname: process.env.HOSTNAME,
    instance: process.env.INSTANCE_ID || null,
  });
});

/* =========================
   ERROR HANDLING
========================= */

// Error handler
app.use((err, req, res, next) => {
  req.log.error(
    {
      err: {
        message: err.message,
        stack: err.stack,
      },
    },
    'Unhandled error'
  );

  res.status(500).json({
    error: 'Something went wrong!',
    message:
      process.env.NODE_ENV === 'development'
        ? err.message
        : 'Internal server error',
  });
});

// 404 handler
app.use('*', (req, res) => {
  req.log.warn('Route not found');
  res.status(404).json({ error: 'Route not found' });
});

/* =========================
   SERVER START
========================= */

app.listen(PORT, () => {
  logger.info(
    {
      port: PORT,
      env: process.env.NODE_ENV || 'development',
    },
    'Server started'
  );
});
