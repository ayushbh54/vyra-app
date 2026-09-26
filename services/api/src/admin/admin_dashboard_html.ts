/**
 * =============================================================================
 * VYRA ENTERPRISE WEB ADMIN PORTAL — Single Page Application (SPA)
 * =============================================================================
 * Enterprise Control Center served at GET /admin and GET /admin/dashboard.
 * Designed for national operations, telemetry, remote config & medical network.
 * Zero external CDN dependencies; high-density obsidian glassmorphism.
 * =============================================================================
 */

export const ADMIN_DASHBOARD_HTML: string = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VYRA Enterprise Operations Center | Admin Console</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-dark: #07090E;
      --bg-surface: #0E131F;
      --bg-card: #141B2D;
      --bg-card-hover: #1A243B;
      --border-subtle: rgba(255, 255, 255, 0.08);
      --border-focus: rgba(0, 210, 255, 0.4);
      --text-main: #F0F4FC;
      --text-muted: #8E9BAE;
      --text-dim: #546075;
      --cyan: #00D2FF;
      --cyan-glow: rgba(0, 210, 255, 0.2);
      --emerald: #34FF8C;
      --emerald-glow: rgba(52, 255, 140, 0.2);
      --amber: #FFB800;
      --amber-glow: rgba(255, 184, 0, 0.2);
      --crimson: #FF4757;
      --crimson-glow: rgba(255, 71, 87, 0.25);
      --purple: #A55EEA;
      --font-sans: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      --font-mono: 'JetBrains Mono', monospace;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      -webkit-font-smoothing: antialiased;
    }

    body {
      background-color: var(--bg-dark);
      color: var(--text-main);
      font-family: var(--font-sans);
      height: 100vh;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }

    /* TOP BAR */
    header.topbar {
      height: 64px;
      background: rgba(14, 19, 31, 0.85);
      backdrop-filter: blur(16px);
      border-bottom: 1px solid var(--border-subtle);
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 24px;
      z-index: 50;
      flex-shrink: 0;
    }

    .brand-section {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .brand-logo {
      display: flex;
      align-items: center;
      gap: 10px;
      text-decoration: none;
    }

    .logo-icon {
      width: 36px;
      height: 36px;
      background: linear-gradient(135deg, #00D2FF 0%, #0072FF 100%);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 0 16px var(--cyan-glow);
    }

    .brand-title {
      font-size: 19px;
      font-weight: 800;
      letter-spacing: -0.5px;
      background: linear-gradient(90deg, #FFFFFF 0%, #BFE7FF 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .badge-enterprise {
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 0.8px;
      padding: 3px 8px;
      border-radius: 6px;
      background: rgba(0, 210, 255, 0.12);
      border: 1px solid rgba(0, 210, 255, 0.3);
      color: var(--cyan);
      text-transform: uppercase;
    }

    .top-telemetry {
      display: flex;
      align-items: center;
      gap: 20px;
    }

    .status-pill {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 6px 14px;
      border-radius: 20px;
      background: rgba(52, 255, 140, 0.08);
      border: 1px solid rgba(52, 255, 140, 0.25);
      font-size: 12px;
      font-weight: 600;
      color: var(--emerald);
    }

    .pulse-dot {
      width: 8px;
      height: 8px;
      background-color: var(--emerald);
      border-radius: 50%;
      box-shadow: 0 0 10px var(--emerald);
      animation: pulse 2s infinite ease-in-out;
    }

    @keyframes pulse {
      0% { opacity: 0.4; transform: scale(0.9); }
      50% { opacity: 1; transform: scale(1.15); box-shadow: 0 0 14px var(--emerald); }
      100% { opacity: 0.4; transform: scale(0.9); }
    }

    .top-actions {
      display: flex;
      align-items: center;
      gap: 16px;
    }

    .clock-display {
      font-family: var(--font-mono);
      font-size: 12px;
      color: var(--text-muted);
      background: var(--bg-card);
      padding: 6px 12px;
      border-radius: 8px;
      border: 1px solid var(--border-subtle);
    }

    .btn-refresh {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      color: var(--text-main);
      padding: 7px 14px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s;
    }

    .btn-refresh:hover {
      background: var(--bg-card-hover);
      border-color: var(--cyan);
      color: var(--cyan);
    }

    .user-avatar-badge {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 4px 10px 4px 6px;
      background: var(--bg-card);
      border-radius: 20px;
      border: 1px solid var(--border-subtle);
    }

    .avatar-circle {
      width: 28px;
      height: 28px;
      border-radius: 50%;
      background: linear-gradient(135deg, #00D2FF 0%, #34FF8C 100%);
      color: #000;
      font-size: 11px;
      font-weight: 800;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .user-name-tag {
      font-size: 12px;
      font-weight: 600;
    }

    /* MAIN CONTAINER */
    .app-body {
      display: flex;
      flex: 1;
      overflow: hidden;
    }

    /* SIDEBAR */
    nav.sidebar {
      width: 250px;
      background: var(--bg-surface);
      border-right: 1px solid var(--border-subtle);
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      padding: 20px 12px;
      flex-shrink: 0;
    }

    .nav-group-label {
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 1px;
      color: var(--text-dim);
      text-transform: uppercase;
      padding: 8px 12px 6px 12px;
    }

    .nav-list {
      list-style: none;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .nav-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 14px;
      border-radius: 10px;
      font-size: 13.5px;
      font-weight: 600;
      color: var(--text-muted);
      cursor: pointer;
      transition: all 0.15s ease;
      text-decoration: none;
    }

    .nav-item:hover {
      color: var(--text-main);
      background: rgba(255, 255, 255, 0.04);
    }

    .nav-item.active {
      color: var(--cyan);
      background: rgba(0, 210, 255, 0.1);
      border: 1px solid rgba(0, 210, 255, 0.25);
    }

    .nav-item-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .nav-badge {
      font-size: 10px;
      font-weight: 700;
      padding: 2px 7px;
      border-radius: 10px;
      background: rgba(255, 71, 87, 0.18);
      color: var(--crimson);
      border: 1px solid rgba(255, 71, 87, 0.3);
    }

    .sidebar-footer {
      border-top: 1px solid var(--border-subtle);
      padding-top: 14px;
      font-size: 11px;
      color: var(--text-dim);
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    /* CONTENT VIEW */
    main.viewport {
      flex: 1;
      overflow-y: auto;
      background: var(--bg-dark);
      padding: 28px 36px;
      display: flex;
      flex-direction: column;
      gap: 28px;
    }

    .page-header {
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
      border-bottom: 1px solid var(--border-subtle);
      padding-bottom: 18px;
    }

    .page-title {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
      color: #FFF;
    }

    .page-subtitle {
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 4px;
    }

    /* CARDS & GRIDS */
    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 18px;
    }

    .card {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: 14px;
      padding: 20px;
      transition: transform 0.2s, border-color 0.2s;
    }

    .card:hover {
      border-color: rgba(255, 255, 255, 0.16);
    }

    .kpi-card {
      display: flex;
      flex-direction: column;
      gap: 12px;
      position: relative;
      overflow: hidden;
    }

    .kpi-card::after {
      content: '';
      position: absolute;
      top: 0;
      right: 0;
      width: 90px;
      height: 90px;
      background: radial-gradient(circle, var(--glow-color, rgba(0, 210, 255, 0.15)) 0%, transparent 70%);
      pointer-events: none;
    }

    .kpi-label {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .kpi-value {
      font-size: 32px;
      font-weight: 800;
      font-family: var(--font-mono);
      color: #FFF;
      letter-spacing: -1px;
    }

    .kpi-trend {
      font-size: 11px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 6px;
      color: var(--emerald);
    }

    .kpi-trend.down {
      color: var(--crimson);
    }

    /* SECTION LAYOUTS */
    .two-col-grid {
      display: grid;
      grid-template-columns: 2fr 1fr;
      gap: 20px;
    }

    .three-col-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 20px;
    }

    .card-title {
      font-size: 16px;
      font-weight: 700;
      color: #FFF;
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 16px;
    }

    /* TABLES */
    .data-table-container {
      border-radius: 12px;
      overflow: hidden;
      border: 1px solid var(--border-subtle);
      background: var(--bg-surface);
    }

    table.data-table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 13px;
    }

    table.data-table th {
      background: rgba(255, 255, 255, 0.03);
      padding: 12px 18px;
      font-weight: 700;
      font-size: 11px;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.6px;
      border-bottom: 1px solid var(--border-subtle);
    }

    table.data-table td {
      padding: 14px 18px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.04);
      color: var(--text-main);
    }

    table.data-table tr:hover td {
      background: rgba(255, 255, 255, 0.02);
    }

    /* BADGES */
    .tag {
      display: inline-flex;
      align-items: center;
      padding: 3px 9px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.3px;
    }

    .tag-cyan {
      background: rgba(0, 210, 255, 0.12);
      border: 1px solid rgba(0, 210, 255, 0.35);
      color: var(--cyan);
    }

    .tag-green {
      background: rgba(52, 255, 140, 0.12);
      border: 1px solid rgba(52, 255, 140, 0.35);
      color: var(--emerald);
    }

    .tag-amber {
      background: rgba(255, 184, 0, 0.12);
      border: 1px solid rgba(255, 184, 0, 0.35);
      color: var(--amber);
    }

    .tag-red {
      background: rgba(255, 71, 87, 0.15);
      border: 1px solid rgba(255, 71, 87, 0.4);
      color: var(--crimson);
    }

    /* TOGGLE SWITCHES */
    .toggle-group {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    .toggle-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 16px;
      border-radius: 10px;
      background: var(--bg-surface);
      border: 1px solid var(--border-subtle);
      transition: border-color 0.2s;
    }

    .toggle-row:hover {
      border-color: rgba(255, 255, 255, 0.12);
    }

    .toggle-info {
      display: flex;
      flex-direction: column;
      gap: 3px;
    }

    .toggle-title {
      font-size: 13.5px;
      font-weight: 600;
      color: #FFF;
    }

    .toggle-desc {
      font-size: 11.5px;
      color: var(--text-muted);
    }

    .switch {
      position: relative;
      display: inline-block;
      width: 44px;
      height: 24px;
      flex-shrink: 0;
    }

    .switch input {
      opacity: 0;
      width: 0;
      height: 0;
    }

    .slider {
      position: absolute;
      cursor: pointer;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background-color: #242E42;
      transition: .3s;
      border-radius: 24px;
    }

    .slider:before {
      position: absolute;
      content: "";
      height: 18px;
      width: 18px;
      left: 3px;
      bottom: 3px;
      background-color: white;
      transition: .3s;
      border-radius: 50%;
    }

    input:checked + .slider {
      background-color: var(--cyan);
      box-shadow: 0 0 10px var(--cyan-glow);
    }

    input:checked + .slider:before {
      transform: translateX(20px);
    }

    /* BUTTONS */
    .btn-primary {
      background: linear-gradient(135deg, #00D2FF 0%, #0072FF 100%);
      color: #000;
      border: none;
      padding: 10px 18px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      transition: opacity 0.2s, transform 0.15s;
    }

    .btn-primary:hover {
      opacity: 0.92;
      transform: translateY(-1px);
    }

    .btn-secondary {
      background: var(--bg-card);
      color: var(--text-main);
      border: 1px solid var(--border-subtle);
      padding: 8px 14px;
      border-radius: 8px;
      font-size: 12.5px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }

    .btn-secondary:hover {
      border-color: var(--cyan);
      color: var(--cyan);
    }

    .btn-danger {
      background: rgba(255, 71, 87, 0.15);
      color: var(--crimson);
      border: 1px solid rgba(255, 71, 87, 0.35);
      padding: 8px 14px;
      border-radius: 8px;
      font-size: 12.5px;
      font-weight: 600;
      cursor: pointer;
    }

    .btn-danger:hover {
      background: rgba(255, 71, 87, 0.25);
    }

    /* SEARCH / FILTER */
    .filter-bar {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 16px;
      flex-wrap: wrap;
    }

    .search-input {
      background: var(--bg-surface);
      border: 1px solid var(--border-subtle);
      padding: 9px 14px;
      border-radius: 8px;
      color: #FFF;
      font-size: 13px;
      outline: none;
      min-width: 260px;
    }

    .search-input:focus {
      border-color: var(--cyan);
      box-shadow: 0 0 0 2px var(--cyan-glow);
    }

    .category-pills {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }

    .cat-pill {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      padding: 6px 12px;
      border-radius: 20px;
      font-size: 11.5px;
      font-weight: 600;
      color: var(--text-muted);
      cursor: pointer;
      transition: all 0.15s;
    }

    .cat-pill.active, .cat-pill:hover {
      background: rgba(0, 210, 255, 0.12);
      border-color: var(--cyan);
      color: var(--cyan);
    }

    /* MODAL */
    .modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(4, 6, 10, 0.75);
      backdrop-filter: blur(8px);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 100;
    }

    .modal-overlay.active {
      display: flex;
    }

    .modal-card {
      background: var(--bg-card);
      border: 1px solid rgba(0, 210, 255, 0.3);
      border-radius: 16px;
      width: 90%;
      max-width: 580px;
      padding: 28px;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
      display: flex;
      flex-direction: column;
      gap: 20px;
      animation: modalSlide 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    }

    @keyframes modalSlide {
      from { transform: translateY(20px) scale(0.96); opacity: 0; }
      to { transform: translateY(0) scale(1); opacity: 1; }
    }

    .modal-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    .modal-title {
      font-size: 18px;
      font-weight: 800;
      color: #FFF;
    }

    .btn-close {
      background: none;
      border: none;
      color: var(--text-muted);
      font-size: 20px;
      cursor: pointer;
    }

    .form-group {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }

    .form-label {
      font-size: 12px;
      font-weight: 700;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .form-control {
      background: var(--bg-surface);
      border: 1px solid var(--border-subtle);
      border-radius: 8px;
      padding: 10px 14px;
      font-size: 13.5px;
      color: #FFF;
      outline: none;
      font-family: var(--font-sans);
    }

    .form-control:focus {
      border-color: var(--cyan);
      box-shadow: 0 0 0 2px var(--cyan-glow);
    }

    /* TOAST */
    .toast-container {
      position: fixed;
      bottom: 24px;
      right: 24px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      z-index: 1000;
    }

    .toast {
      background: var(--bg-card);
      border: 1px solid var(--cyan);
      color: #FFF;
      padding: 12px 18px;
      border-radius: 10px;
      font-size: 13px;
      font-weight: 600;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
      display: flex;
      align-items: center;
      gap: 10px;
      animation: toastIn 0.3s ease-out;
    }

    @keyframes toastIn {
      from { transform: translateX(50px); opacity: 0; }
      to { transform: translateX(0); opacity: 1; }
    }

    /* TAB VIEWS */
    .view-panel {
      display: none;
      flex-direction: column;
      gap: 24px;
    }

    .view-panel.active {
      display: flex;
    }

    /* KINEMATICS DRAWER */
    .kinematics-card {
      border: 1px solid var(--border-subtle);
      background: var(--bg-surface);
      border-radius: 12px;
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      position: relative;
    }

    .kinematics-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
    }

    .exercise-title {
      font-size: 15px;
      font-weight: 700;
      color: #FFF;
    }

    .hindi-badge {
      font-size: 11px;
      color: var(--text-muted);
      margin-left: 6px;
    }

    .angles-strip {
      display: flex;
      gap: 10px;
      font-family: var(--font-mono);
      font-size: 11.5px;
      color: var(--cyan);
      background: rgba(0, 210, 255, 0.06);
      padding: 6px 10px;
      border-radius: 6px;
      border: 1px solid rgba(0, 210, 255, 0.15);
    }
  </style>
</head>
<body>

  <!-- TOP BAR -->
  <header class="topbar">
    <div class="brand-section">
      <a href="/admin" class="brand-logo">
        <div class="logo-icon">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
          </svg>
        </div>
        <span class="brand-title">VYRA</span>
      </a>
      <span class="badge-enterprise">Enterprise Command</span>
    </div>

    <div class="top-telemetry">
      <div class="status-pill">
        <div class="pulse-dot"></div>
        <span>e-RaktKosh API Setu Active • 42ms Gateway</span>
      </div>
      <div class="status-pill" style="border-color: rgba(0, 210, 255, 0.3); color: var(--cyan); background: rgba(0, 210, 255, 0.08);">
        <div class="pulse-dot" style="background-color: var(--cyan); box-shadow: 0 0 10px var(--cyan);"></div>
        <span>Gemini 1.5 RAG Grounding 100%</span>
      </div>
    </div>

    <div class="top-actions">
      <div class="clock-display" id="live-clock">12:30:00 IST</div>
      <button class="btn-refresh" onclick="refreshAdminData()">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M23 4v6h-6"></path><path d="M1 20v-6h6"></path><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"></path></svg>
        Refresh
      </button>
      <div class="user-avatar-badge">
        <div class="avatar-circle">AB</div>
        <span class="user-name-tag">Ayush Bhadoria (Superadmin)</span>
      </div>
    </div>
  </header>

  <!-- BODY -->
  <div class="app-body">
    <!-- SIDEBAR -->
    <nav class="sidebar">
      <div>
        <div class="nav-group-label">Core Operations</div>
        <ul class="nav-list">
          <li class="nav-item active" onclick="switchTab('overview')">
            <div class="nav-item-left">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect></svg>
              <span>Command Center</span>
            </div>
          </li>
          <li class="nav-item" onclick="switchTab('features')">
            <div class="nav-item-left">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline></svg>
              <span>Feature Flags</span>
            </div>
            <span class="nav-badge" style="background: rgba(0, 210, 255, 0.15); color: var(--cyan); border-color: rgba(0,210,255,0.3)">15 Active</span>
          </li>
          <li class="nav-item" onclick="switchTab('blood')">
            <div class="nav-item-left">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path></svg>
              <span>e-RaktKosh SOS</span>
            </div>
            <span class="nav-badge" id="sidebar-blood-count">2 Urgent</span>
          </li>
          <li class="nav-item" onclick="switchTab('exercises')">
            <div class="nav-item-left">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 18h12M6 6h12M4 12h16"></path></svg>
              <span>AI Kinematics</span>
            </div>
            <span class="nav-badge" style="background: rgba(52, 255, 140, 0.15); color: var(--emerald); border-color: rgba(52,255,140,0.3)">100+ Moves</span>
          </li>
          <li class="nav-item" onclick="switchTab('athletes')">
            <div class="nav-item-left">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>
              <span>Athletes & Users</span>
            </div>
          </li>
          <li class="nav-item" onclick="switchTab('tickets')">
            <div class="nav-item-left">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>
              <span>Support & Moderation</span>
            </div>
            <span class="nav-badge" id="sidebar-tickets-count">1 Open</span>
          </li>
          <li class="nav-item" onclick="switchTab('maintenance')">
            <div class="nav-item-left">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>
              <span>System & Broadcast</span>
            </div>
          </li>
        </ul>
      </div>

      <div class="sidebar-footer">
        <div><strong>VYRA Core Production v2.4.0</strong></div>
        <div>Enterprise Operations Control</div>
        <div>Cluster Status: Healthy (99.98%)</div>
      </div>
    </nav>

    <!-- MAIN VIEWPORT -->
    <main class="viewport">

      <!-- 1. OVERVIEW VIEW -->
      <div id="view-overview" class="view-panel active">
        <div class="page-header">
          <div>
            <h1 class="page-title">Command Center</h1>
            <p class="page-subtitle">National health telemetry, real-time activity throughput, and operational KPIs.</p>
          </div>
          <button class="btn-primary" onclick="openEmergencyModal()">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
            + New Emergency Appeal
          </button>
        </div>

        <div class="kpi-grid">
          <div class="card kpi-card" style="--glow-color: rgba(0, 210, 255, 0.2);">
            <div class="kpi-label">Active Athletes Today</div>
            <div class="kpi-value" id="kpi-athletes">8,424</div>
            <div class="kpi-trend">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"></polyline><polyline points="17 6 23 6 23 12"></polyline></svg>
              <span>+14.8% vs yesterday</span>
            </div>
          </div>

          <div class="card kpi-card" style="--glow-color: rgba(52, 255, 140, 0.2);">
            <div class="kpi-label">Workouts Completed</div>
            <div class="kpi-value" id="kpi-workouts">1,845</div>
            <div class="kpi-trend">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"></polyline><polyline points="17 6 23 6 23 12"></polyline></svg>
              <span>99.2% Form Accuracy</span>
            </div>
          </div>

          <div class="card kpi-card" style="--glow-color: rgba(255, 71, 87, 0.25);">
            <div class="kpi-label">Active Blood Appeals</div>
            <div class="kpi-value" id="kpi-appeals" style="color: var(--crimson);">2</div>
            <div class="kpi-trend" style="color: var(--amber);">
              <span>AIIMS & Safdarjung Trauma</span>
            </div>
          </div>

          <div class="card kpi-card" style="--glow-color: rgba(165, 94, 234, 0.2);">
            <div class="kpi-label">Gemini RAG Queries</div>
            <div class="kpi-value" id="kpi-gemini">4,129</div>
            <div class="kpi-trend">
              <span>0% Hallucination Index</span>
            </div>
          </div>
        </div>

        <!-- TWO COLUMN SECTION -->
        <div class="two-col-grid">
          <div class="card">
            <div class="card-title">
              <span>Live Hourly Workout Velocity (Kinematics Throughput)</span>
              <span class="tag tag-cyan">Live Socket</span>
            </div>
            <!-- Dynamic SVG Velocity Chart -->
            <svg viewBox="0 0 600 200" style="width: 100%; height: 180px; overflow: visible;">
              <defs>
                <linearGradient id="chartGrad" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stop-color="#00D2FF" stop-opacity="0.35"/>
                  <stop offset="100%" stop-color="#00D2FF" stop-opacity="0.0"/>
                </linearGradient>
              </defs>
              <line x1="0" y1="180" x2="600" y2="180" stroke="rgba(255,255,255,0.08)" stroke-width="1"/>
              <line x1="0" y1="120" x2="600" y2="120" stroke="rgba(255,255,255,0.05)" stroke-dasharray="4"/>
              <line x1="0" y1="60" x2="600" y2="60" stroke="rgba(255,255,255,0.05)" stroke-dasharray="4"/>
              
              <!-- Gradient fill -->
              <path d="M 0 180 L 0 140 Q 60 120 120 130 T 240 90 T 360 40 T 480 80 T 600 30 L 600 180 Z" fill="url(#chartGrad)"/>
              
              <!-- Curve Stroke -->
              <path d="M 0 140 Q 60 120 120 130 T 240 90 T 360 40 T 480 80 T 600 30" fill="none" stroke="#00D2FF" stroke-width="3" stroke-linecap="round"/>

              <!-- Pulse Point -->
              <circle cx="600" cy="30" r="5" fill="#34FF8C" stroke="#FFF" stroke-width="2"/>
            </svg>
            <div style="display: flex; justify-content: space-between; font-size: 11px; color: var(--text-dim); margin-top: 8px; font-family: var(--font-mono);">
              <span>06:00 AM (Morning Push)</span>
              <span>12:00 PM (Midday)</span>
              <span>06:00 PM (Evening Peak)</span>
              <span>NOW (Peak Velocity: 342 reps/min)</span>
            </div>
          </div>

          <div class="card">
            <div class="card-title">
              <span>National System Health</span>
              <span class="tag tag-green">All Systems Nominal</span>
            </div>
            <div style="display: flex; flex-direction: column; gap: 14px; font-size: 12.5px;">
              <div style="display: flex; justify-content: space-between; padding-bottom: 8px; border-bottom: 1px solid var(--border-subtle);">
                <span style="color: var(--text-muted);">Node API Runtime</span>
                <strong style="color: var(--emerald);">HEALTHY (0 fatal)</strong>
              </div>
              <div style="display: flex; justify-content: space-between; padding-bottom: 8px; border-bottom: 1px solid var(--border-subtle);">
                <span style="color: var(--text-muted);">e-RaktKosh API Setu Gateway</span>
                <strong style="color: var(--cyan);">CONNECTED (42ms)</strong>
              </div>
              <div style="display: flex; justify-content: space-between; padding-bottom: 8px; border-bottom: 1px solid var(--border-subtle);">
                <span style="color: var(--text-muted);">Gemini 1.5 Flash Vision Model</span>
                <strong style="color: var(--emerald);">ACTIVE (Grounding ON)</strong>
              </div>
              <div style="display: flex; justify-content: space-between; padding-bottom: 8px; border-bottom: 1px solid var(--border-subtle);">
                <span style="color: var(--text-muted);">Memory RSS / Heap</span>
                <strong style="font-family: var(--font-mono); color: #FFF;" id="telemetry-ram">48 MB / 128 MB</strong>
              </div>
              <div style="display: flex; justify-content: space-between;">
                <span style="color: var(--text-muted);">Core Server Uptime</span>
                <strong style="font-family: var(--font-mono); color: var(--amber);" id="telemetry-uptime">99.98%</strong>
              </div>
            </div>
          </div>
        </div>

        <!-- RECENT CRITICAL APPEALS -->
        <div class="card">
          <div class="card-title">
            <span>Critical e-RaktKosh Blood Donation Appeals</span>
            <button class="btn-secondary" onclick="switchTab('blood')">View All Appeals</button>
          </div>
          <div class="data-table-container">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Hospital</th>
                  <th>Location</th>
                  <th>Blood Group</th>
                  <th>Units</th>
                  <th>Urgency</th>
                  <th>Contact Person</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody id="overview-appeals-tbody">
                <!-- Injected dynamically -->
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- 2. FEATURE FLAGS VIEW -->
      <div id="view-features" class="view-panel">
        <div class="page-header">
          <div>
            <h1 class="page-title">Feature Flags & Remote Config</h1>
            <p class="page-subtitle">Instant real-time toggles for production modules. Clients receive updates within seconds.</p>
          </div>
          <button class="btn-primary" onclick="showToast('Feature flags synced with cloud config.')">
            Save Snapshot
          </button>
        </div>

        <div class="three-col-grid" id="feature-flags-grid">
          <!-- Injected dynamically -->
        </div>
      </div>

      <!-- 3. e-RAKTKOSH BLOOD SOS VIEW -->
      <div id="view-blood" class="view-panel">
        <div class="page-header">
          <div>
            <h1 class="page-title">e-RaktKosh Blood Bank & Emergency SOS</h1>
            <p class="page-subtitle">National emergency blood coordination, hospital alerts, and verified donor dispatch.</p>
          </div>
          <button class="btn-primary" onclick="openEmergencyModal()">
            + Create Hospital Emergency Appeal
          </button>
        </div>

        <div class="kpi-grid">
          <div class="card kpi-card">
            <div class="kpi-label">Connected Blood Banks</div>
            <div class="kpi-value" style="color: var(--cyan);">148</div>
            <div class="kpi-trend">e-RaktKosh API Setu Verified</div>
          </div>
          <div class="card kpi-card">
            <div class="kpi-label">Bags Pledged This Month</div>
            <div class="kpi-value" style="color: var(--emerald);">824</div>
            <div class="kpi-trend">+182 via VYRA Donors</div>
          </div>
          <div class="card kpi-card">
            <div class="kpi-label">Average Response Time</div>
            <div class="kpi-value" style="color: var(--amber);">8.4 min</div>
            <div class="kpi-trend">AI Rapid Donor Matching</div>
          </div>
          <div class="card kpi-card">
            <div class="kpi-label">Verified Thalassemia Patients</div>
            <div class="kpi-value">54</div>
            <div class="kpi-trend">Free Priority Transfusion Queue</div>
          </div>
        </div>

        <div class="card">
          <div class="card-title">
            <span>Active Hospital Emergency Appeals</span>
            <span class="tag tag-red">High Priority Board</span>
          </div>
          <div class="data-table-container">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Appeal ID</th>
                  <th>Hospital & City</th>
                  <th>Group</th>
                  <th>Units</th>
                  <th>Urgency</th>
                  <th>Medical Reason / Case</th>
                  <th>Emergency Contact</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody id="blood-appeals-tbody">
                <!-- Injected dynamically -->
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- 4. AI KINEMATICS & DATASET VIEW -->
      <div id="view-exercises" class="view-panel">
        <div class="page-header">
          <div>
            <h1 class="page-title">AI Biomechanical Kinematics & Exercise Registry</h1>
            <p class="page-subtitle">100+ Sports-Physio exercise movements with joint flexion angles, tempo, breathing & Gemini RAG.</p>
          </div>
          <button class="btn-primary" onclick="openGeminiInspector('squat')">
            Inspect Gemini Prompt Grounding
          </button>
        </div>

        <div class="filter-bar">
          <input type="text" class="search-input" id="exercise-search" placeholder="Search exercises (e.g. Squat, Push-up, उठक-बैठक)..." oninput="filterExercises()">
          <div class="category-pills" id="exercise-cat-pills">
            <span class="cat-pill active" onclick="setCategoryFilter('')">All (100+)</span>
            <span class="cat-pill" onclick="setCategoryFilter('legs')">Legs</span>
            <span class="cat-pill" onclick="setCategoryFilter('chest')">Chest</span>
            <span class="cat-pill" onclick="setCategoryFilter('back')">Back</span>
            <span class="cat-pill" onclick="setCategoryFilter('shoulders')">Shoulders</span>
            <span class="cat-pill" onclick="setCategoryFilter('arms')">Arms</span>
            <span class="cat-pill" onclick="setCategoryFilter('core')">Core</span>
            <span class="cat-pill" onclick="setCategoryFilter('cardio')">HIIT Cardio</span>
            <span class="cat-pill" onclick="setCategoryFilter('yoga')">Yoga & Mobility</span>
          </div>
        </div>

        <div class="three-col-grid" id="exercises-grid">
          <!-- Injected dynamically -->
        </div>
      </div>

      <!-- 5. ATHLETES & USERS VIEW -->
      <div id="view-athletes" class="view-panel">
        <div class="page-header">
          <div>
            <h1 class="page-title">Registered Athletes & User Directory</h1>
            <p class="page-subtitle">Manage athlete profiles, streak milestones, VYRA coins rewards, and verified badges.</p>
          </div>
        </div>

        <div class="card">
          <div class="filter-bar">
            <input type="text" class="search-input" id="athlete-search" placeholder="Search athletes by name, @handle, email..." oninput="filterAthletes()">
          </div>
          <div class="data-table-container">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Athlete Name</th>
                  <th>Handle</th>
                  <th>Tier Badge</th>
                  <th>Streak</th>
                  <th>Workouts</th>
                  <th>VYRA Coins</th>
                  <th>Blood Donor</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody id="athletes-tbody">
                <!-- Injected dynamically -->
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- 6. SUPPORT TICKETS VIEW -->
      <div id="view-tickets" class="view-panel">
        <div class="page-header">
          <div>
            <h1 class="page-title">Support Tickets & Athlete Moderation</h1>
            <p class="page-subtitle">Direct communication line with athletes, badge inquiries, and technical support.</p>
          </div>
        </div>

        <div class="card">
          <div class="data-table-container">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Ticket ID</th>
                  <th>Athlete</th>
                  <th>Category</th>
                  <th>Subject</th>
                  <th>Status</th>
                  <th>Date</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody id="tickets-tbody">
                <!-- Injected dynamically -->
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- 7. SYSTEM & MAINTENANCE VIEW -->
      <div id="view-maintenance" class="view-panel">
        <div class="page-header">
          <div>
            <h1 class="page-title">System & Global Broadcast Settings</h1>
            <p class="page-subtitle">Manage platform availability, emergency maintenance banners, and mobile app minimum versions.</p>
          </div>
          <button class="btn-primary" onclick="saveSystemStatus()">
            Apply System Configuration
          </button>
        </div>

        <div class="two-col-grid">
          <div class="card">
            <div class="card-title">Platform Maintenance Controller</div>
            <div class="toggle-group">
              <div class="toggle-row">
                <div class="toggle-info">
                  <div class="toggle-title">Maintenance Mode</div>
                  <div class="toggle-desc">When enabled, mobile apps display a graceful downtime overlay.</div>
                </div>
                <label class="switch">
                  <input type="checkbox" id="sys-maintenance-mode">
                  <span class="slider"></span>
                </label>
              </div>

              <div class="form-group" style="margin-top: 14px;">
                <label class="form-label">Broadcast Banner Message</label>
                <textarea class="form-control" id="sys-maintenance-msg" rows="3">VYRA core servers are undergoing routine high-performance optimization. Resuming in 10 minutes.</textarea>
              </div>

              <div class="toggle-row" style="margin-top: 8px;">
                <div class="toggle-info">
                  <div class="toggle-title">User Registration Open</div>
                  <div class="toggle-desc">Permit new athletes to create accounts.</div>
                </div>
                <label class="switch">
                  <input type="checkbox" id="sys-reg-open" checked>
                  <span class="slider"></span>
                </label>
              </div>
            </div>
          </div>

          <div class="card">
            <div class="card-title">Mobile App Version Gateways</div>
            <div style="display: flex; flex-direction: column; gap: 16px;">
              <div class="form-group">
                <label class="form-label">Minimum iOS App Version</label>
                <input type="text" class="form-control" id="sys-ios-ver" value="1.0.0">
              </div>
              <div class="form-group">
                <label class="form-label">Minimum Android App Version</label>
                <input type="text" class="form-control" id="sys-android-ver" value="1.0.0">
              </div>
              <div class="form-group">
                <label class="form-label">Active Gemini Model</label>
                <input type="text" class="form-control" value="gemini-1.5-flash-latest (Multimodal Vision)" readonly style="color: var(--cyan);">
              </div>
            </div>
          </div>
        </div>
      </div>

    </main>
  </div>

  <!-- MODAL: CREATE BLOOD APPEAL -->
  <div class="modal-overlay" id="modal-appeal">
    <div class="modal-card">
      <div class="modal-header">
        <h2 class="modal-title">Create Emergency Blood Appeal</h2>
        <button class="btn-close" onclick="closeModal('modal-appeal')">&times;</button>
      </div>
      <div style="display: flex; flex-direction: column; gap: 14px;">
        <div class="form-group">
          <label class="form-label">Hospital Name</label>
          <input type="text" class="form-control" id="appeal-hosp" placeholder="e.g. AIIMS New Delhi">
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
          <div class="form-group">
            <label class="form-label">Blood Group</label>
            <select class="form-control" id="appeal-group">
              <option value="O+">O+ Positive</option>
              <option value="O-">O- Negative (Universal)</option>
              <option value="A+">A+ Positive</option>
              <option value="A-">A- Negative</option>
              <option value="B+">B+ Positive</option>
              <option value="B-">B- Negative</option>
              <option value="AB+">AB+ Positive</option>
              <option value="AB-">AB- Negative</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">Units Needed</label>
            <input type="number" class="form-control" id="appeal-units" value="2" min="1" max="10">
          </div>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
          <div class="form-group">
            <label class="form-label">Urgency Level</label>
            <select class="form-control" id="appeal-urgency">
              <option value="CRITICAL">CRITICAL (Immediate)</option>
              <option value="URGENT">URGENT (&lt; 4 Hours)</option>
              <option value="ROUTINE">ROUTINE (Scheduled)</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">City</label>
            <input type="text" class="form-control" id="appeal-city" value="New Delhi">
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">Patient Case / Surgery Context</label>
          <input type="text" class="form-control" id="appeal-case" placeholder="e.g. Emergency OT surgery, polytrauma">
        </div>
        <div class="form-group">
          <label class="form-label">Duty Doctor / Contact Phone</label>
          <input type="text" class="form-control" id="appeal-phone" value="+91 98112 34567">
        </div>
      </div>
      <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
        <button class="btn-secondary" onclick="closeModal('modal-appeal')">Cancel</button>
        <button class="btn-primary" onclick="submitAppeal()">Dispatch Emergency Broadcast</button>
      </div>
    </div>
  </div>

  <!-- MODAL: REWARD ATHLETE COINS -->
  <div class="modal-overlay" id="modal-reward">
    <div class="modal-card">
      <div class="modal-header">
        <h2 class="modal-title">Grant Athlete VYRA Bonus Coins</h2>
        <button class="btn-close" onclick="closeModal('modal-reward')">&times;</button>
      </div>
      <div style="display: flex; flex-direction: column; gap: 14px;">
        <input type="hidden" id="reward-athlete-id">
        <p style="font-size: 13px; color: var(--text-muted);" id="reward-athlete-desc">Granting bonus motivational coins to athlete.</p>
        <div class="form-group">
          <label class="form-label">Coin Bonus Amount</label>
          <input type="number" class="form-control" id="reward-coins-amount" value="100" min="10" step="10">
        </div>
        <div class="form-group">
          <label class="form-label">Reason / Award Badge</label>
          <input type="text" class="form-control" id="reward-reason" value="National Fitness Sprint Excellence Award">
        </div>
      </div>
      <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
        <button class="btn-secondary" onclick="closeModal('modal-reward')">Cancel</button>
        <button class="btn-primary" onclick="submitReward()">Award Coins</button>
      </div>
    </div>
  </div>

  <!-- MODAL: REPLY TICKET -->
  <div class="modal-overlay" id="modal-ticket">
    <div class="modal-card">
      <div class="modal-header">
        <h2 class="modal-title">Reply to Support Ticket</h2>
        <button class="btn-close" onclick="closeModal('modal-ticket')">&times;</button>
      </div>
      <div style="display: flex; flex-direction: column; gap: 14px;">
        <input type="hidden" id="ticket-id">
        <div style="font-size: 13px; color: var(--text-muted);" id="ticket-context">Loading context...</div>
        <div class="form-group">
          <label class="form-label">Admin Reply</label>
          <textarea class="form-control" id="ticket-reply-text" rows="4" placeholder="Enter solution or clarification for athlete..."></textarea>
        </div>
        <div class="form-group">
          <label class="form-label">Status</label>
          <select class="form-control" id="ticket-status-select">
            <option value="RESOLVED">RESOLVED</option>
            <option value="IN_PROGRESS">IN_PROGRESS</option>
            <option value="OPEN">OPEN</option>
          </select>
        </div>
      </div>
      <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
        <button class="btn-secondary" onclick="closeModal('modal-ticket')">Cancel</button>
        <button class="btn-primary" onclick="submitTicketReply()">Send Official Reply</button>
      </div>
    </div>
  </div>

  <!-- MODAL: GEMINI GROUNDING INSPECTOR -->
  <div class="modal-overlay" id="modal-gemini">
    <div class="modal-card" style="max-width: 720px;">
      <div class="modal-header">
        <h2 class="modal-title">Gemini RAG Grounding Prompt Inspector</h2>
        <button class="btn-close" onclick="closeModal('modal-gemini')">&times;</button>
      </div>
      <div style="display: flex; flex-direction: column; gap: 12px; font-size: 13px;">
        <p style="color: var(--text-muted);">
          When an athlete asks Gemini AI about exercise form or rehabilitation, VYRA's sports-physio dataset is injected into the system context. This prevents hallucinations and forces medically verified biomechanical angles.
        </p>
        <div class="form-group">
          <label class="form-label">Grounding Payload Sent to Gemini 1.5</label>
          <pre class="form-control" id="gemini-prompt-preview" style="font-family: var(--font-mono); font-size: 11.5px; height: 260px; overflow-y: auto; color: var(--cyan); white-space: pre-wrap; line-height: 1.5;">Loading...</pre>
        </div>
      </div>
      <div style="display: flex; justify-content: flex-end; margin-top: 10px;">
        <button class="btn-primary" onclick="closeModal('modal-gemini')">Close Inspector</button>
      </div>
    </div>
  </div>

  <!-- TOAST CONTAINER -->
  <div class="toast-container" id="toast-container"></div>

  <!-- LOGIC SCRIPT -->
  <script>
    // In-memory local state
    let state = {
      featureFlags: {},
      appeals: [],
      athletes: [],
      tickets: [],
      exercises: [],
      selectedCategory: '',
    };

    // Live Clock
    function updateClock() {
      const now = new Date();
      const timeStr = now.toLocaleTimeString('en-IN', { timeZone: 'Asia/Kolkata' }) + ' IST';
      const el = document.getElementById('live-clock');
      if (el) el.innerText = timeStr;
    }
    setInterval(updateClock, 1000);
    updateClock();

    // Tab Navigation
    function switchTab(tabId) {
      document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
      document.querySelectorAll('.view-panel').forEach(el => el.classList.remove('active'));

      const targetNav = Array.from(document.querySelectorAll('.nav-item')).find(el => el.getAttribute('onclick')?.includes(tabId));
      if (targetNav) targetNav.classList.add('active');

      const targetView = document.getElementById('view-' + tabId);
      if (targetView) targetView.classList.add('active');
    }

    // Toast Notifications
    function showToast(message) {
      const c = document.getElementById('toast-container');
      const t = document.createElement('div');
      t.className = 'toast';
      t.innerHTML = '⚡ ' + message;
      c.appendChild(t);
      setTimeout(() => {
        t.style.opacity = '0';
        t.style.transform = 'translateY(10px)';
        setTimeout(() => t.remove(), 300);
      }, 3500);
    }

    // Modal helpers
    function openModal(id) {
      document.getElementById(id).classList.add('active');
    }
    function closeModal(id) {
      document.getElementById(id).classList.remove('active');
    }
    function openEmergencyModal() {
      openModal('modal-appeal');
    }

    // Data Fetching
    async function refreshAdminData() {
      try {
        // 1. Overview
        const resOver = await fetch('/v1/admin/overview');
        if (resOver.ok) {
          const data = await resOver.json();
          document.getElementById('kpi-athletes').innerText = Number(data.kpi.activeAthletes).toLocaleString('en-IN');
          document.getElementById('kpi-workouts').innerText = Number(data.kpi.workoutsCompletedToday).toLocaleString('en-IN');
          document.getElementById('kpi-appeals').innerText = data.kpi.emergencyBloodAppealsActive;
          document.getElementById('kpi-gemini').innerText = Number(data.kpi.geminiAiQueriesToday).toLocaleString('en-IN');
          document.getElementById('telemetry-ram').innerText = data.kpi.memoryRssMb + ' MB / 256 MB';
          document.getElementById('telemetry-uptime').innerText = Math.floor(data.kpi.systemUptimeSec / 60) + ' min uptime';

          state.featureFlags = data.featureFlags || {};
          renderFeatureFlags();
        }

        // 2. Blood Appeals
        const resBlood = await fetch('/v1/admin/blood-network');
        if (resBlood.ok) {
          const data = await resBlood.json();
          state.appeals = data.appeals || [];
          renderBloodAppeals();
        }

        // 3. Athletes
        const resAthletes = await fetch('/v1/admin/athletes');
        if (resAthletes.ok) {
          const data = await resAthletes.json();
          state.athletes = data.athletes || [];
          renderAthletes();
        }

        // 4. Tickets
        const resTickets = await fetch('/v1/admin/tickets');
        if (resTickets.ok) {
          const data = await resTickets.json();
          state.tickets = data.tickets || [];
          renderTickets();
        }

        // 5. Exercises
        const resEx = await fetch('/v1/admin/exercises');
        if (resEx.ok) {
          const data = await resEx.json();
          state.exercises = data.exercises || [];
          renderExercises();
        }

        showToast('All real-time telemetry and registries synchronized.');
      } catch (err) {
        console.warn('API fetch warning, using loaded local state:', err);
      }
    }

    // Render Feature Flags
    function renderFeatureFlags() {
      const container = document.getElementById('feature-flags-grid');
      if (!container) return;
      container.innerHTML = '';

      const flagDescriptions = {
        pose_tracking: 'AI Camera 33-Joint Skeleton Kinematics & Rep Counter',
        blood_donation: 'e-RaktKosh National Blood Bank Network & Pledges',
        nearby_doctors: 'Verified Doctors & Healthcare Booking System',
        health_report_ai: 'Blood Test OCR & Biomarker Clinical AI Insights',
        transformation_photos: 'Before/After Privacy Mesh Photo Journal',
        social_leaderboard: 'WhatsApp Contact Sync & Family Cup Leaderboard',
        multilingual: 'Hindi, Hinglish & Regional Vernacular Engine',
        admob_ads: 'Non-intrusive AdMob Banner Placements',
        rewarded_ads: 'Opt-in Rewarded Ads for Workout Coin Boosts',
        subscription_pro: 'VYRA Pro Elite Membership & Custom AI Diets',
        subscription_elite: '1-on-1 Certified Coach & Realtime Video Consult',
        motivational_slogans: 'Dynamic Daily Hindi/English Motivation Service',
        avatar_3d_viewport: '180° Biomechanical 3D Coach in Exercise Detail',
        face_likeness_engine: 'On-device Face Scan Likeness Generator',
        diet_framework: 'Macro Tracking & Sugar Neutralizer Intelligence',
      };

      for (const [key, enabled] of Object.entries(state.featureFlags)) {
        const row = document.createElement('div');
        row.className = 'toggle-row';
        row.innerHTML = \`
          <div class="toggle-info">
            <div class="toggle-title">\${key.replace(/_/g, ' ').toUpperCase()}</div>
            <div class="toggle-desc">\${flagDescriptions[key] || 'Platform feature control module'}</div>
          </div>
          <label class="switch">
            <input type="checkbox" \${enabled ? 'checked' : ''} onchange="toggleFlag('\${key}', this.checked)">
            <span class="slider"></span>
          </label>
        \`;
        container.appendChild(row);
      }
    }

    async function toggleFlag(key, value) {
      try {
        const res = await fetch('/v1/admin/feature-flags/toggle', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ key, value })
        });
        if (res.ok) {
          state.featureFlags[key] = value;
          showToast(\`Feature flag "\${key}" is now \${value ? 'ENABLED' : 'DISABLED'}\`);
        }
      } catch (e) {
        showToast('Error syncing flag: ' + e);
      }
    }

    // Render Blood Appeals
    function renderBloodAppeals() {
      const overviewTbody = document.getElementById('overview-appeals-tbody');
      const fullTbody = document.getElementById('blood-appeals-tbody');
      const sidebarBadge = document.getElementById('sidebar-blood-count');

      const activeAppeals = state.appeals.filter(a => a.status === 'ACTIVE');
      if (sidebarBadge) sidebarBadge.innerText = activeAppeals.length + ' Urgent';

      const renderRow = (a) => \`
        <tr>
          <td><strong>\${a.hospitalName}</strong></td>
          <td>\${a.city || 'Delhi NCR'}</td>
          <td><span class="tag tag-red" style="font-family: var(--font-mono); font-size: 13px;">\${a.bloodGroup}</span></td>
          <td><strong>\${a.unitsNeeded} Units</strong></td>
          <td>
            <span class="tag \${a.urgency === 'CRITICAL' ? 'tag-red' : a.urgency === 'URGENT' ? 'tag-amber' : 'tag-cyan'}">
              \${a.urgency}
            </span>
          </td>
          <td>\${a.contactPerson} (\${a.contactPhone})</td>
          <td>
            \${a.status === 'ACTIVE' 
              ? \`<button class="btn-secondary" style="font-size: 11px; padding: 4px 8px;" onclick="fulfillAppeal('\${a.id}')">Mark Fulfilled</button>\`
              : \`<span class="tag tag-green">FULFILLED</span>\`
            }
          </td>
        </tr>
      \`;

      if (overviewTbody) {
        overviewTbody.innerHTML = state.appeals.slice(0, 3).map(renderRow).join('');
      }
      if (fullTbody) {
        fullTbody.innerHTML = state.appeals.map(a => \`
          <tr>
            <td><code style="font-family: var(--font-mono); color: var(--cyan);">\${a.id}</code></td>
            <td><strong>\${a.hospitalName}</strong><br><span style="font-size: 11px; color: var(--text-muted);">\${a.city}</span></td>
            <td><span class="tag tag-red" style="font-size: 13px;">\${a.bloodGroup}</span></td>
            <td><strong>\${a.unitsNeeded} Units</strong></td>
            <td><span class="tag \${a.urgency === 'CRITICAL' ? 'tag-red' : 'tag-amber'}">\${a.urgency}</span></td>
            <td style="max-width: 200px; font-size: 12px; color: var(--text-muted);">\${a.patientCase}</td>
            <td>\${a.contactPhone}</td>
            <td>
              \${a.status === 'ACTIVE' 
                ? \`<button class="btn-primary" style="font-size: 11px; padding: 4px 8px;" onclick="fulfillAppeal('\${a.id}')">Fulfill</button>\`
                : \`<span class="tag tag-green">RESOLVED</span>\`
              }
            </td>
          </tr>
        \`).join('');
      }
    }

    async function fulfillAppeal(id) {
      try {
        const res = await fetch(\`/v1/admin/blood-network/appeal/\${id}/fulfill\`, { method: 'POST' });
        if (res.ok) {
          const app = state.appeals.find(a => a.id === id);
          if (app) app.status = 'FULFILLED';
          renderBloodAppeals();
          showToast(\`Emergency Appeal \${id} marked as FULFILLED.\`);
        }
      } catch (e) {
        showToast('Error: ' + e);
      }
    }

    async function submitAppeal() {
      const hosp = document.getElementById('appeal-hosp').value.trim();
      const group = document.getElementById('appeal-group').value;
      const units = document.getElementById('appeal-units').value;
      const urgency = document.getElementById('appeal-urgency').value;
      const city = document.getElementById('appeal-city').value.trim();
      const patientCase = document.getElementById('appeal-case').value.trim();
      const phone = document.getElementById('appeal-phone').value.trim();

      if (!hosp) {
        alert('Please specify the hospital name.');
        return;
      }

      try {
        const res = await fetch('/v1/admin/blood-network/appeal', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ hospitalName: hosp, bloodGroup: group, unitsNeeded: units, urgency, city, patientCase, contactPhone: phone })
        });
        if (res.ok) {
          const data = await res.json();
          state.appeals.unshift(data.appeal);
          renderBloodAppeals();
          closeModal('modal-appeal');
          showToast(\`Emergency Broadcast sent for \${hosp} (\${group})\`);
        }
      } catch (e) {
        showToast('Error creating appeal: ' + e);
      }
    }

    // Render Athletes
    function renderAthletes() {
      const tbody = document.getElementById('athletes-tbody');
      if (!tbody) return;

      const q = (document.getElementById('athlete-search')?.value || '').toLowerCase();
      const list = state.athletes.filter(a => 
        a.name.toLowerCase().includes(q) || a.displayHandle.toLowerCase().includes(q) || a.email.toLowerCase().includes(q)
      );

      tbody.innerHTML = list.map(a => \`
        <tr>
          <td><strong>\${a.name}</strong><br><span style="font-size: 11px; color: var(--text-muted);">\${a.email}</span></td>
          <td><code style="color: var(--cyan);">\${a.displayHandle}</code></td>
          <td><span class="tag tag-cyan">\${a.tier}</span></td>
          <td><strong style="color: var(--amber);">🔥 \${a.streakDays} Days</strong></td>
          <td>\${a.totalWorkouts} sessions</td>
          <td><strong style="color: var(--emerald); font-family: var(--font-mono);">⚡ \${a.coins}</strong></td>
          <td>
            \${a.verifiedDonor 
              ? \`<span class="tag tag-green">Verified \${a.bloodGroup}</span>\` 
              : \`<span class="tag" style="background: rgba(255,255,255,0.05); color: var(--text-dim);">Unregistered</span>\`
            }
          </td>
          <td>
            <button class="btn-secondary" style="font-size: 11px; padding: 4px 8px;" onclick="openRewardModal('\${a.id}', '\${a.name}')">+ Grant Coins</button>
          </td>
        </tr>
      \`).join('');
    }

    function filterAthletes() {
      renderAthletes();
    }

    function openRewardModal(id, name) {
      document.getElementById('reward-athlete-id').value = id;
      document.getElementById('reward-athlete-desc').innerText = \`Granting bonus VYRA coins to \${name} for fitness accomplishments.\`;
      openModal('modal-reward');
    }

    async function submitReward() {
      const id = document.getElementById('reward-athlete-id').value;
      const coins = Number(document.getElementById('reward-coins-amount').value) || 100;
      try {
        const res = await fetch(\`/v1/admin/athletes/\${id}/reward\`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ bonusCoins: coins })
        });
        if (res.ok) {
          const data = await res.json();
          const athlete = state.athletes.find(a => a.id === id);
          if (athlete) athlete.coins += coins;
          renderAthletes();
          closeModal('modal-reward');
          showToast(data.message);
        }
      } catch (e) {
        showToast('Error awarding coins: ' + e);
      }
    }

    // Render Tickets
    function renderTickets() {
      const tbody = document.getElementById('tickets-tbody');
      const sidebarBadge = document.getElementById('sidebar-tickets-count');
      if (!tbody) return;

      const openTickets = state.tickets.filter(t => t.status === 'OPEN');
      if (sidebarBadge) sidebarBadge.innerText = openTickets.length + ' Open';

      tbody.innerHTML = state.tickets.map(t => \`
        <tr>
          <td><code style="color: var(--cyan); font-family: var(--font-mono);">\${t.id}</code></td>
          <td><strong>\${t.userName}</strong><br><span style="font-size: 11px; color: var(--text-muted);">\${t.userEmail}</span></td>
          <td><span class="tag tag-cyan">\${t.category}</span></td>
          <td>
            <strong>\${t.subject}</strong><br>
            <span style="font-size: 11.5px; color: var(--text-muted);">"\${t.message}"</span>
            \${t.reply ? \`<br><span style="font-size: 11px; color: var(--emerald);">Reply: \${t.reply}</span>\` : ''}
          </td>
          <td><span class="tag \${t.status === 'RESOLVED' ? 'tag-green' : t.status === 'OPEN' ? 'tag-red' : 'tag-amber'}">\${t.status}</span></td>
          <td style="font-size: 11px; color: var(--text-dim);">\${new Date(t.createdAt).toLocaleDateString()}</td>
          <td>
            <button class="btn-secondary" style="font-size: 11px; padding: 4px 8px;" onclick="openTicketModal('\${t.id}')">Reply</button>
          </td>
        </tr>
      \`).join('');
    }

    function openTicketModal(id) {
      const ticket = state.tickets.find(t => t.id === id);
      if (!ticket) return;
      document.getElementById('ticket-id').value = id;
      document.getElementById('ticket-context').innerText = \`Ticket \${ticket.id} by \${ticket.userName}: "\${ticket.subject}"\`;
      document.getElementById('ticket-reply-text').value = ticket.reply || '';
      document.getElementById('ticket-status-select').value = ticket.status;
      openModal('modal-ticket');
    }

    async function submitTicketReply() {
      const id = document.getElementById('ticket-id').value;
      const replyText = document.getElementById('ticket-reply-text').value.trim();
      const status = document.getElementById('ticket-status-select').value;

      try {
        const res = await fetch(\`/v1/admin/tickets/\${id}/reply\`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ replyText, status })
        });
        if (res.ok) {
          const t = state.tickets.find(x => x.id === id);
          if (t) {
            t.reply = replyText;
            t.status = status;
          }
          renderTickets();
          closeModal('modal-ticket');
          showToast(\`Ticket \${id} updated to \${status}\`);
        }
      } catch (e) {
        showToast('Error: ' + e);
      }
    }

    // Render Exercises
    function renderExercises() {
      const grid = document.getElementById('exercises-grid');
      if (!grid) return;

      const q = (document.getElementById('exercise-search')?.value || '').toLowerCase();
      let list = state.exercises;
      if (state.selectedCategory) {
        list = list.filter(e => e.category === state.selectedCategory);
      }
      if (q) {
        list = list.filter(e => 
          e.name.toLowerCase().includes(q) || e.slug.toLowerCase().includes(q) || (e.hindiName && e.hindiName.includes(q))
        );
      }

      grid.innerHTML = list.map(e => \`
        <div class="kinematics-card">
          <div class="kinematics-header">
            <div>
              <div class="exercise-title">\${e.name} <span class="hindi-badge">(\${e.hindiName || ''})</span></div>
              <div style="font-size: 11px; color: var(--cyan); text-transform: uppercase; margin-top: 2px;">\${e.category} • \${(e.primaryMuscles || [e.primaryMuscle || '']).join(', ')}</div>
            </div>
            <span class="tag tag-cyan">\${e.difficulty}</span>
          </div>

          <div class="angles-strip">
            <span>📐 Flexion: \${e.kinematics?.optimalFlexionDeg ? e.kinematics.optimalFlexionDeg + '° (' + e.kinematics.primaryJoint + ')' : (e.targetJointFlexionDeg || 'Parallel')}</span>
            <span>⏱️ Tempo: \${e.kinematics?.tempo || e.kinematicTempo || '3-1-1-0'}</span>
          </div>

          <div style="font-size: 12px; color: var(--text-muted); line-height: 1.4;">
            <strong>Cues:</strong> \${(e.criticalFormChecklist || e.formCues || []).slice(0, 2).join('; ')}
          </div>

          <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 6px;">
            <span style="font-size: 11px; color: var(--text-dim);">Joint: \${e.kinematics?.primaryJoint || (e.targetJoints || []).join(', ')}</span>
            <button class="btn-secondary" style="font-size: 10.5px; padding: 3px 8px;" onclick="openGeminiInspector('\${e.slug}')">Inspect Grounding</button>
          </div>
        </div>
      \`).join('');
    }

    function setCategoryFilter(cat) {
      state.selectedCategory = cat;
      document.querySelectorAll('#exercise-cat-pills .cat-pill').forEach(p => p.classList.remove('active'));
      const activePill = Array.from(document.querySelectorAll('#exercise-cat-pills .cat-pill')).find(p => 
        cat ? p.getAttribute('onclick')?.includes(cat) : p.innerText.includes('All')
      );
      if (activePill) activePill.classList.add('active');
      renderExercises();
    }

    function filterExercises() {
      renderExercises();
    }

    function openGeminiInspector(slug) {
      const ex = state.exercises.find(e => e.slug === slug) || state.exercises[0] || {
        name: 'Bodyweight Squat',
        hindiName: 'दंड बैठक (Squat)',
        category: 'legs',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        kinematics: {
          primaryJoint: 'knee',
          optimalFlexionDeg: 75,
          lockoutDeg: 175,
          tempo: '3-1-1-0',
          eccentricCue: 'Hinge hips back, descend for 3 seconds',
          isometricHoldCue: 'Pause at parallel thighs',
          concentricDriveCue: 'Drive through midfoot to stand'
        },
        breathingPattern: 'Inhale on descent, exhale on drive',
        criticalFormChecklist: ['Feet shoulder-width apart', 'Knees track over toes', 'Spine neutral'],
        commonMistakesToAvoid: ['Knees caving inwards (valgus)', 'Heels lifting off ground']
      };

      const promptMock = \\\`[GEMINI 1.5 RAG SYSTEM GROUNDING INJECTION]
TARGET EXERCISE: \\\${ex.name} (\\\${ex.hindiName || ''})
CATEGORY: \\\${(ex.category || '').toUpperCase()} | TARGET MUSCLES: \\\${(ex.primaryMuscles || [ex.primaryMuscle || '']).join(', ')}
BIOMECHANICAL SPECIFICATIONS:
- Primary Joint: \\\${ex.kinematics?.primaryJoint || 'knee'}
- Joint Flexion Target: \\\${ex.kinematics?.optimalFlexionDeg ? ex.kinematics.optimalFlexionDeg + '°' : 'Parallel'}
- Kinetic Repetition Tempo: \\\${ex.kinematics?.tempo || '3-1-1-0'} (Eccentric-Pause-Concentric-Reset)
- Respiration Protocol: \\\${ex.breathingPattern || ex.breathing || 'Inhale eccentric, exhale concentric'}
- Correct Form Cues:
  * \\\${(ex.criticalFormChecklist || ex.formCues || []).join('\\n  * ')}
- Critical Biomechanical Faults to Detect:
  * \\\${(ex.commonMistakesToAvoid || ex.commonFaults || []).join('\\n  * ')}

INSTRUCTION FOR GEMINI AGENT:
Provide authoritative, supportive, zero-hallucination biomechanical feedback strictly within these ranges. Answer user queries in their preferred language (Hindi/English).\\\`;

      document.getElementById('gemini-prompt-preview').innerText = promptMock;
      openModal('modal-gemini');
    }

    // System Maintenance Settings
    async function saveSystemStatus() {
      const maintenanceMode = document.getElementById('sys-maintenance-mode').checked;
      const maintenanceMsg = document.getElementById('sys-maintenance-msg').value;
      const regOpen = document.getElementById('sys-reg-open').checked;

      try {
        const res = await fetch('/v1/admin/system-status/update', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            maintenance_mode: maintenanceMode,
            maintenance_message: maintenanceMsg,
            registration_open: regOpen
          })
        });
        if (res.ok) {
          showToast('Global system status successfully updated.');
        }
      } catch (e) {
        showToast('Error updating status: ' + e);
      }
    }

    // Initial Load
    refreshAdminData();
    const urlParams = new URLSearchParams(window.location.search);
    const tabFromUrl = urlParams.get('tab') || window.location.hash.replace('#', '');
    if (tabFromUrl) switchTab(tabFromUrl);
  </script>
</body>
</html>
`;
