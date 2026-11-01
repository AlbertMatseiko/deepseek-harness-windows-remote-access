'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const host = process.env.DSH_LATEST_HOST;
const port = Number(process.env.DSH_LATEST_PORT || 3090);
const dshHome = process.env.DSH_HOME || path.join(process.env.USERPROFILE || process.env.HOME || '.', '.dsh');
const authFile = process.env.DSH_LATEST_AUTH || path.join(dshHome, 'latest-auth.json');
const urlFile = process.env.DSH_LATEST_URL || path.join(dshHome, 'latest-url.txt');

function fail(message) {
  console.error(message);
  process.exit(1);
}

if (!host) {
  fail('DSH_LATEST_HOST is required (set it to your Tailscale DNS name).');
}

let auth;
try {
  auth = JSON.parse(fs.readFileSync(authFile, 'utf8'));
}
catch (error) {
  fail(`Cannot read auth file ${authFile}: ${error.message}`);
}

if (!auth.user || !auth.salt || !/^[0-9a-f]{64}$/.test(auth.hash || '')) {
  fail(`Invalid auth file ${authFile}`);
}

const expectedHash = Buffer.from(auth.hash, 'hex');

function authorized(header) {
  if (typeof header !== 'string' || !header.startsWith('Basic ')) return false;

  let decoded;
  try {
    decoded = Buffer.from(header.slice(6).trim(), 'base64').toString('utf8');
  }
  catch {
    return false;
  }

  const separator = decoded.indexOf(':');
  if (separator < 0) return false;

  const user = decoded.slice(0, separator);
  const password = decoded.slice(separator + 1);
  if (user !== auth.user) return false;

  const digest = crypto
    .createHash('sha256')
    .update(`${auth.salt}:${user}:${password}`, 'utf8')
    .digest();

  return digest.length === expectedHash.length && crypto.timingSafeEqual(digest, expectedHash);
}

function latestUrl() {
  const raw = fs.readFileSync(urlFile, 'utf8').trim();
  const url = new URL(raw);

  if (url.protocol !== 'https:' || url.hostname !== host) {
    throw new Error('unexpected URL host');
  }
  if (!url.searchParams.has('token')) {
    throw new Error('missing token');
  }

  return url.toString();
}

const server = http.createServer((req, res) => {
  // Tailscale may forward /latest or /latest/; accept / as well if it strips the mount.
  const pathname = (req.url || '').split('?', 1)[0];
  if (pathname !== '/' && pathname !== '/latest' && pathname !== '/latest/') {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('not found');
    return;
  }

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD' });
    res.end();
    return;
  }

  if (!authorized(req.headers.authorization)) {
    res.writeHead(401, {
      'WWW-Authenticate': 'Basic realm="DSH latest", charset="UTF-8"',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end('authentication required');
    return;
  }

  let target;
  try {
    target = latestUrl();
  }
  catch {
    res.writeHead(503, {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end('DSH is not ready');
    return;
  }

  res.writeHead(302, {
    Location: target,
    'Cache-Control': 'no-store',
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
  });
  res.end();
});

server.requestTimeout = 10_000;
server.listen(port, '127.0.0.1', () => {
  console.log(`DSH latest redirect listening on http://127.0.0.1:${port}/latest for ${host}`);
});
