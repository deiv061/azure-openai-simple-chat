/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  env: {
    CHAT_SERVICE_URL: process.env.CHAT_SERVICE_URL || 'http://localhost:8000',
    SESSION_SERVICE_URL: process.env.SESSION_SERVICE_URL || 'http://localhost:8001',
  },
}

module.exports = nextConfig
