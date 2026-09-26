/**
 * =============================================================================
 * VYRA ATHLETE 3D WEB PORTAL — Router & Controller
 * =============================================================================
 * Serves the Grand-Level 3D Web User Portal at:
 *   - GET /portal
 *   - GET /athlete
 *   - GET /user
 * =============================================================================
 */

import type { Router, Ctx } from '../http/router';
import { ATHLETE_PORTAL_HTML } from './athlete_portal_html';

export function registerAthletePortalRoutes(router: Router): void {
  router.get('/', async (ctx: Ctx) => {
    ctx.res.setHeader('Content-Type', 'text/html; charset=utf-8');
    ctx.res.writeHead(200).end(ATHLETE_PORTAL_HTML);
  });

  router.get('/portal', async (ctx: Ctx) => {
    ctx.res.setHeader('Content-Type', 'text/html; charset=utf-8');
    ctx.res.writeHead(200).end(ATHLETE_PORTAL_HTML);
  });

  router.get('/athlete', async (ctx: Ctx) => {
    ctx.res.setHeader('Content-Type', 'text/html; charset=utf-8');
    ctx.res.writeHead(200).end(ATHLETE_PORTAL_HTML);
  });

  router.get('/user', async (ctx: Ctx) => {
    ctx.res.setHeader('Content-Type', 'text/html; charset=utf-8');
    ctx.res.writeHead(200).end(ATHLETE_PORTAL_HTML);
  });
}
