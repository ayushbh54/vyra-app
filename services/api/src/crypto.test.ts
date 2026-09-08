/**
 * Health-data encryption tests.
 *
 * The threat model these defend against: someone obtains a copy of the database.
 * Everything below asserts that a dump alone is not enough to read, forge, or
 * shuffle a person's health data.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';

import {
  CryptoConfigError,
  DecryptionError,
  decryptNumber,
  decryptValue,
  encryptOptional,
  encryptValue,
  hashIp,
  loadKeyRing,
  needsReEncryption,
  safeEqual,
} from './crypto';

const K1 = randomBytes(32).toString('base64');
const K2 = randomBytes(32).toString('base64');

const ring1 = loadKeyRing({ HEALTH_ENCRYPTION_KEY_V1: K1, ACTIVE_KEY_VERSION: '1' } as NodeJS.ProcessEnv);
const ring2 = loadKeyRing({
  HEALTH_ENCRYPTION_KEY_V1: K1,
  HEALTH_ENCRYPTION_KEY_V2: K2,
  ACTIVE_KEY_VERSION: '2',
} as NodeJS.ProcessEnv);

const USER = 'user-abc';
const OTHER = 'user-xyz';

describe('configuration', () => {
  it('refuses to start without a key', () => {
    assert.throws(() => loadKeyRing({} as NodeJS.ProcessEnv), CryptoConfigError);
  });

  it('rejects a key of the wrong length, with the fix in the message', () => {
    assert.throws(
      () => loadKeyRing({ HEALTH_ENCRYPTION_KEY_V1: Buffer.from('short').toString('base64') } as NodeJS.ProcessEnv),
      /openssl rand -base64 32/,
    );
  });

  it('rejects an active version that has no key', () => {
    assert.throws(
      () => loadKeyRing({ HEALTH_ENCRYPTION_KEY_V1: K1, ACTIVE_KEY_VERSION: '9' } as NodeJS.ProcessEnv),
      /no matching HEALTH_ENCRYPTION_KEY_V9/,
    );
  });

  it('defaults to the highest configured version', () => {
    const r = loadKeyRing({ HEALTH_ENCRYPTION_KEY_V1: K1, HEALTH_ENCRYPTION_KEY_V2: K2 } as NodeJS.ProcessEnv);
    assert.equal(r.activeVersion, 2);
  });
});

describe('round trip', () => {
  it('recovers the original value', () => {
    const env = encryptValue(ring1, 128, USER, 'glucose');
    assert.equal(decryptValue(ring1, env, USER, 'glucose'), '128');
  });

  it('recovers numbers as numbers', () => {
    const env = encryptValue(ring1, 72.5, USER, 'weight');
    assert.equal(decryptNumber(ring1, env, USER, 'weight'), 72.5);
  });

  it('treats a missing value as undefined rather than throwing', () => {
    assert.equal(decryptNumber(ring1, null, USER, 'weight'), undefined);
    assert.equal(encryptOptional(ring1, undefined, USER, 'weight'), null);
  });

  it('produces different ciphertext each time for the same input', () => {
    // A deterministic ciphertext would leak that two readings were identical,
    // which is enough to reconstruct a weight trend without decrypting anything.
    const a = encryptValue(ring1, 120, USER, 'bp_systolic');
    const b = encryptValue(ring1, 120, USER, 'bp_systolic');
    assert.notEqual(a.toString('hex'), b.toString('hex'));
  });

  it('never contains the plaintext', () => {
    const env = encryptValue(ring1, 98765, USER, 'glucose');
    assert.ok(!env.toString('utf8').includes('98765'));
    assert.ok(!env.toString('hex').includes(Buffer.from('98765').toString('hex')));
  });
});

describe('binding to user and field', () => {
  /**
   * Guards against a row-level swap: moving a ciphertext between users or
   * between columns must fail, not silently mislabel someone's health data.
   */
  it('refuses to decrypt another user ciphertext', () => {
    const env = encryptValue(ring1, 140, USER, 'glucose');
    assert.throws(() => decryptValue(ring1, env, OTHER, 'glucose'), DecryptionError);
  });

  it('refuses to decrypt into a different field', () => {
    const env = encryptValue(ring1, 140, USER, 'glucose');
    assert.throws(() => decryptValue(ring1, env, USER, 'spo2'), DecryptionError);
  });
});

describe('tamper resistance', () => {
  it('detects a modified ciphertext', () => {
    const env = encryptValue(ring1, 120, USER, 'bp_systolic');
    env[env.length - 1]! ^= 0xff;
    assert.throws(() => decryptValue(ring1, env, USER, 'bp_systolic'), DecryptionError);
  });

  it('detects a modified auth tag', () => {
    const env = encryptValue(ring1, 120, USER, 'bp_systolic');
    env[14]! ^= 0x01;
    assert.throws(() => decryptValue(ring1, env, USER, 'bp_systolic'), DecryptionError);
  });

  it('rejects a truncated envelope', () => {
    const env = encryptValue(ring1, 120, USER, 'bp_systolic');
    assert.throws(() => decryptValue(ring1, env.subarray(0, 10), USER, 'bp_systolic'), /too short/);
  });

  it('does not reveal why decryption failed', () => {
    const env = encryptValue(ring1, 120, USER, 'bp_systolic');
    try {
      decryptValue(ring1, env, OTHER, 'bp_systolic');
      assert.fail('should have thrown');
    } catch (e) {
      // No mention of keys, AAD, or which check failed.
      assert.equal((e as Error).message, 'Could not decrypt this value');
    }
  });
});

describe('key rotation', () => {
  it('still reads rows written with an older key', () => {
    const old = encryptValue(ring1, 15, USER, 'spo2');   // written under v1
    assert.equal(decryptValue(ring2, old, USER, 'spo2'), '15');
  });

  it('writes new rows with the active key', () => {
    const fresh = encryptValue(ring2, 99, USER, 'spo2');
    assert.equal(fresh[0], 2);
  });

  it('flags old rows for background re-encryption', () => {
    assert.equal(needsReEncryption(ring2, encryptValue(ring1, 1, USER, 'spo2')), true);
    assert.equal(needsReEncryption(ring2, encryptValue(ring2, 1, USER, 'spo2')), false);
  });

  it('explains clearly when a retired key was dropped too early', () => {
    const old = encryptValue(ring1, 15, USER, 'spo2');
    const onlyV2 = loadKeyRing({ HEALTH_ENCRYPTION_KEY_V2: K2, ACTIVE_KEY_VERSION: '2' } as NodeJS.ProcessEnv);
    assert.throws(() => decryptValue(onlyV2, old, USER, 'spo2'), /must stay on the key ring/);
  });
});

describe('IP hashing', () => {
  it('is stable for the same input', () => {
    assert.equal(hashIp('49.36.1.2', 'salt'), hashIp('49.36.1.2', 'salt'));
  });

  it('changes completely with the salt, so a leaked DB cannot be brute-forced', () => {
    assert.notEqual(hashIp('49.36.1.2', 'salt-a'), hashIp('49.36.1.2', 'salt-b'));
  });

  it('never contains the original address', () => {
    assert.ok(!hashIp('49.36.1.2', 'salt').includes('49'));
  });

  it('refuses to run without a salt', () => {
    assert.throws(() => hashIp('49.36.1.2', ''), CryptoConfigError);
  });
});

describe('constant-time comparison', () => {
  it('matches identical strings', () => {
    assert.equal(safeEqual('482913', '482913'), true);
  });

  it('rejects different strings', () => {
    assert.equal(safeEqual('482913', '482914'), false);
  });

  it('handles a length mismatch without throwing', () => {
    assert.equal(safeEqual('4829', '482913'), false);
  });
});
