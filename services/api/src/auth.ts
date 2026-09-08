/**
 * =============================================================================
 * AUTHENTICATION — HS256 JWT, hand-rolled on node:crypto
 * =============================================================================
 * Why not a JWT library: the signing and verification here is about sixty lines
 * of well-understood code, and JWT libraries have a long history of CVEs caused
 * by exactly the flexibility we do not want (the `alg: none` family of attacks,
 * algorithm confusion between HMAC and RSA). This implementation accepts one
 * algorithm and rejects everything else, which removes that class of bug.
 *
 * Design decisions worth defending:
 *   - Short-lived access token (15 min), long-lived refresh token (30 days).
 *     A leaked access token expires before it is useful; refresh tokens are
 *     stored server-side so they can be revoked.
 *   - Constant-time signature comparison, so a timing attack cannot recover a
 *     valid signature byte by byte.
 *   - The token carries only a user id and a token type. No email, no name, no
 *     health data — a JWT is signed, not encrypted, and anyone holding it can
 *     read its contents.
 * =============================================================================
 */

import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { HttpError } from './http/router';

export interface TokenPayload {
  sub: string;                 // user id
  typ: 'access' | 'refresh';
  iat: number;
  exp: number;
  /** Ties a refresh token to one device so a stolen one is easier to spot. */
  did?: string;
  /** Set only on tokens issued to an admin_users row — a completely separate
   * credential space from athlete accounts (see store.ts StoredAdmin). */
  admin?: boolean;
}

const b64url = (buf: Buffer): string =>
  buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

const b64urlDecode = (s: string): Buffer =>
  Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64');

export interface AuthConfig {
  secret: string;
  accessTtlSec: number;
  refreshTtlSec: number;
}

export function loadAuthConfig(env: NodeJS.ProcessEnv = process.env): AuthConfig {
  const secret = env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error(
      'JWT_SECRET must be set and at least 32 characters. Generate with: openssl rand -base64 48',
    );
  }
  return {
    secret,
    accessTtlSec: Number(env.JWT_ACCESS_TTL ?? 900),
    refreshTtlSec: Number(env.JWT_REFRESH_TTL ?? 2_592_000),
  };
}

function sign(input: string, secret: string): string {
  return b64url(createHmac('sha256', secret).update(input).digest());
}

export function issueToken(
  cfg: AuthConfig,
  userId: string,
  typ: 'access' | 'refresh',
  nowMs: number,
  deviceId?: string,
  isAdmin?: boolean,
): string {
  const iat = Math.floor(nowMs / 1000);
  const exp = iat + (typ === 'access' ? cfg.accessTtlSec : cfg.refreshTtlSec);

  const header = b64url(Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const payload = b64url(
    Buffer.from(JSON.stringify({
      sub: userId, typ, iat, exp,
      ...(deviceId ? { did: deviceId } : {}),
      ...(isAdmin ? { admin: true } : {}),
    })),
  );
  return `${header}.${payload}.${sign(`${header}.${payload}`, cfg.secret)}`;
}

export function verifyToken(cfg: AuthConfig, token: string, nowMs: number): TokenPayload {
  const parts = token.split('.');
  if (parts.length !== 3) throw HttpError.unauthorized('Malformed token.');

  const [headerB64, payloadB64, signatureB64] = parts as [string, string, string];

  // Reject anything that is not exactly HS256 before doing any other work.
  let header: { alg?: string };
  try {
    header = JSON.parse(b64urlDecode(headerB64).toString('utf8'));
  } catch {
    throw HttpError.unauthorized('Malformed token.');
  }
  if (header.alg !== 'HS256') {
    throw HttpError.unauthorized('Unsupported token algorithm.');
  }

  const expected = sign(`${headerB64}.${payloadB64}`, cfg.secret);
  const a = Buffer.from(expected);
  const b = Buffer.from(signatureB64);
  if (a.length !== b.length || !timingSafeEqual(a, b)) {
    throw HttpError.unauthorized('Invalid token signature.');
  }

  let payload: TokenPayload;
  try {
    payload = JSON.parse(b64urlDecode(payloadB64).toString('utf8'));
  } catch {
    throw HttpError.unauthorized('Malformed token.');
  }

  if (typeof payload.sub !== 'string' || !payload.exp) {
    throw HttpError.unauthorized('Malformed token.');
  }
  if (payload.exp * 1000 <= nowMs) {
    throw HttpError.unauthorized('Your session has expired. Please sign in again.');
  }

  return payload;
}

export function newOpaqueToken(): string {
  return randomBytes(32).toString('base64url');
}

/**
 * Six-digit OTP from a cryptographically secure source.
 *
 * Math.random() is predictable enough that an attacker who sees a few codes can
 * predict the next one. For anything that grants account access, it must not be
 * used — this is a common and serious mistake.
 */
export function generateOtp(): string {
  return String(randomBytes(4).readUInt32BE(0) % 1_000_000).padStart(6, '0');
}
