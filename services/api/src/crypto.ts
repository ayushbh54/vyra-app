/**
 * =============================================================================
 * HEALTH-DATA ENCRYPTION
 * =============================================================================
 * Biometric values (heart rate, blood pressure, SpO2, glucose, weight) are
 * encrypted by this module before they reach Postgres, and decrypted only when
 * serving them back to their owner.
 *
 * Why not pgcrypto / Postgres-side encryption:
 *   pgcrypto would put the key inside the same trust boundary as the ciphertext.
 *   Anyone who dumps the database also gets the means to read it, which makes the
 *   encryption decorative. Here the key lives in a vault the database cannot see,
 *   so a stolen dump is genuinely useless on its own.
 *
 * Envelope format (a single BYTEA column):
 *
 *   ┌──────────┬────────────┬──────────────┬────────────────┐
 *   │ version  │ IV         │ auth tag     │ ciphertext     │
 *   │ 1 byte   │ 12 bytes   │ 16 bytes     │ n bytes        │
 *   └──────────┴────────────┴──────────────┴────────────────┘
 *
 * The leading version byte is what makes key rotation possible: old rows keep
 * decrypting with the old key while new writes use the new one. Without it, a
 * rotation would mean re-encrypting every row in one transaction, which is how
 * teams end up never rotating at all.
 *
 * AES-256-GCM is authenticated, so tampering with a stored row fails loudly on
 * decrypt rather than silently returning a wrong blood-pressure reading.
 *
 * AAD: every value is bound to its user id and field name. A ciphertext copied
 * from one user's glucose column into another user's row will not decrypt —
 * so a database-level swap cannot quietly mix up two people's health data.
 * =============================================================================
 */

import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
  scrypt as scryptCallback,
  timingSafeEqual,
} from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(scryptCallback);

const ALGO = 'aes-256-gcm';
const IV_BYTES = 12;
const TAG_BYTES = 16;
const KEY_BYTES = 32;

export class CryptoConfigError extends Error {}
export class DecryptionError extends Error {}

// -----------------------------------------------------------------------------
// Key ring
// -----------------------------------------------------------------------------

export interface KeyRing {
  /** Version written into every new envelope. */
  activeVersion: number;
  /** version -> 32-byte key. Old versions are retained so old rows still open. */
  keys: Map<number, Buffer>;
}

/**
 * Reads HEALTH_ENCRYPTION_KEY_V1, _V2, ... from the environment.
 * Fails at startup rather than at the first write — a server that boots without
 * a usable key would silently accept health data it cannot protect.
 */
export function loadKeyRing(env: NodeJS.ProcessEnv = process.env): KeyRing {
  const keys = new Map<number, Buffer>();

  for (const [name, value] of Object.entries(env)) {
    const match = /^HEALTH_ENCRYPTION_KEY_V(\d+)$/.exec(name);
    if (!match || !value) continue;

    const version = Number(match[1]);
    let key: Buffer;
    try {
      key = Buffer.from(value, 'base64');
    } catch {
      throw new CryptoConfigError(`${name} is not valid base64`);
    }
    if (key.length !== KEY_BYTES) {
      throw new CryptoConfigError(
        `${name} must decode to ${KEY_BYTES} bytes, got ${key.length}. Generate with: openssl rand -base64 32`,
      );
    }
    if (version < 1 || version > 255) {
      throw new CryptoConfigError(`${name}: key version must be between 1 and 255`);
    }
    keys.set(version, key);
  }

  if (keys.size === 0) {
    throw new CryptoConfigError(
      'No HEALTH_ENCRYPTION_KEY_V1 configured. Health features cannot start without it.',
    );
  }

  const activeVersion = Number(env.ACTIVE_KEY_VERSION ?? Math.max(...keys.keys()));
  if (!keys.has(activeVersion)) {
    throw new CryptoConfigError(
      `ACTIVE_KEY_VERSION=${activeVersion} has no matching HEALTH_ENCRYPTION_KEY_V${activeVersion}`,
    );
  }

  return { activeVersion, keys };
}

// -----------------------------------------------------------------------------
// Encrypt / decrypt
// -----------------------------------------------------------------------------

/** Binds a ciphertext to one user and one field. */
function aad(userId: string, field: string): Buffer {
  return Buffer.from(`${userId}:${field}`, 'utf8');
}

export function encryptValue(
  ring: KeyRing,
  plaintext: string | number,
  userId: string,
  field: string,
): Buffer {
  const key = ring.keys.get(ring.activeVersion);
  if (!key) throw new CryptoConfigError(`Active key v${ring.activeVersion} missing`);

  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv(ALGO, key, iv, { authTagLength: TAG_BYTES });
  cipher.setAAD(aad(userId, field));

  const body = Buffer.concat([
    cipher.update(String(plaintext), 'utf8'),
    cipher.final(),
  ]);

  return Buffer.concat([Buffer.from([ring.activeVersion]), iv, cipher.getAuthTag(), body]);
}

export function decryptValue(
  ring: KeyRing,
  envelope: Buffer,
  userId: string,
  field: string,
): string {
  if (envelope.length < 1 + IV_BYTES + TAG_BYTES) {
    throw new DecryptionError('Envelope is too short to be valid');
  }

  const version = envelope[0]!;
  const key = ring.keys.get(version);
  if (!key) {
    throw new DecryptionError(
      `No key for version ${version}. Retired keys must stay on the key ring until their rows are re-encrypted.`,
    );
  }

  const iv = envelope.subarray(1, 1 + IV_BYTES);
  const tag = envelope.subarray(1 + IV_BYTES, 1 + IV_BYTES + TAG_BYTES);
  const body = envelope.subarray(1 + IV_BYTES + TAG_BYTES);

  const decipher = createDecipheriv(ALGO, key, iv, { authTagLength: TAG_BYTES });
  decipher.setAAD(aad(userId, field));
  decipher.setAuthTag(tag);

  try {
    return Buffer.concat([decipher.update(body), decipher.final()]).toString('utf8');
  } catch {
    // Deliberately vague: never reveal whether the key, the AAD or the data was wrong.
    throw new DecryptionError('Could not decrypt this value');
  }
}

export function decryptNumber(
  ring: KeyRing,
  envelope: Buffer | null | undefined,
  userId: string,
  field: string,
): number | undefined {
  if (!envelope || envelope.length === 0) return undefined;
  const n = Number(decryptValue(ring, envelope, userId, field));
  return Number.isFinite(n) ? n : undefined;
}

export function encryptOptional(
  ring: KeyRing,
  value: number | undefined | null,
  userId: string,
  field: string,
): Buffer | null {
  if (value === undefined || value === null) return null;
  return encryptValue(ring, value, userId, field);
}

/** True when a row was written with a key older than the active one. */
export function needsReEncryption(ring: KeyRing, envelope: Buffer): boolean {
  return envelope.length > 0 && envelope[0] !== ring.activeVersion;
}

// -----------------------------------------------------------------------------
// Hashing — for values we must compare but never store
// -----------------------------------------------------------------------------

/**
 * Salted hash of an IP address, for the DPDP consent audit trail.
 *
 * We need to show that a consent came from somewhere, without retaining an
 * identifier that turns the audit log itself into personal data. The salt is a
 * separate secret, so a leaked database cannot be brute-forced back to IPs —
 * the IPv4 space is small enough that an unsalted hash is reversible in minutes.
 */
export function hashIp(ip: string, salt: string): string {
  if (!salt) throw new CryptoConfigError('IP_HASH_SALT is not set');
  return createHash('sha256').update(`${salt}:${ip}`).digest('hex');
}

/** Constant-time comparison for OTP codes and similar secrets. */
export function safeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}

/**
 * Password hashing — scrypt, node's built-in, rather than a dependency like
 * bcrypt/argon2. scrypt is memory-hard (same family of protection argon2
 * gives), and using the standard library here means one fewer native addon
 * that has to compile cleanly on whatever machine is building this.
 *
 * Format stored: `scrypt:<saltHex>:<hashHex>` — self-describing, so the
 * algorithm can be upgraded later without a separate "version" column.
 */
const SCRYPT_KEYLEN = 64;

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const derived = (await scrypt(password, salt, SCRYPT_KEYLEN)) as Buffer;
  return `scrypt:${salt.toString('hex')}:${derived.toString('hex')}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const parts = stored.split(':');
  if (parts.length !== 3 || parts[0] !== 'scrypt') return false;
  const [, saltHex, hashHex] = parts as [string, string, string];
  const salt = Buffer.from(saltHex, 'hex');
  const expected = Buffer.from(hashHex, 'hex');
  const derived = (await scrypt(password, salt, expected.length)) as Buffer;
  if (derived.length !== expected.length) return false;
  return timingSafeEqual(derived, expected);
}
