/**
 * =============================================================================
 * POSTGRES STORE
 * =============================================================================
 * The production implementation of `Store`. Selected automatically whenever
 * DATABASE_URL is set; otherwise the API falls back to MemoryStore.
 *
 * Why every query lives in this one file:
 *   - SQL scattered through route handlers is impossible to audit. Here, the
 *     complete set of statements that touch a user's health data is one file
 *     long, which is what makes a privacy review feasible.
 *   - Every statement is parameterised. There is no string concatenation of
 *     user input anywhere in this file, which is the whole of SQL injection
 *     defence.
 *
 * The `pg` driver is imported lazily so the package is only required when a
 * database is actually configured — the demo path stays dependency-free.
 * =============================================================================
 */

import type { ISODate } from '@vyra/types';
import type { RawBlock } from './domain/chrono';
import type { LedgerRow, CoinSource } from './domain/coins';
import { MOVEMENT_DEFINITIONS } from './content/movements';
import type {
  AccountStatus, AuditEntry, BeaconContact, DmPrivacy, MovementDefinition, ReportReason,
  ReportStatus, ReportTargetType, Store, StoredActivity, StoredAdmin, StoredClub, StoredClubPost,
  StoredChatMessage, StoredComment, StoredConversation, StoredEvent, StoredMessage, StoredPlan,
  StoredReport, StoredTracking, StoredUser,
} from './store';

// Minimal structural types for `pg`, so this file compiles without the package
// installed. The real driver satisfies these.
interface QueryResult<T> { rows: T[]; rowCount: number | null }
interface PoolClient {
  query<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<QueryResult<T>>;
  release(): void;
}
interface Pool {
  query<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<QueryResult<T>>;
  connect(): Promise<PoolClient>;
  end(): Promise<void>;
}

export class PgStore implements Store {
  private constructor(private readonly pool: Pool) {}

  /**
   * Builds a pool, or throws with a message that says how to fix it.
   *
   * Pool sizing matters on free tiers: Supabase's direct connection allows very
   * few clients, so we default to a small pool and expect the pooler URI
   * (port 6543). A pool larger than the server allows fails at peak load, which
   * is exactly when a demo is being watched.
   */
  static async create(databaseUrl: string): Promise<PgStore> {
    let pg: { Pool: new (config: Record<string, unknown>) => Pool };
    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      pg = require('pg') as { Pool: new (config: Record<string, unknown>) => Pool };
    } catch {
      throw new Error(
        'DATABASE_URL is set but the "pg" package is not installed. Run: pnpm --filter @vyra/api add pg',
      );
    }

    const pool = new pg.Pool({
      connectionString: databaseUrl,
      max: Number(process.env.PG_POOL_MAX ?? 8),
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 10_000,
      // Managed Postgres (Supabase, RDS) terminates TLS with its own CA chain.
      ssl: databaseUrl.includes('localhost') ? false : { rejectUnauthorized: false },
    });

    // Fail at boot rather than on the first user request.
    await pool.query('SELECT 1');
    return new PgStore(pool);
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  async createUser(u: Omit<StoredUser, 'createdAt'>): Promise<StoredUser> {
    const { rows } = await this.pool.query<Record<string, unknown>>(
      `INSERT INTO users (
         id, display_handle, name, email, dob, gender, height_cm, weight_kg,
         disability_flag, accessibility_mode, fitness_goal, diet_toggle,
         diet_preference, city, primary_sport, dm_privacy, account_status, onboarding_step
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
       RETURNING *`,
      [
        u.id, u.displayHandle, u.name, u.email ?? null, u.dob, u.gender,
        u.heightCm, u.weightKg, u.disabilityFlag, u.accessibilityMode,
        u.fitnessGoal, u.dietToggle, u.dietPreference, u.city ?? null,
        u.primarySport, u.dmPrivacy, u.accountStatus, u.onboardingStep,
      ],
    );
    return this.mapUser(rows[0]!);
  }

  async getUser(id: string): Promise<StoredUser | null> {
    const { rows } = await this.pool.query(
      `SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL`,
      [id],
    );
    return rows[0] ? this.mapUser(rows[0]) : null;
  }

  async updateUser(id: string, patch: Partial<StoredUser>): Promise<StoredUser> {
    // Column names come from this fixed map, never from the caller — a patch
    // key can therefore never become part of the SQL text.
    const columns: Record<string, string> = {
      name: 'name', email: 'email', heightCm: 'height_cm', weightKg: 'weight_kg',
      accessibilityMode: 'accessibility_mode', fitnessGoal: 'fitness_goal',
      dietToggle: 'diet_toggle', dietPreference: 'diet_preference',
      city: 'city', onboardingStep: 'onboarding_step',
      displayHandle: 'display_handle', primarySport: 'primary_sport',
      dmPrivacy: 'dm_privacy',
      accountStatus: 'account_status',
      dob: 'dob', gender: 'gender', disabilityFlag: 'disability_flag',
    };

    const sets: string[] = [];
    const params: unknown[] = [id];
    for (const [key, value] of Object.entries(patch)) {
      const column = columns[key];
      if (!column) continue;
      params.push(value);
      sets.push(`${column} = $${params.length}`);
    }
    if (sets.length === 0) {
      const existing = await this.getUser(id);
      if (!existing) throw new Error(`User ${id} not found`);
      return existing;
    }

    const { rows } = await this.pool.query(
      `UPDATE users SET ${sets.join(', ')} WHERE id = $1 RETURNING *`,
      params,
    );
    if (!rows[0]) throw new Error(`User ${id} not found`);
    return this.mapUser(rows[0]);
  }

  private mapUser(r: Record<string, unknown>): StoredUser {
    return {
      id: String(r.id),
      displayHandle: String(r.display_handle),
      name: String(r.name),
      email: r.email ? String(r.email) : undefined,
      dob: this.toDate(r.dob),
      gender: r.gender as StoredUser['gender'],
      heightCm: Number(r.height_cm),
      weightKg: Number(r.weight_kg),
      disabilityFlag: Boolean(r.disability_flag),
      accessibilityMode: Boolean(r.accessibility_mode),
      fitnessGoal: r.fitness_goal as StoredUser['fitnessGoal'],
      dietToggle: Boolean(r.diet_toggle),
      dietPreference: r.diet_preference as StoredUser['dietPreference'],
      city: r.city ? String(r.city) : undefined,
      primarySport: String(r.primary_sport ?? 'run'),
      dmPrivacy: (r.dm_privacy as DmPrivacy) ?? 'following',
      accountStatus: (r.account_status as AccountStatus) ?? 'active',
      onboardingStep: Number(r.onboarding_step),
      createdAt: this.toIso(r.signup_date),
    };
  }

  /** Postgres DATE comes back as a JS Date in local time; we want the calendar day. */
  private toDate(v: unknown): ISODate {
    if (v instanceof Date) {
      return `${v.getFullYear()}-${String(v.getMonth() + 1).padStart(2, '0')}-${String(v.getDate()).padStart(2, '0')}`;
    }
    return String(v).slice(0, 10);
  }

  private toIso(v: unknown): string {
    return v instanceof Date ? v.toISOString() : String(v);
  }

  // ---------------------------------------------------------------------------
  // Schedule
  // ---------------------------------------------------------------------------

  async setSchedule(userId: string, blocks: RawBlock[]): Promise<void> {
    const client = await this.pool.connect();
    try {
      // Replace-all in one transaction. A partial write here would leave the
      // Chrono Engine reading half of yesterday's timetable and half of today's.
      await client.query('BEGIN');
      await client.query('DELETE FROM schedule_blocks WHERE user_id = $1', [userId]);

      for (const b of blocks) {
        await client.query(
          `INSERT INTO schedule_blocks (user_id, weekday, block_start, block_end, block_type, label)
           VALUES ($1,$2,$3,$4,$5,$6)`,
          [userId, b.weekday, b.blockStart, b.blockEnd, b.blockType, b.label ?? null],
        );
      }
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async getSchedule(userId: string): Promise<RawBlock[]> {
    const { rows } = await this.pool.query(
      `SELECT weekday, block_start, block_end, block_type, label
         FROM schedule_blocks WHERE user_id = $1 ORDER BY weekday, block_start`,
      [userId],
    );
    return rows.map((r) => ({
      weekday: Number(r.weekday),
      // TIME comes back as 'HH:MM:SS'; the engine wants 'HH:MM'.
      blockStart: String(r.block_start).slice(0, 5),
      blockEnd: String(r.block_end).slice(0, 5),
      blockType: r.block_type as RawBlock['blockType'],
      label: r.label ? String(r.label) : undefined,
    }));
  }

  // ---------------------------------------------------------------------------
  // Plans
  // ---------------------------------------------------------------------------

  async upsertPlan(plan: StoredPlan): Promise<StoredPlan> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const { rows } = await client.query<{ id: string }>(
        `INSERT INTO workout_plans (user_id, plan_date, status, generated_by)
           VALUES ($1,$2,$3,'chrono_engine_v1')
         ON CONFLICT (user_id, plan_date) DO UPDATE SET status = EXCLUDED.status
         RETURNING id`,
        [plan.userId, plan.planDate, plan.goalMin === 0 ? 'rest' : 'pending'],
      );
      const planId = rows[0]!.id;

      // Entries are rewritten wholesale, but completion state is carried over by
      // the caller (buildPlanFor), so a replan never erases finished work.
      await client.query('DELETE FROM workout_plan_entries WHERE plan_id = $1', [planId]);

      for (const [i, e] of plan.entries.entries()) {
        await client.query(
          `INSERT INTO workout_plan_entries
             (plan_id, exercise_id, position, duration_sec, is_completed, completed_at)
           SELECT $1, ex.id, $2, $3, $4, $5 FROM exercises ex WHERE ex.slug = $6`,
          [planId, i, e.durationSec, e.isCompleted, e.isCompleted ? new Date() : null, e.exerciseSlug],
        );
      }

      await client.query('COMMIT');
      return plan;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async getPlan(userId: string, date: ISODate): Promise<StoredPlan | null> {
    const { rows } = await this.pool.query(
      `SELECT p.plan_date, p.status,
              e.slug, e.name, pe.duration_sec, pe.is_completed, pe.position
         FROM workout_plans p
         LEFT JOIN workout_plan_entries pe ON pe.plan_id = p.id
         LEFT JOIN exercises e ON e.id = pe.exercise_id
        WHERE p.user_id = $1 AND p.plan_date = $2
        ORDER BY pe.position`,
      [userId, date],
    );
    if (rows.length === 0) return null;

    const entries = rows
      .filter((r) => r.slug)
      .map((r) => ({
        exerciseSlug: String(r.slug),
        name: String(r.name),
        durationSec: Number(r.duration_sec),
        isCompleted: Boolean(r.is_completed),
      }));

    const achievedMin = entries
      .filter((e) => e.isCompleted)
      .reduce((sum, e) => sum + e.durationSec / 60, 0);

    return {
      userId,
      planDate: date,
      // goalMin and capacityMin are recomputed by the Chrono Engine on read
      // rather than stored, so an edited schedule takes effect immediately
      // instead of leaving a stale goal in the database.
      goalMin: 0,
      capacityMin: 0,
      achievedMin: Math.round(achievedMin * 10) / 10,
      entries,
    };
  }

  async listPlans(userId: string, from: ISODate, to: ISODate): Promise<StoredPlan[]> {
    const { rows } = await this.pool.query<{ plan_date: unknown }>(
      `SELECT plan_date FROM workout_plans
        WHERE user_id = $1 AND plan_date BETWEEN $2 AND $3
        ORDER BY plan_date`,
      [userId, from, to],
    );

    const plans: StoredPlan[] = [];
    for (const r of rows) {
      const plan = await this.getPlan(userId, this.toDate(r.plan_date));
      if (plan) plans.push(plan);
    }
    return plans;
  }

  // ---------------------------------------------------------------------------
  // Tracking — the encrypted path
  // ---------------------------------------------------------------------------

  async upsertTracking(rec: StoredTracking): Promise<StoredTracking> {
    // COALESCE on every column so a partial update merges rather than wipes:
    // logging water at noon must not erase this morning's weight entry.
    await this.pool.query(
      `INSERT INTO tracking_records (
         user_id, record_date, water_ml, steps,
         heart_rate_enc, bp_systolic_enc, bp_diastolic_enc,
         spo2_enc, glucose_enc, weight_enc, key_version, source
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       ON CONFLICT (user_id, record_date) DO UPDATE SET
         water_ml         = COALESCE(EXCLUDED.water_ml, tracking_records.water_ml),
         steps            = COALESCE(EXCLUDED.steps, tracking_records.steps),
         heart_rate_enc   = COALESCE(EXCLUDED.heart_rate_enc, tracking_records.heart_rate_enc),
         bp_systolic_enc  = COALESCE(EXCLUDED.bp_systolic_enc, tracking_records.bp_systolic_enc),
         bp_diastolic_enc = COALESCE(EXCLUDED.bp_diastolic_enc, tracking_records.bp_diastolic_enc),
         spo2_enc         = COALESCE(EXCLUDED.spo2_enc, tracking_records.spo2_enc),
         glucose_enc      = COALESCE(EXCLUDED.glucose_enc, tracking_records.glucose_enc),
         weight_enc       = COALESCE(EXCLUDED.weight_enc, tracking_records.weight_enc),
         updated_at       = now()`,
      [
        rec.userId, rec.recordDate, rec.waterMl ?? null, rec.steps ?? null,
        rec.encrypted.heartRateBpm ?? null,
        rec.encrypted.bpSystolic ?? null,
        rec.encrypted.bpDiastolic ?? null,
        rec.encrypted.spo2 ?? null,
        rec.encrypted.glucoseMgDl ?? null,
        rec.encrypted.weightKg ?? null,
        Number(process.env.ACTIVE_KEY_VERSION ?? 1),
        rec.source,
      ],
    );
    const saved = await this.getTracking(rec.userId, rec.recordDate);
    return saved ?? rec;
  }

  async getTracking(userId: string, date: ISODate): Promise<StoredTracking | null> {
    const { rows } = await this.pool.query(
      `SELECT * FROM tracking_records WHERE user_id = $1 AND record_date = $2`,
      [userId, date],
    );
    return rows[0] ? this.mapTracking(rows[0]) : null;
  }

  async listTracking(userId: string, from: ISODate, to: ISODate): Promise<StoredTracking[]> {
    const { rows } = await this.pool.query(
      `SELECT * FROM tracking_records
        WHERE user_id = $1 AND record_date BETWEEN $2 AND $3
        ORDER BY record_date`,
      [userId, from, to],
    );
    return rows.map((r) => this.mapTracking(r));
  }

  private mapTracking(r: Record<string, unknown>): StoredTracking {
    const encrypted: Record<string, Buffer> = {};
    const columns: Array<[string, string]> = [
      ['heart_rate_enc', 'heartRateBpm'],
      ['bp_systolic_enc', 'bpSystolic'],
      ['bp_diastolic_enc', 'bpDiastolic'],
      ['spo2_enc', 'spo2'],
      ['glucose_enc', 'glucoseMgDl'],
      ['weight_enc', 'weightKg'],
    ];
    for (const [column, field] of columns) {
      const value = r[column];
      if (Buffer.isBuffer(value) && value.length > 0) encrypted[field] = value;
    }

    return {
      userId: String(r.user_id),
      recordDate: this.toDate(r.record_date),
      waterMl: r.water_ml === null ? undefined : Number(r.water_ml),
      steps: r.steps === null ? undefined : Number(r.steps),
      encrypted,
      source: String(r.source),
    };
  }

  // ---------------------------------------------------------------------------
  // Sugar
  // ---------------------------------------------------------------------------

  async setSugar(userId: string, date: ISODate, grams: number): Promise<void> {
    await this.pool.query(
      `INSERT INTO sugar_logs (user_id, log_date, sugar_grams) VALUES ($1,$2,$3)
       ON CONFLICT (user_id, log_date) DO UPDATE SET sugar_grams = EXCLUDED.sugar_grams`,
      [userId, date, grams],
    );
  }

  async getSugar(userId: string, date: ISODate): Promise<number | null> {
    const { rows } = await this.pool.query<{ sugar_grams: string }>(
      `SELECT sugar_grams FROM sugar_logs WHERE user_id = $1 AND log_date = $2`,
      [userId, date],
    );
    return rows[0] ? Number(rows[0].sugar_grams) : null;
  }

  async listSugar(userId: string, from: ISODate, to: ISODate) {
    const { rows } = await this.pool.query(
      `SELECT log_date, sugar_grams FROM sugar_logs
        WHERE user_id = $1 AND log_date BETWEEN $2 AND $3 ORDER BY log_date`,
      [userId, from, to],
    );
    return rows.map((r) => ({ date: this.toDate(r.log_date), grams: Number(r.sugar_grams) }));
  }

  // ---------------------------------------------------------------------------
  // Coin ledger — append-only
  // ---------------------------------------------------------------------------

  async appendLedger(userId: string, row: LedgerRow): Promise<void> {
    // ON CONFLICT DO NOTHING on the idempotency key is the database-level
    // backstop for double-award: even if two requests race past the in-memory
    // check, only one row can exist.
    await this.pool.query(
      `INSERT INTO coin_ledger (user_id, delta, reason, source_type, idempotency_key)
         VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (idempotency_key) DO NOTHING`,
      [userId, row.delta, row.reason, row.sourceType, row.idempotencyKey ?? null],
    );
  }

  async listLedger(userId: string): Promise<LedgerRow[]> {
    const { rows } = await this.pool.query(
      `SELECT delta, reason, source_type, idempotency_key, created_at
         FROM coin_ledger WHERE user_id = $1 ORDER BY created_at`,
      [userId],
    );
    return rows.map((r) => this.mapLedger(r));
  }

  async listLedgerForDate(userId: string, date: ISODate): Promise<LedgerRow[]> {
    const { rows } = await this.pool.query(
      `SELECT delta, reason, source_type, idempotency_key, created_at
         FROM coin_ledger
        WHERE user_id = $1 AND created_at::date = $2::date
        ORDER BY created_at`,
      [userId, date],
    );
    return rows.map((r) => this.mapLedger(r));
  }

  private mapLedger(r: Record<string, unknown>): LedgerRow {
    return {
      delta: Number(r.delta),
      reason: String(r.reason),
      sourceType: String(r.source_type) as CoinSource,
      idempotencyKey: r.idempotency_key ? String(r.idempotency_key) : undefined,
      createdAt: this.toIso(r.created_at),
    };
  }

  // ---------------------------------------------------------------------------
  // Consent — append-only, for the DPDP audit trail
  // ---------------------------------------------------------------------------

  async recordConsent(
    userId: string, consentType: string, granted: boolean,
    ipHash: string, policyVersion: string,
  ): Promise<void> {
    await this.pool.query(
      `INSERT INTO consent_records (user_id, consent_type, granted, policy_version, locale, ip_hash)
         VALUES ($1,$2,$3,$4,$5,$6)`,
      [userId, consentType, granted, policyVersion, 'en-IN', ipHash],
    );
  }

  async currentConsents(userId: string) {
    // Reads the view, which already resolves "latest row wins" per consent type.
    const { rows } = await this.pool.query(
      `SELECT consent_type, granted, created_at FROM current_consents WHERE user_id = $1`,
      [userId],
    );
    return rows.map((r) => ({
      consentType: String(r.consent_type),
      granted: Boolean(r.granted),
      updatedAt: this.toIso(r.created_at),
    }));
  }

  // ---------------------------------------------------------------------------
  // Leaderboard
  // ---------------------------------------------------------------------------

  async leaderboard(period: string, limit: number) {
    const { rows } = await this.pool.query(
      `SELECT ls.user_id, u.display_handle, ls.activity_points
         FROM leaderboard_scores ls
         JOIN users u ON u.id = ls.user_id
        WHERE ls.period_key = $1 AND u.deleted_at IS NULL
        ORDER BY ls.activity_points DESC
        LIMIT $2`,
      [period, limit],
    );
    return rows.map((r) => ({
      userId: String(r.user_id),
      handle: String(r.display_handle),
      points: Number(r.activity_points),
    }));
  }

  async setLeaderboardScore(userId: string, period: string, points: number): Promise<void> {
    await this.pool.query(
      `INSERT INTO leaderboard_scores (user_id, period_key, activity_points)
         VALUES ($1,$2,$3)
       ON CONFLICT (user_id, period_key)
         DO UPDATE SET activity_points = EXCLUDED.activity_points, updated_at = now()`,
      [userId, period, points],
    );
  }

  // ---------------------------------------------------------------------------
  // Erasure — DPDP right to be forgotten
  // ---------------------------------------------------------------------------

  async eraseUser(userId: string): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Most tables cascade from users. The consent audit trail is the deliberate
      // exception: it is anonymised rather than deleted, because we must still be
      // able to prove a valid consent existed at the time data was processed —
      // and after this, nothing in it identifies a person.
      await client.query(
        `UPDATE consent_records SET ip_hash = NULL, user_agent = NULL WHERE user_id = $1`,
        [userId],
      );
      await client.query(
        `INSERT INTO erasure_requests (user_id, status, completed_at)
           VALUES ($1, 'completed', now())`,
        [userId],
      );
      await client.query('DELETE FROM users WHERE id = $1', [userId]);

      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  // ---------------------------------------------------------------------------
  // Activities / feed
  // ---------------------------------------------------------------------------

  async createActivity(a: Omit<StoredActivity, 'createdAt'>): Promise<StoredActivity> {
    const { rows } = await this.pool.query(
      `INSERT INTO activities (id, user_id, type, title, distance_m, duration_sec, route, started_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [a.id, a.userId, a.type, a.title, a.distanceM, a.durationSec, JSON.stringify(a.route), a.startedAt],
    );
    return this.mapActivity(rows[0]!);
  }

  async getActivity(id: string): Promise<StoredActivity | null> {
    const { rows } = await this.pool.query(`SELECT * FROM activities WHERE id = $1`, [id]);
    return rows[0] ? this.mapActivity(rows[0]) : null;
  }

  async listUserActivities(userId: string, limit: number): Promise<StoredActivity[]> {
    const { rows } = await this.pool.query(
      `SELECT * FROM activities WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [userId, limit],
    );
    return rows.map((r) => this.mapActivity(r));
  }

  async listFeed(userId: string, limit: number): Promise<StoredActivity[]> {
    const { rows } = await this.pool.query(
      `SELECT a.* FROM activities a
        WHERE a.user_id = $1
           OR a.user_id IN (SELECT friend_user_id FROM friend_edges WHERE user_id = $1)
        ORDER BY a.created_at DESC LIMIT $2`,
      [userId, limit],
    );
    return rows.map((r) => this.mapActivity(r));
  }

  private mapActivity(r: Record<string, unknown>): StoredActivity {
    const route = typeof r.route === 'string' ? JSON.parse(r.route) : r.route;
    return {
      id: String(r.id),
      userId: String(r.user_id),
      type: r.type as StoredActivity['type'],
      title: String(r.title),
      distanceM: Number(r.distance_m),
      durationSec: Number(r.duration_sec),
      route: (route ?? []) as StoredActivity['route'],
      startedAt: this.toIso(r.started_at),
      createdAt: this.toIso(r.created_at),
    };
  }

  async toggleKudos(activityId: string, userId: string): Promise<{ given: boolean; count: number }> {
    const existing = await this.pool.query(
      `SELECT 1 FROM activity_kudos WHERE activity_id = $1 AND user_id = $2`,
      [activityId, userId],
    );
    const given = existing.rowCount === 0;
    if (given) {
      await this.pool.query(
        `INSERT INTO activity_kudos (activity_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
        [activityId, userId],
      );
    } else {
      await this.pool.query(
        `DELETE FROM activity_kudos WHERE activity_id = $1 AND user_id = $2`,
        [activityId, userId],
      );
    }
    const { rows } = await this.pool.query<{ count: string }>(
      `SELECT count(*)::text AS count FROM activity_kudos WHERE activity_id = $1`,
      [activityId],
    );
    return { given, count: Number(rows[0]?.count ?? 0) };
  }

  async hasKudos(activityId: string, userId: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      `SELECT 1 FROM activity_kudos WHERE activity_id = $1 AND user_id = $2`,
      [activityId, userId],
    );
    return (rowCount ?? 0) > 0;
  }

  async addComment(activityId: string, userId: string, text: string): Promise<StoredComment> {
    const { rows } = await this.pool.query(
      `INSERT INTO activity_comments (activity_id, user_id, body) VALUES ($1,$2,$3) RETURNING *`,
      [activityId, userId, text],
    );
    const r = rows[0]!;
    return {
      id: String(r.id), activityId: String(r.activity_id), userId: String(r.user_id),
      text: String(r.body), createdAt: this.toIso(r.created_at),
    };
  }

  async listComments(activityId: string): Promise<StoredComment[]> {
    const { rows } = await this.pool.query(
      `SELECT * FROM activity_comments WHERE activity_id = $1 ORDER BY created_at`,
      [activityId],
    );
    return rows.map((r) => ({
      id: String(r.id), activityId: String(r.activity_id), userId: String(r.user_id),
      text: String(r.body), createdAt: this.toIso(r.created_at),
    }));
  }

  // ---------------------------------------------------------------------------
  // Follow graph — reuses friend_edges
  // ---------------------------------------------------------------------------

  async follow(userId: string, targetId: string): Promise<void> {
    if (userId === targetId) return;
    await this.pool.query(
      `INSERT INTO friend_edges (user_id, friend_user_id, source) VALUES ($1,$2,'vyra')
       ON CONFLICT DO NOTHING`,
      [userId, targetId],
    );
  }

  async unfollow(userId: string, targetId: string): Promise<void> {
    await this.pool.query(
      `DELETE FROM friend_edges WHERE user_id = $1 AND friend_user_id = $2`,
      [userId, targetId],
    );
  }

  async isFollowing(userId: string, targetId: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      `SELECT 1 FROM friend_edges WHERE user_id = $1 AND friend_user_id = $2`,
      [userId, targetId],
    );
    return (rowCount ?? 0) > 0;
  }

  async listFollowing(userId: string): Promise<StoredUser[]> {
    const { rows } = await this.pool.query(
      `SELECT u.* FROM users u
         JOIN friend_edges f ON f.friend_user_id = u.id
        WHERE f.user_id = $1 AND u.deleted_at IS NULL`,
      [userId],
    );
    return rows.map((r) => this.mapUser(r));
  }

  async listFollowers(userId: string): Promise<StoredUser[]> {
    const { rows } = await this.pool.query(
      `SELECT u.* FROM users u
         JOIN friend_edges f ON f.user_id = u.id
        WHERE f.friend_user_id = $1 AND u.deleted_at IS NULL`,
      [userId],
    );
    return rows.map((r) => this.mapUser(r));
  }

  async searchUsers(query: string, excludeUserId: string, limit: number): Promise<StoredUser[]> {
    const { rows } = await this.pool.query(
      `SELECT * FROM users
        WHERE id <> $1 AND deleted_at IS NULL
          AND ($2 = '' OR name ILIKE '%' || $2 || '%' OR display_handle ILIKE '%' || $2 || '%')
        ORDER BY name LIMIT $3`,
      [excludeUserId, query, limit],
    );
    return rows.map((r) => this.mapUser(r));
  }

  // ---------------------------------------------------------------------------
  // Beacon — safety location sharing
  // ---------------------------------------------------------------------------

  async setBeacon(userId: string, enabled: boolean, contacts: BeaconContact[]): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(`UPDATE users SET beacon_enabled = $2 WHERE id = $1`, [userId, enabled]);
      await client.query(`DELETE FROM emergency_contacts WHERE user_id = $1`, [userId]);
      let priority = 1;
      for (const c of contacts.slice(0, 3)) {
        await client.query(
          `INSERT INTO emergency_contacts (user_id, name, phone_e164, priority)
             VALUES ($1,$2,$3,$4)
           ON CONFLICT (user_id, phone_e164) DO NOTHING`,
          [userId, c.name, c.phone, priority++],
        );
      }
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async getBeacon(userId: string): Promise<{ enabled: boolean; contacts: BeaconContact[] }> {
    const [userRes, contactsRes] = await Promise.all([
      this.pool.query(`SELECT beacon_enabled FROM users WHERE id = $1`, [userId]),
      this.pool.query(
        `SELECT name, phone_e164 FROM emergency_contacts WHERE user_id = $1 ORDER BY priority`,
        [userId],
      ),
    ]);
    return {
      enabled: Boolean(userRes.rows[0]?.beacon_enabled),
      contacts: contactsRes.rows.map((r) => ({ name: String(r.name), phone: String(r.phone_e164) })),
    };
  }

  // ---------------------------------------------------------------------------
  // Clubs
  // ---------------------------------------------------------------------------

  async listClubs(): Promise<StoredClub[]> {
    const { rows } = await this.pool.query(`SELECT * FROM clubs ORDER BY member_count DESC`);
    return rows.map((r) => this.mapClub(r));
  }

  async getClub(id: string): Promise<StoredClub | null> {
    const { rows } = await this.pool.query(`SELECT * FROM clubs WHERE id = $1`, [id]);
    return rows[0] ? this.mapClub(rows[0]) : null;
  }

  private mapClub(r: Record<string, unknown>): StoredClub {
    return {
      id: String(r.id),
      name: String(r.name),
      description: String(r.description ?? ''),
      interestTag: String(r.interest_tag),
      memberCount: Number(r.member_count),
    };
  }

  async isClubMember(clubId: string, userId: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      `SELECT 1 FROM club_members WHERE club_id = $1 AND user_id = $2`,
      [clubId, userId],
    );
    return (rowCount ?? 0) > 0;
  }

  async joinClub(clubId: string, userId: string): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const inserted = await client.query(
        `INSERT INTO club_members (club_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
        [clubId, userId],
      );
      if ((inserted.rowCount ?? 0) > 0) {
        await client.query(`UPDATE clubs SET member_count = member_count + 1 WHERE id = $1`, [clubId]);
      }
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async leaveClub(clubId: string, userId: string): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const deleted = await client.query(
        `DELETE FROM club_members WHERE club_id = $1 AND user_id = $2`,
        [clubId, userId],
      );
      if ((deleted.rowCount ?? 0) > 0) {
        await client.query(
          `UPDATE clubs SET member_count = GREATEST(0, member_count - 1) WHERE id = $1`,
          [clubId],
        );
      }
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async listClubPosts(clubId: string): Promise<StoredClubPost[]> {
    const { rows } = await this.pool.query(
      `SELECT * FROM club_posts WHERE club_id = $1 ORDER BY created_at DESC`,
      [clubId],
    );
    return rows.map((r) => ({
      id: String(r.id), clubId: String(r.club_id), userId: String(r.user_id),
      body: String(r.body), createdAt: this.toIso(r.created_at),
    }));
  }

  async addClubPost(clubId: string, userId: string, body: string): Promise<StoredClubPost> {
    const { rows } = await this.pool.query(
      `INSERT INTO club_posts (club_id, user_id, body) VALUES ($1,$2,$3) RETURNING *`,
      [clubId, userId, body],
    );
    const r = rows[0]!;
    return {
      id: String(r.id), clubId: String(r.club_id), userId: String(r.user_id),
      body: String(r.body), createdAt: this.toIso(r.created_at),
    };
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  async listEvents(): Promise<StoredEvent[]> {
    const { rows } = await this.pool.query(`SELECT * FROM events ORDER BY starts_at`);
    return rows.map((r) => ({
      id: String(r.id), title: String(r.title), sport: String(r.sport),
      location: String(r.location), startsAt: this.toIso(r.starts_at),
      clubId: r.club_id ? String(r.club_id) : null,
    }));
  }

  async isRegisteredForEvent(eventId: string, userId: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      `SELECT 1 FROM event_registrations WHERE event_id = $1 AND user_id = $2`,
      [eventId, userId],
    );
    return (rowCount ?? 0) > 0;
  }

  async registerForEvent(eventId: string, userId: string): Promise<void> {
    await this.pool.query(
      `INSERT INTO event_registrations (event_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
      [eventId, userId],
    );
  }

  async unregisterFromEvent(eventId: string, userId: string): Promise<void> {
    await this.pool.query(
      `DELETE FROM event_registrations WHERE event_id = $1 AND user_id = $2`,
      [eventId, userId],
    );
  }

  // ---------------------------------------------------------------------------
  // Direct messaging
  // ---------------------------------------------------------------------------

  async getOrCreateConversation(userA: string, userB: string): Promise<StoredConversation> {
    const { rows } = await this.pool.query<{ conversation_id: string }>(
      `SELECT cp1.conversation_id
         FROM conversation_participants cp1
         JOIN conversation_participants cp2 ON cp1.conversation_id = cp2.conversation_id
        WHERE cp1.user_id = $1 AND cp2.user_id = $2
        LIMIT 1`,
      [userA, userB],
    );
    if (rows[0]) {
      const existing = await this.getConversation(rows[0].conversation_id);
      if (existing) return existing;
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const created = await client.query(`INSERT INTO conversations DEFAULT VALUES RETURNING *`);
      const createdRow = created.rows[0]!;
      const conversationId = createdRow.id as string;
      await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id) VALUES ($1,$2), ($1,$3)`,
        [conversationId, userA, userB],
      );
      await client.query('COMMIT');
      return { id: conversationId, participantIds: [userA, userB],
        createdAt: this.toIso(createdRow.created_at) };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async listConversations(userId: string): Promise<StoredConversation[]> {
    const { rows } = await this.pool.query<{ conversation_id: string; created_at: unknown }>(
      `SELECT c.id AS conversation_id, c.created_at
         FROM conversations c
         JOIN conversation_participants cp ON cp.conversation_id = c.id
        WHERE cp.user_id = $1`,
      [userId],
    );
    const conversations: StoredConversation[] = [];
    for (const row of rows) {
      const conversation = await this.getConversation(row.conversation_id);
      if (conversation) conversations.push(conversation);
    }
    return conversations;
  }

  async getConversation(id: string): Promise<StoredConversation | null> {
    const convRes = await this.pool.query(`SELECT * FROM conversations WHERE id = $1`, [id]);
    if (!convRes.rows[0]) return null;
    const participantsRes = await this.pool.query<{ user_id: string }>(
      `SELECT user_id FROM conversation_participants WHERE conversation_id = $1`,
      [id],
    );
    return {
      id,
      participantIds: participantsRes.rows.map((r) => r.user_id),
      createdAt: this.toIso(convRes.rows[0].created_at),
    };
  }

  async listMessages(conversationId: string, limit: number): Promise<StoredMessage[]> {
    const { rows } = await this.pool.query(
      `SELECT * FROM messages WHERE conversation_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [conversationId, limit],
    );
    return rows.reverse().map((r) => ({
      id: String(r.id), conversationId: String(r.conversation_id), senderId: String(r.sender_id),
      body: String(r.body), createdAt: this.toIso(r.created_at),
    }));
  }

  async sendMessage(conversationId: string, senderId: string, body: string): Promise<StoredMessage> {
    const { rows } = await this.pool.query(
      `INSERT INTO messages (conversation_id, sender_id, body) VALUES ($1,$2,$3) RETURNING *`,
      [conversationId, senderId, body],
    );
    const r = rows[0]!;
    return {
      id: String(r.id), conversationId: String(r.conversation_id), senderId: String(r.sender_id),
      body: String(r.body), createdAt: this.toIso(r.created_at),
    };
  }

  // ---------------------------------------------------------------------------
  // AI fitness chat
  // ---------------------------------------------------------------------------

  async appendChatMessage(
    userId: string, role: 'user' | 'assistant', body: string,
  ): Promise<StoredChatMessage> {
    const { rows } = await this.pool.query(
      `INSERT INTO ai_chat_messages (user_id, role, body) VALUES ($1,$2,$3) RETURNING *`,
      [userId, role, body],
    );
    const r = rows[0]!;
    return {
      id: String(r.id), userId: String(r.user_id), role: r.role as 'user' | 'assistant',
      body: String(r.body), createdAt: this.toIso(r.created_at),
    };
  }

  async listChatHistory(userId: string, limit: number): Promise<StoredChatMessage[]> {
    const { rows } = await this.pool.query(
      `SELECT * FROM ai_chat_messages WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [userId, limit],
    );
    return rows.reverse().map((r) => ({
      id: String(r.id), userId: String(r.user_id), role: r.role as 'user' | 'assistant',
      body: String(r.body), createdAt: this.toIso(r.created_at),
    }));
  }

  async clearChatHistory(userId: string): Promise<void> {
    await this.pool.query(`DELETE FROM ai_chat_messages WHERE user_id = $1`, [userId]);
  }

  // ---------------------------------------------------------------------------
  // Password auth
  // ---------------------------------------------------------------------------

  async getUserByEmail(email: string): Promise<StoredUser | null> {
    const { rows } = await this.pool.query(
      `SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL`,
      [email.trim().toLowerCase()],
    );
    return rows[0] ? this.mapUser(rows[0]) : null;
  }

  async setPasswordHash(userId: string, hash: string): Promise<void> {
    await this.pool.query(`UPDATE users SET password_hash = $2 WHERE id = $1`, [userId, hash]);
  }

  async getPasswordHash(userId: string): Promise<string | null> {
    const { rows } = await this.pool.query<{ password_hash: string | null }>(
      `SELECT password_hash FROM users WHERE id = $1`, [userId],
    );
    return rows[0]?.password_hash ?? null;
  }

  // ---------------------------------------------------------------------------
  // Auth identities (Google/Facebook)
  // ---------------------------------------------------------------------------

  async linkAuthIdentity(userId: string, provider: string, providerUid: string): Promise<void> {
    await this.pool.query(
      `INSERT INTO auth_identities (user_id, provider, provider_uid) VALUES ($1,$2,$3)
       ON CONFLICT (provider, provider_uid) DO NOTHING`,
      [userId, provider, providerUid],
    );
  }

  async getUserByAuthIdentity(provider: string, providerUid: string): Promise<StoredUser | null> {
    const { rows } = await this.pool.query(
      `SELECT u.* FROM users u
         JOIN auth_identities ai ON ai.user_id = u.id
        WHERE ai.provider = $1 AND ai.provider_uid = $2 AND u.deleted_at IS NULL`,
      [provider, providerUid],
    );
    return rows[0] ? this.mapUser(rows[0]) : null;
  }

  // ---------------------------------------------------------------------------
  // Reports & blocks
  // ---------------------------------------------------------------------------

  async createReport(r: { reporterId: string; targetType: ReportTargetType; targetId: string;
    reason: ReportReason; detail?: string }): Promise<StoredReport> {
    const { rows } = await this.pool.query(
      `INSERT INTO reports (reporter_id, target_type, target_id, reason, detail)
         VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [r.reporterId, r.targetType, r.targetId, r.reason, r.detail ?? null],
    );
    return this.mapReport(rows[0]!);
  }

  async listReports(status?: ReportStatus): Promise<StoredReport[]> {
    const { rows } = status
      ? await this.pool.query(`SELECT * FROM reports WHERE status = $1 ORDER BY created_at DESC`, [status])
      : await this.pool.query(`SELECT * FROM reports ORDER BY created_at DESC`);
    return rows.map((r) => this.mapReport(r));
  }

  async getReport(id: string): Promise<StoredReport | null> {
    const { rows } = await this.pool.query(`SELECT * FROM reports WHERE id = $1`, [id]);
    return rows[0] ? this.mapReport(rows[0]) : null;
  }

  async resolveReport(id: string, adminId: string, status: ReportStatus, resolution?: string):
    Promise<StoredReport> {
    const { rows } = await this.pool.query(
      `UPDATE reports SET status = $2, resolved_by = $3, resolution = $4, resolved_at = now()
         WHERE id = $1 RETURNING *`,
      [id, status, adminId, resolution ?? null],
    );
    if (!rows[0]) throw new Error(`Report ${id} not found`);
    return this.mapReport(rows[0]);
  }

  private mapReport(r: Record<string, unknown>): StoredReport {
    return {
      id: String(r.id),
      reporterId: String(r.reporter_id),
      targetType: r.target_type as ReportTargetType,
      targetId: String(r.target_id),
      reason: r.reason as ReportReason,
      detail: r.detail ? String(r.detail) : undefined,
      status: r.status as ReportStatus,
      resolvedBy: r.resolved_by ? String(r.resolved_by) : undefined,
      resolution: r.resolution ? String(r.resolution) : undefined,
      createdAt: this.toIso(r.created_at),
      resolvedAt: r.resolved_at ? this.toIso(r.resolved_at) : undefined,
    };
  }

  async blockUser(blockerId: string, blockedId: string): Promise<void> {
    await this.pool.query(
      `INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
      [blockerId, blockedId],
    );
    await this.unfollow(blockerId, blockedId);
    await this.unfollow(blockedId, blockerId);
  }

  async unblockUser(blockerId: string, blockedId: string): Promise<void> {
    await this.pool.query(`DELETE FROM blocks WHERE blocker_id = $1 AND blocked_id = $2`,
      [blockerId, blockedId]);
  }

  async isBlocked(blockerId: string, blockedId: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      `SELECT 1 FROM blocks WHERE blocker_id = $1 AND blocked_id = $2`, [blockerId, blockedId],
    );
    return (rowCount ?? 0) > 0;
  }

  async listBlocked(blockerId: string): Promise<StoredUser[]> {
    const { rows } = await this.pool.query(
      `SELECT u.* FROM users u JOIN blocks b ON b.blocked_id = u.id WHERE b.blocker_id = $1`,
      [blockerId],
    );
    return rows.map((r) => this.mapUser(r));
  }

  // ---------------------------------------------------------------------------
  // Admin accounts
  // ---------------------------------------------------------------------------

  async createAdmin(a: Omit<StoredAdmin, 'createdAt'>): Promise<StoredAdmin> {
    const { rows } = await this.pool.query(
      `INSERT INTO admin_users (id, email, name, password_hash, role, is_active)
         VALUES ($1,$2,$3,'',$4,$5) RETURNING *`,
      [a.id, a.email, a.name, a.role, a.isActive],
    );
    return this.mapAdmin(rows[0]!);
  }

  async getAdminByEmail(email: string): Promise<StoredAdmin | null> {
    const { rows } = await this.pool.query(`SELECT * FROM admin_users WHERE email = $1`,
      [email.trim().toLowerCase()]);
    return rows[0] ? this.mapAdmin(rows[0]) : null;
  }

  async getAdmin(id: string): Promise<StoredAdmin | null> {
    const { rows } = await this.pool.query(`SELECT * FROM admin_users WHERE id = $1`, [id]);
    return rows[0] ? this.mapAdmin(rows[0]) : null;
  }

  async listAdmins(): Promise<StoredAdmin[]> {
    const { rows } = await this.pool.query(`SELECT * FROM admin_users ORDER BY created_at`);
    return rows.map((r) => this.mapAdmin(r));
  }

  private mapAdmin(r: Record<string, unknown>): StoredAdmin {
    return {
      id: String(r.id), email: String(r.email), name: String(r.name),
      role: r.role as StoredAdmin['role'], isActive: Boolean(r.is_active),
      createdAt: this.toIso(r.created_at),
    };
  }

  async setAdminPasswordHash(adminId: string, hash: string): Promise<void> {
    await this.pool.query(`UPDATE admin_users SET password_hash = $2 WHERE id = $1`, [adminId, hash]);
  }

  async getAdminPasswordHash(adminId: string): Promise<string | null> {
    const { rows } = await this.pool.query<{ password_hash: string | null }>(
      `SELECT password_hash FROM admin_users WHERE id = $1`, [adminId],
    );
    return rows[0]?.password_hash ?? null;
  }

  // ---------------------------------------------------------------------------
  // Platform-wide moderation & operations
  // ---------------------------------------------------------------------------

  async setAccountStatus(userId: string, status: AccountStatus): Promise<void> {
    await this.pool.query(`UPDATE users SET account_status = $2 WHERE id = $1`, [userId, status]);
  }

  async listUsersForAdmin(limit: number, offset: number, query?: string): Promise<StoredUser[]> {
    const q = query?.trim() ?? '';
    const { rows } = await this.pool.query(
      `SELECT * FROM users
        WHERE ($3 = '' OR name ILIKE '%'||$3||'%' OR display_handle ILIKE '%'||$3||'%'
               OR email ILIKE '%'||$3||'%')
        ORDER BY signup_date DESC LIMIT $1 OFFSET $2`,
      [limit, offset, q],
    );
    return rows.map((r) => this.mapUser(r));
  }

  async countUsers(): Promise<number> {
    const { rows } = await this.pool.query<{ count: string }>(`SELECT count(*)::text AS count FROM users`);
    return Number(rows[0]?.count ?? 0);
  }

  async appendAuditLog(entry: Omit<AuditEntry, 'createdAt'>): Promise<void> {
    await this.pool.query(
      `INSERT INTO audit_log (actor_id, actor_role, action, target_type, target_id, reason)
         VALUES ($1,$2,$3,$4,$5,$6)`,
      [entry.actorId ?? null, entry.actorRole ?? null, entry.action,
        entry.targetType ?? null, entry.targetId ?? null, entry.reason ?? null],
    );
  }

  async listAuditLog(limit: number): Promise<AuditEntry[]> {
    const { rows } = await this.pool.query(
      `SELECT * FROM audit_log ORDER BY created_at DESC LIMIT $1`, [limit],
    );
    return rows.map((r) => ({
      actorId: r.actor_id ? String(r.actor_id) : undefined,
      actorRole: r.actor_role ? String(r.actor_role) : undefined,
      action: String(r.action),
      targetType: r.target_type ? String(r.target_type) : undefined,
      targetId: r.target_id ? String(r.target_id) : undefined,
      reason: r.reason ? String(r.reason) : undefined,
      createdAt: this.toIso(r.created_at),
    }));
  }

  // ---------------------------------------------------------------------------
  // Movement definitions — 3D exercise avatar system.
  //
  // The seed set (services/api/src/content/movements.ts) is the source of
  // truth for the MVP exercises, the same way exercises themselves live in
  // code, not the (unseeded) `exercises` table. A DB row, if one exists,
  // overrides the seed — so an admin can eventually edit a movement without
  // a code deploy, but nothing breaks before that ever happens.
  // ---------------------------------------------------------------------------

  async getMovementDefinition(exerciseSlug: string): Promise<MovementDefinition | null> {
    const { rows } = await this.pool.query(
      `SELECT * FROM movement_definitions WHERE exercise_slug = $1`, [exerciseSlug],
    );
    if (rows[0]) return this.mapMovementDefinition(rows[0]);
    return MOVEMENT_DEFINITIONS.find((d) => d.exerciseSlug === exerciseSlug) ?? null;
  }

  async upsertMovementDefinition(def: MovementDefinition): Promise<MovementDefinition> {
    await this.pool.query(
      `INSERT INTO movement_definitions
         (exercise_slug, rig_id, tempo, target_muscle, phases, correct_mechanics,
          avoid_cheats, camera_views)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       ON CONFLICT (exercise_slug) DO UPDATE SET
         rig_id = $2, tempo = $3, target_muscle = $4, phases = $5,
         correct_mechanics = $6, avoid_cheats = $7, camera_views = $8`,
      [
        def.exerciseSlug, def.rigId, def.tempo, def.targetMuscle,
        JSON.stringify(def.phases), JSON.stringify(def.correctMechanics),
        JSON.stringify(def.avoidCheats), JSON.stringify(def.cameraViews),
      ],
    );
    return def;
  }

  async listMovementDefinitions(): Promise<MovementDefinition[]> {
    const { rows } = await this.pool.query(`SELECT * FROM movement_definitions`);
    const fromDb = rows.map((r) => this.mapMovementDefinition(r));
    const dbSlugs = new Set(fromDb.map((d) => d.exerciseSlug));
    const fromSeed = MOVEMENT_DEFINITIONS.filter((d) => !dbSlugs.has(d.exerciseSlug));
    return [...fromDb, ...fromSeed];
  }

  private mapMovementDefinition(r: Record<string, unknown>): MovementDefinition {
    const parse = <T,>(v: unknown, fallback: T): T =>
      typeof v === 'string' ? JSON.parse(v) : (v as T) ?? fallback;
    return {
      exerciseSlug: String(r.exercise_slug),
      rigId: String(r.rig_id),
      tempo: String(r.tempo),
      targetMuscle: String(r.target_muscle),
      phases: parse(r.phases, []),
      correctMechanics: parse(r.correct_mechanics, []),
      avoidCheats: parse(r.avoid_cheats, []),
      cameraViews: parse(r.camera_views, ['front']),
    };
  }

  // ---------------------------------------------------------------------------

  async health() {
    try {
      const { rows } = await this.pool.query<{ count: string }>(
        'SELECT count(*)::text AS count FROM users WHERE deleted_at IS NULL',
      );
      return { ok: true, backend: 'postgres', detail: `${rows[0]?.count ?? '0'} users` };
    } catch (error) {
      return { ok: false, backend: 'postgres', detail: (error as Error).message };
    }
  }
}
