/**
 * =============================================================================
 * STORAGE
 * =============================================================================
 * One interface, two implementations:
 *
 *   MemoryStore  — zero setup. The API boots and works with no database at all.
 *   PgStore      — Postgres, used whenever DATABASE_URL is present.
 *
 * This is not over-engineering; it buys two concrete things:
 *   1. The whole API can be exercised in tests and in a live demo without a
 *      database, so a failed connection can never take the demo down.
 *   2. Every query lives behind a named method, so the SQL is in one file rather
 *      than scattered through route handlers.
 *
 * PgStore lives in store.pg.ts and is loaded lazily, so the `pg` driver is only
 * required when it is actually used.
 * =============================================================================
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import type { DietPreference, FitnessGoal, Gender, ISODate } from '@vyra/types';
import { MOVEMENT_DEFINITIONS } from './content/movements';
import type { RawBlock } from './domain/chrono';
import type { LedgerRow } from './domain/coins';

export interface StoredUser {
  id: string;
  displayHandle: string;
  name: string;
  email?: string;
  dob: ISODate;
  gender: Gender;
  heightCm: number;
  weightKg: number;
  disabilityFlag: boolean;
  accessibilityMode: boolean;
  disabilityType?: string;
  hasPhysicalConsideration?: boolean;
  physicalConsiderationDetails?: string;
  medicalConditions?: string[];
  fitnessGoal: FitnessGoal;
  fitnessLevel?: string;
  bodyType?: string;
  latestLabMarkers?: Record<string, number>;
  labInsights?: string[];
  dietToggle: boolean;
  dietPreference: DietPreference;
  city?: string;
  primarySport: string;
  dmPrivacy: DmPrivacy;
  accountStatus: AccountStatus;
  onboardingStep: number;
  createdAt: string;
}

export interface StoredTracking {
  userId: string;
  recordDate: ISODate;
  waterMl?: number;
  steps?: number;
  /** Encrypted envelopes, keyed by field name. Never plaintext at rest. */
  encrypted: Record<string, Buffer>;
  source: string;
}

export interface StoredPlanEntry {
  exerciseSlug: string;
  name: string;
  durationSec: number;
  isCompleted: boolean;
  scheduledAt?: string;
}

export interface StoredPlan {
  userId: string;
  planDate: ISODate;
  goalMin: number;
  capacityMin: number;
  entries: StoredPlanEntry[];
  achievedMin: number;
}

/** One GPS fix. `t` is seconds elapsed since the activity started. */
export interface ActivityPoint {
  lat: number;
  lng: number;
  t: number;
}

export interface StoredActivity {
  id: string;
  userId: string;
  type: 'run' | 'ride' | 'walk' | 'other';
  title: string;
  distanceM: number;
  durationSec: number;
  route: ActivityPoint[];
  startedAt: string;
  createdAt: string;
}

export interface StoredComment {
  id: string;
  activityId: string;
  userId: string;
  text: string;
  createdAt: string;
}

export interface BeaconContact {
  name: string;
  phone: string;
}

export interface StoredClub {
  id: string;
  name: string;
  description: string;
  interestTag: string;
  memberCount: number;
}

export interface StoredClubPost {
  id: string;
  clubId: string;
  userId: string;
  body: string;
  createdAt: string;
}

export interface StoredEvent {
  id: string;
  title: string;
  sport: string;
  location: string;
  startsAt: string;
  clubId: string | null;
}

export type DmPrivacy = 'following' | 'mutuals' | 'no_one';
export type AccountStatus = 'active' | 'flagged' | 'suspended' | 'banned' | 'deleted';
export type AdminRole = 'super_admin' | 'content_manager' | 'support_agent' | 'compliance_auditor';
export type ReportTargetType = 'activity' | 'club_post' | 'message' | 'user' | 'comment';
export type ReportStatus = 'pending' | 'reviewing' | 'resolved' | 'dismissed';
export type ReportReason =
  | 'spam' | 'harassment' | 'inappropriate_content' | 'unwanted_contact'
  | 'impersonation' | 'safety_concern' | 'other';

export interface StoredReport {
  id: string;
  reporterId: string;
  targetType: ReportTargetType;
  targetId: string;
  reason: ReportReason;
  detail?: string;
  status: ReportStatus;
  resolvedBy?: string;
  resolution?: string;
  createdAt: string;
  resolvedAt?: string;
}

export interface StoredAdmin {
  id: string;
  email: string;
  name: string;
  role: AdminRole;
  isActive: boolean;
  createdAt: string;
}

export interface AuditEntry {
  actorId?: string;
  actorRole?: string;
  action: string;
  targetType?: string;
  targetId?: string;
  reason?: string;
  createdAt: string;
}

/** One step of a code-driven 3D exercise animation — pure data, no rendering
 * logic. The same reusable rig (`rigId`) plays back whichever phases a given
 * exercise's MovementDefinition supplies. */
export interface MovementPhase {
  id: string;
  label: string;
  cue: string;
  /** Joint name -> target angle in degrees, e.g. { leftElbow: 140, rightElbow: 140 }. */
  jointTargets: Record<string, number>;
  durationSec: number;
}

export interface MovementDefinition {
  exerciseSlug: string;
  rigId: string;
  tempo: string;
  targetMuscle: string;
  phases: MovementPhase[];
  correctMechanics: string[];
  avoidCheats: string[];
  cameraViews: string[];
}

export interface StoredMessage {
  id: string;
  conversationId: string;
  senderId: string;
  body: string;
  createdAt: string;
}

export interface StoredConversation {
  id: string;
  participantIds: string[];
  createdAt: string;
}

/**
 * AI fitness chat — deliberately NOT a StoredMessage. That type belongs to a
 * StoredConversation with multiple participantIds; AI chat is always exactly
 * one user talking to the assistant, so it gets its own flat, per-user shape
 * instead of a fake two-participant conversation.
 */
export interface StoredChatMessage {
  id: string;
  userId: string;
  role: 'user' | 'assistant';
  body: string;
  createdAt: string;
}

export interface Store {
  createUser(u: Omit<StoredUser, 'createdAt'>): Promise<StoredUser>;
  getUser(id: string): Promise<StoredUser | null>;
  updateUser(id: string, patch: Partial<StoredUser>): Promise<StoredUser>;

  setSchedule(userId: string, blocks: RawBlock[]): Promise<void>;
  getSchedule(userId: string): Promise<RawBlock[]>;

  upsertPlan(plan: StoredPlan): Promise<StoredPlan>;
  getPlan(userId: string, date: ISODate): Promise<StoredPlan | null>;
  listPlans(userId: string, fromDate: ISODate, toDate: ISODate): Promise<StoredPlan[]>;

  upsertTracking(rec: StoredTracking): Promise<StoredTracking>;
  getTracking(userId: string, date: ISODate): Promise<StoredTracking | null>;
  listTracking(userId: string, from: ISODate, to: ISODate): Promise<StoredTracking[]>;

  setSugar(userId: string, date: ISODate, grams: number): Promise<void>;
  getSugar(userId: string, date: ISODate): Promise<number | null>;
  listSugar(userId: string, from: ISODate, to: ISODate): Promise<Array<{ date: ISODate; grams: number }>>;

  appendLedger(userId: string, row: LedgerRow): Promise<void>;
  listLedger(userId: string): Promise<LedgerRow[]>;
  listLedgerForDate(userId: string, date: ISODate): Promise<LedgerRow[]>;

  recordConsent(userId: string, type: string, granted: boolean, ipHash: string, policyVersion: string): Promise<void>;
  currentConsents(userId: string): Promise<Array<{ consentType: string; granted: boolean; updatedAt: string }>>;

  leaderboard(period: string, limit: number): Promise<Array<{ userId: string; handle: string; points: number }>>;
  setLeaderboardScore(userId: string, period: string, points: number): Promise<void>;

  // Activities — GPS-recorded runs/rides, the source of the social feed.
  createActivity(a: Omit<StoredActivity, 'createdAt'>): Promise<StoredActivity>;
  getActivity(id: string): Promise<StoredActivity | null>;
  listUserActivities(userId: string, limit: number): Promise<StoredActivity[]>;
  /** Self + everyone the user follows, newest first. */
  listFeed(userId: string, limit: number): Promise<StoredActivity[]>;

  toggleKudos(activityId: string, userId: string): Promise<{ given: boolean; count: number }>;
  hasKudos(activityId: string, userId: string): Promise<boolean>;

  addComment(activityId: string, userId: string, text: string): Promise<StoredComment>;
  listComments(activityId: string): Promise<StoredComment[]>;

  // Follow graph
  follow(userId: string, targetId: string): Promise<void>;
  unfollow(userId: string, targetId: string): Promise<void>;
  isFollowing(userId: string, targetId: string): Promise<boolean>;
  listFollowing(userId: string): Promise<StoredUser[]>;
  listFollowers(userId: string): Promise<StoredUser[]>;
  searchUsers(query: string, excludeUserId: string, limit: number): Promise<StoredUser[]>;

  // Beacon — live-location safety sharing with up to three contacts
  setBeacon(userId: string, enabled: boolean, contacts: BeaconContact[]): Promise<void>;
  getBeacon(userId: string): Promise<{ enabled: boolean; contacts: BeaconContact[] }>;

  // Clubs
  listClubs(): Promise<StoredClub[]>;
  getClub(id: string): Promise<StoredClub | null>;
  isClubMember(clubId: string, userId: string): Promise<boolean>;
  joinClub(clubId: string, userId: string): Promise<void>;
  leaveClub(clubId: string, userId: string): Promise<void>;
  listClubPosts(clubId: string): Promise<StoredClubPost[]>;
  addClubPost(clubId: string, userId: string, body: string): Promise<StoredClubPost>;

  // Events
  listEvents(): Promise<StoredEvent[]>;
  isRegisteredForEvent(eventId: string, userId: string): Promise<boolean>;
  registerForEvent(eventId: string, userId: string): Promise<void>;
  unregisterFromEvent(eventId: string, userId: string): Promise<void>;

  // Direct messaging
  getOrCreateConversation(userA: string, userB: string): Promise<StoredConversation>;
  listConversations(userId: string): Promise<StoredConversation[]>;
  getConversation(id: string): Promise<StoredConversation | null>;
  listMessages(conversationId: string, limit: number): Promise<StoredMessage[]>;
  sendMessage(conversationId: string, senderId: string, body: string): Promise<StoredMessage>;

  // AI fitness chat — single-user, no participants; see StoredChatMessage.
  appendChatMessage(userId: string, role: 'user' | 'assistant', body: string): Promise<StoredChatMessage>;
  listChatHistory(userId: string, limit: number): Promise<StoredChatMessage[]>;
  clearChatHistory(userId: string): Promise<void>;

  // Password auth — kept separate from StoredUser so a hash can never
  // accidentally ride along in a response that spreads the user object.
  getUserByEmail(email: string): Promise<StoredUser | null>;
  setPasswordHash(userId: string, hash: string): Promise<void>;
  getPasswordHash(userId: string): Promise<string | null>;

  // Google/Facebook sign-in — one user may link multiple providers.
  linkAuthIdentity(userId: string, provider: string, providerUid: string): Promise<void>;
  getUserByAuthIdentity(provider: string, providerUid: string): Promise<StoredUser | null>;

  // Reports & blocks — Strava's own model: every report lands in a human
  // review queue, and blocking is a separate, stronger action than unfollow.
  createReport(r: { reporterId: string; targetType: ReportTargetType; targetId: string;
    reason: ReportReason; detail?: string }): Promise<StoredReport>;
  listReports(status?: ReportStatus): Promise<StoredReport[]>;
  getReport(id: string): Promise<StoredReport | null>;
  resolveReport(id: string, adminId: string, status: ReportStatus, resolution?: string):
    Promise<StoredReport>;

  blockUser(blockerId: string, blockedId: string): Promise<void>;
  unblockUser(blockerId: string, blockedId: string): Promise<void>;
  isBlocked(blockerId: string, blockedId: string): Promise<boolean>;
  listBlocked(blockerId: string): Promise<StoredUser[]>;

  // Admin accounts — separate credential space from athlete accounts.
  createAdmin(a: Omit<StoredAdmin, 'createdAt'>): Promise<StoredAdmin>;
  getAdminByEmail(email: string): Promise<StoredAdmin | null>;
  getAdmin(id: string): Promise<StoredAdmin | null>;
  listAdmins(): Promise<StoredAdmin[]>;
  setAdminPasswordHash(adminId: string, hash: string): Promise<void>;
  getAdminPasswordHash(adminId: string): Promise<string | null>;

  // Platform-wide moderation & operations
  setAccountStatus(userId: string, status: AccountStatus): Promise<void>;
  listUsersForAdmin(limit: number, offset: number, query?: string): Promise<StoredUser[]>;
  countUsers(): Promise<number>;
  appendAuditLog(entry: Omit<AuditEntry, 'createdAt'>): Promise<void>;
  listAuditLog(limit: number): Promise<AuditEntry[]>;

  // Movement definitions — the code-driven 3D exercise avatar system
  getMovementDefinition(exerciseSlug: string): Promise<MovementDefinition | null>;
  upsertMovementDefinition(def: MovementDefinition): Promise<MovementDefinition>;
  listMovementDefinitions(): Promise<MovementDefinition[]>;

  /** Deletes everything belonging to a user. DPDP right to erasure. */
  eraseUser(userId: string): Promise<void>;

  health(): Promise<{ ok: boolean; backend: string; detail?: string }>;
}

// =============================================================================
// In-memory implementation
// =============================================================================

export class MemoryStore implements Store {
  private users = new Map<string, StoredUser>();
  private schedules = new Map<string, RawBlock[]>();
  private plans = new Map<string, StoredPlan>();          // `${userId}:${date}`
  private tracking = new Map<string, StoredTracking>();
  private sugar = new Map<string, number>();
  private ledgers = new Map<string, LedgerRow[]>();
  private consents = new Map<string, Array<{ consentType: string; granted: boolean; updatedAt: string; ipHash: string; policyVersion: string }>>();
  private scores = new Map<string, Map<string, number>>();  // period -> userId -> points

  private activities = new Map<string, StoredActivity>();
  private kudos = new Map<string, Set<string>>();            // activityId -> Set<userId>
  private comments = new Map<string, StoredComment[]>();     // activityId -> comments
  private following = new Map<string, Set<string>>();        // userId -> Set<followedId>
  private beacons = new Map<string, { enabled: boolean; contacts: BeaconContact[] }>();

  private clubs = new Map<string, StoredClub>();
  private clubMembers = new Map<string, Set<string>>();     // clubId -> Set<userId>
  private clubPosts = new Map<string, StoredClubPost[]>();  // clubId -> posts
  private events = new Map<string, StoredEvent>();
  private eventRegistrations = new Map<string, Set<string>>(); // eventId -> Set<userId>

  private conversations = new Map<string, StoredConversation>();
  private messages = new Map<string, StoredMessage[]>(); // conversationId -> messages
  private chatMessages = new Map<string, StoredChatMessage[]>(); // userId -> AI chat messages, oldest first
  private passwordHashes = new Map<string, string>();

  private authIdentities = new Map<string, string>(); // `${provider}:${uid}` -> userId
  private reports = new Map<string, StoredReport>();
  private blocks = new Map<string, Set<string>>(); // blockerId -> Set<blockedId>
  private admins = new Map<string, StoredAdmin>();
  private adminPasswordHashes = new Map<string, string>();
  private auditLog: AuditEntry[] = [];

  private movementDefinitions = new Map<string, MovementDefinition>();

  private backupPath = process.env.STORE_BACKUP_PATH || resolve(process.cwd(), 'vyra_store_backup.json');
  private persistTimer: NodeJS.Timeout | null = null;

  private persistDebounced() {
    if (this.persistTimer) return;
    this.persistTimer = setTimeout(() => {
      this.persistTimer = null;
      try {
        const data = {
          users: [...this.users.entries()],
          schedules: [...this.schedules.entries()],
          plans: [...this.plans.entries()],
          sugar: [...this.sugar.entries()],
          ledgers: [...this.ledgers.entries()],
          scores: [...this.scores.entries()].map(([k, v]) => [k, [...v.entries()]]),
          activities: [...this.activities.entries()],
          following: [...this.following.entries()].map(([k, v]) => [k, [...v]]),
          chatMessages: [...this.chatMessages.entries()],
          passwordHashes: [...this.passwordHashes.entries()],
          events: [...this.events.entries()],
          eventRegistrations: [...this.eventRegistrations.entries()].map(([k, v]) => [k, [...v]]),
          clubs: [...this.clubs.entries()],
          clubMembers: [...this.clubMembers.entries()].map(([k, v]) => [k, [...v]]),
          clubPosts: [...this.clubPosts.entries()],
        };
        writeFileSync(this.backupPath, JSON.stringify(data, null, 2), 'utf-8');
      } catch (err) {
        console.error('Failed to persist store to disk:', err);
      }
    }, 500);
  }

  private loadFromDisk(): boolean {
    try {
      if (!existsSync(this.backupPath)) return false;
      const raw = readFileSync(this.backupPath, 'utf-8');
      const data = JSON.parse(raw);
      if (Array.isArray(data.users)) for (const [k, v] of data.users) this.users.set(k, v);
      if (Array.isArray(data.schedules)) for (const [k, v] of data.schedules) this.schedules.set(k, v);
      if (Array.isArray(data.plans)) for (const [k, v] of data.plans) this.plans.set(k, v);
      if (Array.isArray(data.sugar)) for (const [k, v] of data.sugar) this.sugar.set(k, v);
      if (Array.isArray(data.ledgers)) for (const [k, v] of data.ledgers) this.ledgers.set(k, v);
      if (Array.isArray(data.activities)) for (const [k, v] of data.activities) this.activities.set(k, v);
      if (Array.isArray(data.chatMessages)) for (const [k, v] of data.chatMessages) this.chatMessages.set(k, v);
      if (Array.isArray(data.passwordHashes)) for (const [k, v] of data.passwordHashes) this.passwordHashes.set(k, v);
      if (Array.isArray(data.events)) for (const [k, v] of data.events) this.events.set(k, v);
      if (Array.isArray(data.clubs)) for (const [k, v] of data.clubs) this.clubs.set(k, v);
      if (Array.isArray(data.scores)) {
        for (const [k, entries] of data.scores) {
          this.scores.set(k, new Map(entries));
        }
      }
      if (Array.isArray(data.following)) {
        for (const [k, entries] of data.following) {
          this.following.set(k, new Set(entries));
        }
      }
      if (Array.isArray(data.eventRegistrations)) {
        for (const [k, entries] of data.eventRegistrations) {
          this.eventRegistrations.set(k, new Set(entries));
        }
      }
      if (Array.isArray(data.clubMembers)) {
        for (const [k, entries] of data.clubMembers) {
          this.clubMembers.set(k, new Set(entries));
        }
      }
      return this.users.size > 0;
    } catch (e) {
      console.error('[Store] Failed to load from disk backup:', e);
      return false;
    }
  }

  private seedCommunity() {
    const communityAthletes: Array<{ id: string; handle: string; name: string; sport: string; pts: number }> = [
      { id: 'ath_aarav', handle: 'aarav_runner', name: 'Aarav Sharma', sport: 'run', pts: 2450 },
      { id: 'ath_priya', handle: 'priya_fitsoul', name: 'Priya Patel', sport: 'yoga', pts: 1890 },
      { id: 'ath_rohit', handle: 'rohit_pedals', name: 'Rohit Kumar', sport: 'ride', pts: 1620 },
      { id: 'ath_ananya', handle: 'ananya_runs', name: 'Ananya Iyer', sport: 'run', pts: 1240 },
      { id: 'ath_kabir', handle: 'kabir_lifts', name: 'Kabir Singh', sport: 'other', pts: 980 },
      { id: 'ath_neha', handle: 'neha_walks', name: 'Neha Verma', sport: 'walk', pts: 720 },
    ];

    const alltimeBoard = this.scores.get('alltime') ?? new Map<string, number>();
    const currentWeekKey = new Date().toISOString().slice(0, 10);
    const weekBoard = this.scores.get(currentWeekKey) ?? new Map<string, number>();

    for (const ath of communityAthletes) {
      if (!this.users.has(ath.id)) {
        this.users.set(ath.id, {
          id: ath.id,
          displayHandle: ath.handle,
          name: ath.name,
          email: `${ath.handle}@vyra.app`,
          dob: '1998-04-12',
          gender: 'prefer-not-to-say',
          heightCm: 172,
          weightKg: 68,
          disabilityFlag: false,
          accessibilityMode: false,
          fitnessGoal: 'maintain',
          dietToggle: true,
          dietPreference: 'veg_no_egg',
          primarySport: ath.sport,
          dmPrivacy: 'following',
          accountStatus: 'active',
          onboardingStep: 9,
          createdAt: new Date(Date.now() - 30 * 86_400_000).toISOString(),
        });
      }
      alltimeBoard.set(ath.id, ath.pts);
      weekBoard.set(ath.id, Math.round(ath.pts * 0.45));

      // Seed community activity if none exist
      const actId = `act_${ath.id}_seed`;
      if (!this.activities.has(actId)) {
        this.activities.set(actId, {
          id: actId,
          userId: ath.id,
          type: (ath.sport === 'run' ? 'run' : ath.sport === 'ride' ? 'ride' : 'walk') as 'run' | 'ride' | 'walk',
          title: ath.sport === 'run' ? 'Morning 5K Pace Run' : ath.sport === 'ride' ? 'Coastline Sunrise Ride' : 'Brisk Park Walk',
          distanceM: ath.sport === 'run' ? 5120 : ath.sport === 'ride' ? 14200 : 3400,
          durationSec: ath.sport === 'run' ? 1680 : ath.sport === 'ride' ? 2400 : 2100,
          route: [
            { lat: 12.9716, lng: 77.5946, t: 0 },
            { lat: 12.9730, lng: 77.5960, t: 600 },
            { lat: 12.9750, lng: 77.5980, t: 1200 },
          ],
          startedAt: new Date(Date.now() - 4 * 3600_000).toISOString(),
          createdAt: new Date(Date.now() - 4 * 3600_000).toISOString(),
        });
      }
    }

    this.scores.set('alltime', alltimeBoard);
    this.scores.set(currentWeekKey, weekBoard);
  }

  constructor() {
    // Try restoring state from persistent disk backup first
    const hasData = this.loadFromDisk();

    // Always seed community athletes and baseline activities
    this.seedCommunity();

    // A handful of seed clubs/events so Groups is never an empty screen on a
    // fresh install — the same reasoning as the 46-item exercise library.
    const seedClubs: Array<[string, string, string]> = [
      ['Morning Runners', 'Early risers who log a run before the day starts.', 'running'],
      ['Yoga Practitioners', 'Daily asana practice, all levels welcome.', 'yoga'],
      ['Weekend Cyclists', 'Long rides on Saturdays, easy pace on Sundays.', 'cycling'],
    ];
    for (const [name, description, interestTag] of seedClubs) {
      const id = `club_${Math.random().toString(36).slice(2, 10)}`;
      if (!this.clubs.has(id)) {
        this.clubs.set(id, { id, name, description, interestTag, memberCount: 12 });
      }
    }

    const inSevenDays = new Date(Date.now() + 7 * 86_400_000).toISOString();
    const inThreeDays = new Date(Date.now() + 3 * 86_400_000).toISOString();
    const seedEvents: Array<[string, string, string, string]> = [
      ['VYRA 5K Challenge', 'run', 'Citywide — track anywhere', inSevenDays],
      ['Sunday Long Ride', 'ride', 'Local cycling group meetup', inThreeDays],
    ];
    for (const [title, sport, location, startsAt] of seedEvents) {
      const id = `event_${Math.random().toString(36).slice(2, 10)}`;
      if (!this.events.has(id)) {
        this.events.set(id, { id, title, sport, location, startsAt, clubId: null });
      }
    }

    for (const def of MOVEMENT_DEFINITIONS) {
      this.movementDefinitions.set(def.exerciseSlug, def);
    }
  }

  private key(userId: string, date: string) { return `${userId}:${date}`; }

  async createUser(u: Omit<StoredUser, 'createdAt'>): Promise<StoredUser> {
    const user: StoredUser = { ...u, createdAt: new Date().toISOString() };
    this.users.set(user.id, user);
    this.persistDebounced();
    return user;
  }

  async getUser(id: string) { return this.users.get(id) ?? null; }

  async updateUser(id: string, patch: Partial<StoredUser>) {
    const existing = this.users.get(id);
    if (!existing) throw new Error(`User ${id} not found`);
    const updated = { ...existing, ...patch };
    this.users.set(id, updated);
    this.persistDebounced();
    return updated;
  }

  async setSchedule(userId: string, blocks: RawBlock[]) {
    this.schedules.set(userId, blocks);
    this.persistDebounced();
  }
  async getSchedule(userId: string) { return this.schedules.get(userId) ?? []; }

  async upsertPlan(plan: StoredPlan) {
    this.plans.set(this.key(plan.userId, plan.planDate), plan);
    this.persistDebounced();
    return plan;
  }

  async getPlan(userId: string, date: ISODate) {
    return this.plans.get(this.key(userId, date)) ?? null;
  }

  async listPlans(userId: string, from: ISODate, to: ISODate) {
    return [...this.plans.values()]
      .filter((p) => p.userId === userId && p.planDate >= from && p.planDate <= to)
      .sort((a, b) => a.planDate.localeCompare(b.planDate));
  }

  async upsertTracking(rec: StoredTracking) {
    const existing = this.tracking.get(this.key(rec.userId, rec.recordDate));
    // Merge rather than replace: logging water at noon must not erase this
    // morning's weight entry.
    const merged: StoredTracking = existing
      ? { ...existing, ...rec, encrypted: { ...existing.encrypted, ...rec.encrypted } }
      : rec;
    this.tracking.set(this.key(rec.userId, rec.recordDate), merged);
    this.persistDebounced();
    return merged;
  }

  async getTracking(userId: string, date: ISODate) {
    return this.tracking.get(this.key(userId, date)) ?? null;
  }

  async listTracking(userId: string, from: ISODate, to: ISODate) {
    return [...this.tracking.values()]
      .filter((t) => t.userId === userId && t.recordDate >= from && t.recordDate <= to)
      .sort((a, b) => a.recordDate.localeCompare(b.recordDate));
  }

  async setSugar(userId: string, date: ISODate, grams: number) {
    this.sugar.set(this.key(userId, date), grams);
    this.persistDebounced();
  }

  async getSugar(userId: string, date: ISODate) {
    return this.sugar.get(this.key(userId, date)) ?? null;
  }

  async listSugar(userId: string, from: ISODate, to: ISODate) {
    return [...this.sugar.entries()]
      .filter(([k]) => k.startsWith(`${userId}:`))
      .map(([k, grams]) => ({ date: k.split(':')[1]!, grams }))
      .filter((r) => r.date >= from && r.date <= to)
      .sort((a, b) => a.date.localeCompare(b.date));
  }

  async appendLedger(userId: string, row: LedgerRow) {
    const rows = this.ledgers.get(userId) ?? [];
    rows.push(row);
    this.ledgers.set(userId, rows);
    this.persistDebounced();
  }

  async listLedger(userId: string) { return this.ledgers.get(userId) ?? []; }

  async listLedgerForDate(userId: string, date: ISODate) {
    return (this.ledgers.get(userId) ?? []).filter((r) => r.createdAt.slice(0, 10) === date);
  }

  async recordConsent(userId: string, consentType: string, granted: boolean, ipHash: string, policyVersion: string) {
    const rows = this.consents.get(userId) ?? [];
    // Append-only: a withdrawal is a new row, never an update. The full history
    // must remain reconstructable for a DPDP audit.
    rows.push({ consentType, granted, ipHash, policyVersion, updatedAt: new Date().toISOString() });
    this.consents.set(userId, rows);
  }

  async currentConsents(userId: string) {
    const rows = this.consents.get(userId) ?? [];
    const latest = new Map<string, { consentType: string; granted: boolean; updatedAt: string }>();
    for (const r of rows) latest.set(r.consentType, r);
    return [...latest.values()];
  }

  async leaderboard(period: string, limit: number) {
    let board = this.scores.get(period);
    if (!board || board.size === 0) {
      board = this.scores.get('alltime') ?? new Map();
    }
    return [...board.entries()]
      .map(([userId, points]) => ({
        userId,
        handle: this.users.get(userId)?.displayHandle ?? 'athlete',
        points,
      }))
      .sort((a, b) => b.points - a.points)
      .slice(0, limit);
  }

  async setLeaderboardScore(userId: string, period: string, points: number) {
    const board = this.scores.get(period) ?? new Map<string, number>();
    board.set(userId, points);
    this.scores.set(period, board);
    this.persistDebounced();
  }

  async eraseUser(userId: string) {
    this.users.delete(userId);
    this.schedules.delete(userId);
    this.ledgers.delete(userId);
    this.consents.delete(userId);
    for (const map of [this.plans, this.tracking]) {
      for (const k of [...map.keys()]) if (k.startsWith(`${userId}:`)) map.delete(k);
    }
    for (const k of [...this.sugar.keys()]) if (k.startsWith(`${userId}:`)) this.sugar.delete(k);
    for (const board of this.scores.values()) board.delete(userId);
    this.persistDebounced();
  }

  // ---------------------------------------------------------------------------
  // Activities / feed
  // ---------------------------------------------------------------------------

  async createActivity(a: Omit<StoredActivity, 'createdAt'>): Promise<StoredActivity> {
    const activity: StoredActivity = { ...a, createdAt: new Date().toISOString() };
    this.activities.set(activity.id, activity);
    this.persistDebounced();
    return activity;
  }

  async getActivity(id: string) { return this.activities.get(id) ?? null; }

  async listUserActivities(userId: string, limit: number) {
    return [...this.activities.values()]
      .filter((a) => a.userId === userId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, limit);
  }

  async listFeed(userId: string, limit: number) {
    const authors = new Set([userId, ...(this.following.get(userId) ?? [])]);
    const items = [...this.activities.values()]
      .filter((a) => authors.has(a.userId))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, limit);
    // Never leave feed empty if community activities exist
    if (items.length === 0) {
      return [...this.activities.values()]
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
        .slice(0, limit);
    }
    return items;
  }

  async toggleKudos(activityId: string, userId: string) {
    const set = this.kudos.get(activityId) ?? new Set<string>();
    const given = !set.has(userId);
    if (given) set.add(userId); else set.delete(userId);
    this.kudos.set(activityId, set);
    return { given, count: set.size };
  }

  async hasKudos(activityId: string, userId: string) {
    return this.kudos.get(activityId)?.has(userId) ?? false;
  }

  async addComment(activityId: string, userId: string, text: string) {
    const comment: StoredComment = {
      id: `c_${Math.random().toString(36).slice(2, 10)}`,
      activityId, userId, text,
      createdAt: new Date().toISOString(),
    };
    const rows = this.comments.get(activityId) ?? [];
    rows.push(comment);
    this.comments.set(activityId, rows);
    return comment;
  }

  async listComments(activityId: string) {
    return this.comments.get(activityId) ?? [];
  }

  // ---------------------------------------------------------------------------
  // Follow graph
  // ---------------------------------------------------------------------------

  async follow(userId: string, targetId: string) {
    if (userId === targetId) return;
    const set = this.following.get(userId) ?? new Set<string>();
    set.add(targetId);
    this.following.set(userId, set);
  }

  async unfollow(userId: string, targetId: string) {
    this.following.get(userId)?.delete(targetId);
  }

  async isFollowing(userId: string, targetId: string) {
    return this.following.get(userId)?.has(targetId) ?? false;
  }

  async listFollowing(userId: string) {
    const ids = this.following.get(userId) ?? new Set<string>();
    return [...ids].map((id) => this.users.get(id)).filter((u): u is StoredUser => !!u);
  }

  async listFollowers(userId: string) {
    return [...this.following.entries()]
      .filter(([, targets]) => targets.has(userId))
      .map(([followerId]) => this.users.get(followerId))
      .filter((u): u is StoredUser => !!u);
  }

  async searchUsers(query: string, excludeUserId: string, limit: number) {
    const q = query.trim().toLowerCase();
    return [...this.users.values()]
      .filter((u) => u.id !== excludeUserId)
      .filter((u) => !q || u.name.toLowerCase().includes(q) || u.displayHandle.toLowerCase().includes(q))
      .slice(0, limit);
  }

  // ---------------------------------------------------------------------------
  // Beacon — safety location sharing
  // ---------------------------------------------------------------------------

  async setBeacon(userId: string, enabled: boolean, contacts: BeaconContact[]) {
    this.beacons.set(userId, { enabled, contacts });
  }

  async getBeacon(userId: string) {
    return this.beacons.get(userId) ?? { enabled: false, contacts: [] };
  }

  // ---------------------------------------------------------------------------
  // Clubs
  // ---------------------------------------------------------------------------

  async listClubs() { return [...this.clubs.values()]; }
  async getClub(id: string) { return this.clubs.get(id) ?? null; }

  async isClubMember(clubId: string, userId: string) {
    return this.clubMembers.get(clubId)?.has(userId) ?? false;
  }

  async joinClub(clubId: string, userId: string) {
    const set = this.clubMembers.get(clubId) ?? new Set<string>();
    if (!set.has(userId)) {
      set.add(userId);
      this.clubMembers.set(clubId, set);
      const club = this.clubs.get(clubId);
      if (club) this.clubs.set(clubId, { ...club, memberCount: club.memberCount + 1 });
    }
  }

  async leaveClub(clubId: string, userId: string) {
    const set = this.clubMembers.get(clubId);
    if (set?.delete(userId)) {
      const club = this.clubs.get(clubId);
      if (club) this.clubs.set(clubId, { ...club, memberCount: Math.max(0, club.memberCount - 1) });
    }
  }

  async listClubPosts(clubId: string) {
    return (this.clubPosts.get(clubId) ?? []).slice().reverse();
  }

  async addClubPost(clubId: string, userId: string, body: string) {
    const post: StoredClubPost = {
      id: `post_${Math.random().toString(36).slice(2, 10)}`,
      clubId, userId, body,
      createdAt: new Date().toISOString(),
    };
    const rows = this.clubPosts.get(clubId) ?? [];
    rows.push(post);
    this.clubPosts.set(clubId, rows);
    return post;
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  async listEvents() {
    return [...this.events.values()].sort((a, b) => a.startsAt.localeCompare(b.startsAt));
  }

  async isRegisteredForEvent(eventId: string, userId: string) {
    return this.eventRegistrations.get(eventId)?.has(userId) ?? false;
  }

  async registerForEvent(eventId: string, userId: string) {
    const set = this.eventRegistrations.get(eventId) ?? new Set<string>();
    set.add(userId);
    this.eventRegistrations.set(eventId, set);
  }

  async unregisterFromEvent(eventId: string, userId: string) {
    this.eventRegistrations.get(eventId)?.delete(userId);
  }

  // ---------------------------------------------------------------------------
  // Direct messaging
  // ---------------------------------------------------------------------------

  async getOrCreateConversation(userA: string, userB: string) {
    const existing = [...this.conversations.values()].find((c) => {
      const ids = c.participantIds;
      return ids.length === 2 && ids.includes(userA) && ids.includes(userB);
    });
    if (existing) return existing;

    const conversation: StoredConversation = {
      id: `conv_${Math.random().toString(36).slice(2, 10)}`,
      participantIds: [userA, userB],
      createdAt: new Date().toISOString(),
    };
    this.conversations.set(conversation.id, conversation);
    return conversation;
  }

  async listConversations(userId: string) {
    return [...this.conversations.values()].filter((c) => c.participantIds.includes(userId));
  }

  async getConversation(id: string) { return this.conversations.get(id) ?? null; }

  async listMessages(conversationId: string, limit: number) {
    return (this.messages.get(conversationId) ?? []).slice(-limit);
  }

  async sendMessage(conversationId: string, senderId: string, body: string) {
    const message: StoredMessage = {
      id: `msg_${Math.random().toString(36).slice(2, 10)}`,
      conversationId, senderId, body,
      createdAt: new Date().toISOString(),
    };
    const rows = this.messages.get(conversationId) ?? [];
    rows.push(message);
    this.messages.set(conversationId, rows);
    return message;
  }

  // ---------------------------------------------------------------------------
  // AI fitness chat
  // ---------------------------------------------------------------------------

  async appendChatMessage(userId: string, role: 'user' | 'assistant', body: string) {
    const message: StoredChatMessage = {
      id: `chat_${Math.random().toString(36).slice(2, 10)}`,
      userId, role, body,
      createdAt: new Date().toISOString(),
    };
    const rows = this.chatMessages.get(userId) ?? [];
    rows.push(message);
    this.chatMessages.set(userId, rows);
    this.persistDebounced();
    return message;
  }

  async listChatHistory(userId: string, limit: number) {
    return (this.chatMessages.get(userId) ?? []).slice(-limit);
  }

  async clearChatHistory(userId: string) {
    this.chatMessages.delete(userId);
    this.persistDebounced();
  }

  // ---------------------------------------------------------------------------
  // Password auth
  // ---------------------------------------------------------------------------

  async getUserByEmail(email: string) {
    const target = email.trim().toLowerCase();
    for (const user of this.users.values()) {
      if (user.email?.trim().toLowerCase() === target) return user;
    }
    return null;
  }

  async setPasswordHash(userId: string, hash: string) {
    this.passwordHashes.set(userId, hash);
  }

  async getPasswordHash(userId: string) {
    return this.passwordHashes.get(userId) ?? null;
  }

  // ---------------------------------------------------------------------------
  // Auth identities (Google/Facebook)
  // ---------------------------------------------------------------------------

  async linkAuthIdentity(userId: string, provider: string, providerUid: string) {
    this.authIdentities.set(`${provider}:${providerUid}`, userId);
  }

  async getUserByAuthIdentity(provider: string, providerUid: string) {
    const userId = this.authIdentities.get(`${provider}:${providerUid}`);
    return userId ? (this.users.get(userId) ?? null) : null;
  }

  // ---------------------------------------------------------------------------
  // Reports & blocks
  // ---------------------------------------------------------------------------

  async createReport(r: { reporterId: string; targetType: ReportTargetType; targetId: string;
    reason: ReportReason; detail?: string }) {
    const report: StoredReport = {
      id: `report_${Math.random().toString(36).slice(2, 10)}`,
      ...r,
      status: 'pending',
      createdAt: new Date().toISOString(),
    };
    this.reports.set(report.id, report);
    return report;
  }

  async listReports(status?: ReportStatus) {
    const rows = [...this.reports.values()];
    const filtered = status ? rows.filter((r) => r.status === status) : rows;
    return filtered.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  async getReport(id: string) { return this.reports.get(id) ?? null; }

  async resolveReport(id: string, adminId: string, status: ReportStatus, resolution?: string) {
    const report = this.reports.get(id);
    if (!report) throw new Error(`Report ${id} not found`);
    const updated: StoredReport = {
      ...report, status, resolvedBy: adminId, resolution,
      resolvedAt: new Date().toISOString(),
    };
    this.reports.set(id, updated);
    return updated;
  }

  async blockUser(blockerId: string, blockedId: string) {
    const set = this.blocks.get(blockerId) ?? new Set<string>();
    set.add(blockedId);
    this.blocks.set(blockerId, set);
    await this.unfollow(blockerId, blockedId);
    await this.unfollow(blockedId, blockerId);
  }

  async unblockUser(blockerId: string, blockedId: string) {
    this.blocks.get(blockerId)?.delete(blockedId);
  }

  async isBlocked(blockerId: string, blockedId: string) {
    return this.blocks.get(blockerId)?.has(blockedId) ?? false;
  }

  async listBlocked(blockerId: string) {
    const ids = this.blocks.get(blockerId) ?? new Set<string>();
    return [...ids].map((id) => this.users.get(id)).filter((u): u is StoredUser => !!u);
  }

  // ---------------------------------------------------------------------------
  // Admin accounts
  // ---------------------------------------------------------------------------

  async createAdmin(a: Omit<StoredAdmin, 'createdAt'>) {
    const admin: StoredAdmin = { ...a, createdAt: new Date().toISOString() };
    this.admins.set(admin.id, admin);
    return admin;
  }

  async getAdminByEmail(email: string) {
    const target = email.trim().toLowerCase();
    for (const admin of this.admins.values()) {
      if (admin.email.trim().toLowerCase() === target) return admin;
    }
    return null;
  }

  async getAdmin(id: string) { return this.admins.get(id) ?? null; }
  async listAdmins() { return [...this.admins.values()]; }

  async setAdminPasswordHash(adminId: string, hash: string) {
    this.adminPasswordHashes.set(adminId, hash);
  }

  async getAdminPasswordHash(adminId: string) {
    return this.adminPasswordHashes.get(adminId) ?? null;
  }

  // ---------------------------------------------------------------------------
  // Platform-wide moderation & operations
  // ---------------------------------------------------------------------------

  async setAccountStatus(userId: string, status: AccountStatus) {
    const user = this.users.get(userId);
    if (user) this.users.set(userId, { ...user, accountStatus: status });
  }

  async listUsersForAdmin(limit: number, offset: number, query?: string) {
    const q = query?.trim().toLowerCase();
    const rows = [...this.users.values()]
      .filter((u) => !q || u.name.toLowerCase().includes(q) ||
        u.displayHandle.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q));
    return rows.slice(offset, offset + limit);
  }

  async countUsers() { return this.users.size; }

  async appendAuditLog(entry: Omit<AuditEntry, 'createdAt'>) {
    this.auditLog.push({ ...entry, createdAt: new Date().toISOString() });
  }

  async listAuditLog(limit: number) {
    return this.auditLog.slice(-limit).reverse();
  }

  // ---------------------------------------------------------------------------
  // Movement definitions — 3D exercise avatar system
  // ---------------------------------------------------------------------------

  async getMovementDefinition(exerciseSlug: string) {
    return this.movementDefinitions.get(exerciseSlug) ?? null;
  }

  async upsertMovementDefinition(def: MovementDefinition) {
    this.movementDefinitions.set(def.exerciseSlug, def);
    return def;
  }

  async listMovementDefinitions() {
    return [...this.movementDefinitions.values()];
  }

  async health() {
    return { ok: true, backend: 'memory', detail: `${this.users.size} users in memory` };
  }
}
