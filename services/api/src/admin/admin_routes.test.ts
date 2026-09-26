import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { Router, type Ctx } from '../http/router';
import { MemoryStore } from '../store';
import { registerAdminPortalRoutes } from './admin_routes';
import { ADMIN_DASHBOARD_HTML } from './admin_dashboard_html';

describe('VYRA Enterprise Web Admin Portal', () => {
  const store = new MemoryStore();
  const router = new Router();
  registerAdminPortalRoutes(router, store);

  function mockCtx(method: string, path: string, body?: unknown, queryParams?: Record<string, string>): { ctx: Ctx; written: { status?: number; data?: string } } {
    const written: { status?: number; data?: string } = {};
    const res = {
      setHeader: () => {},
      writeHead: (status: number) => {
        written.status = status;
        return {
          end: (data: string) => {
            written.data = data;
          }
        };
      },
      end: (data: string) => {
        written.data = data;
      }
    } as any;

    const query = new URLSearchParams(queryParams ?? {});

    const ctx: Ctx = {
      req: { method, url: path } as any,
      res,
      params: {},
      query,
      body: body ?? null,
      requestId: 'test-req-1',
      ip: '127.0.0.1',
    };

    return { ctx, written };
  }

  it('serves high-density obsidian single page admin dashboard at /admin', async () => {
    assert.ok(ADMIN_DASHBOARD_HTML.length > 500);
    assert.ok(ADMIN_DASHBOARD_HTML.includes('Admin Console'));
    assert.ok(ADMIN_DASHBOARD_HTML.includes('Command Center'));
    assert.ok(ADMIN_DASHBOARD_HTML.includes('e-RaktKosh'));
    assert.ok(ADMIN_DASHBOARD_HTML.includes('AI Biomechanical Kinematics'));
  });

  it('provides real-time operational telemetry and KPIs at /v1/admin/overview', async () => {
    const matched = (router as any).match('GET', '/v1/admin/overview');
    assert.ok(matched, 'Overview route registered');

    const { ctx } = mockCtx('GET', '/v1/admin/overview');
    ctx.params = matched.params;
    const result = await matched.route.handler(ctx);

    assert.ok(result.kpi.activeAthletes >= 8000, 'Active athletes count');
    assert.ok(result.kpi.workoutsCompletedToday > 1000, 'Workouts completed today');
    assert.ok(result.system.databaseOk, 'Database health status ok');
    assert.ok(result.featureFlags.pose_tracking, 'Feature flags included');
  });

  it('toggles dynamic feature flags remotely via /v1/admin/feature-flags/toggle', async () => {
    const matched = (router as any).match('POST', '/v1/admin/feature-flags/toggle');
    assert.ok(matched, 'Toggle route registered');

    const { ctx } = mockCtx('POST', '/v1/admin/feature-flags/toggle', { key: 'pose_tracking', value: false });
    ctx.params = matched.params;
    const res = await matched.route.handler(ctx);

    assert.strictEqual(res.ok, true);
    assert.strictEqual(res.enabled, false);

    // Toggle back
    const { ctx: ctx2 } = mockCtx('POST', '/v1/admin/feature-flags/toggle', { key: 'pose_tracking', value: true });
    ctx2.params = matched.params;
    const res2 = await matched.route.handler(ctx2);
    assert.strictEqual(res2.enabled, true);
  });

  it('manages e-RaktKosh national blood bank appeals', async () => {
    const matchedCreate = (router as any).match('POST', '/v1/admin/blood-network/appeal');
    assert.ok(matchedCreate, 'Blood appeal create route registered');

    const { ctx } = mockCtx('POST', '/v1/admin/blood-network/appeal', {
      hospitalName: 'AIIMS Trauma Centre',
      city: 'New Delhi',
      bloodGroup: 'AB-',
      unitsNeeded: 3,
      urgency: 'CRITICAL',
      patientCase: 'Emergency polytrauma',
      contactPhone: '+91 98111 22233'
    });
    ctx.params = matchedCreate.params;

    const createRes = await matchedCreate.route.handler(ctx);
    assert.strictEqual(createRes.ok, true);
    assert.strictEqual(createRes.appeal.hospitalName, 'AIIMS Trauma Centre');
    assert.strictEqual(createRes.appeal.status, 'ACTIVE');

    // Fulfill appeal
    const matchedFulfill = (router as any).match('POST', `/v1/admin/blood-network/appeal/${createRes.appeal.id}/fulfill`);
    assert.ok(matchedFulfill, 'Fulfill route registered');

    const { ctx: fulfillCtx } = mockCtx('POST', `/v1/admin/blood-network/appeal/${createRes.appeal.id}/fulfill`);
    fulfillCtx.params = matchedFulfill.params;
    const fulfillRes = await matchedFulfill.route.handler(fulfillCtx);
    assert.strictEqual(fulfillRes.appeal.status, 'FULFILLED');
  });

  it('searches 100+ exercise kinematics registry with joint flexion angles', async () => {
    const matched = (router as any).match('GET', '/v1/admin/exercises');
    assert.ok(matched, 'Exercises route registered');

    const { ctx } = mockCtx('GET', '/v1/admin/exercises', null, { q: 'squat' });
    ctx.params = matched.params;
    const result = await matched.route.handler(ctx);

    assert.ok(result.exercises.length > 0);
    const squat = result.exercises[0];
    assert.ok(squat.kinematics.optimalFlexionDeg, 'Flexion target present');
    assert.ok(squat.kinematics.tempo, 'Kinematic tempo present');
    assert.ok(squat.breathingPattern, 'Breathing pattern present');
  });

  it('manages athlete profiles and awards bonus coins', async () => {
    const matched = (router as any).match('POST', '/v1/admin/athletes/usr-ayush/reward');
    assert.ok(matched, 'Reward route registered');

    const { ctx } = mockCtx('POST', '/v1/admin/athletes/usr-ayush/reward', { bonusCoins: 500 });
    ctx.params = matched.params;
    const res = await matched.route.handler(ctx);

    assert.strictEqual(res.ok, true);
    assert.ok(res.athlete.coins >= 1950);
  });

  it('allows resolving and replying to athlete support tickets', async () => {
    const matched = (router as any).match('POST', '/v1/admin/tickets/TCK-8813/reply');
    assert.ok(matched, 'Ticket reply route registered');

    const { ctx } = mockCtx('POST', '/v1/admin/tickets/TCK-8813/reply', {
      replyText: 'Your verified donor badge has been credited to your profile.',
      status: 'RESOLVED'
    });
    ctx.params = matched.params;
    const res = await matched.route.handler(ctx);

    assert.strictEqual(res.ok, true);
    assert.strictEqual(res.ticket.status, 'RESOLVED');
  });
});
