/**
 * VYRA Exercise Pose System
 * Injects exercise-specific bone rotations into model-viewer 3D avatars.
 * Uses Mixamo standard bone naming convention.
 * Called from Flutter via relatedJs or postMessage.
 *
 * Supported exercises: squat, pushup, plank, yoga, boxing, running,
 * cycling, swimming, skipping, weightlifting, football, cricket, dancing, tai_chi
 */

(function () {
  'use strict';

  // ── Mixamo standard bone name prefix ──────────────────────────────────
  const B = 'mixamorigHips'; // root bone check

  // ── Euler angles in radians ──────────────────────────────────────────
  const DEG = Math.PI / 180;

  // ── Exercise Pose Definitions ─────────────────────────────────────────
  // Each pose is a map of boneName → [x, y, z] euler rotation in degrees
  const POSES = {

    // ── Squat ─────────────────────────────────────────────────────────
    squat: {
      mixamorigHips:         [  0,   0,   0],
      mixamorigSpine:        [-15,   0,   0],
      mixamorigSpine1:       [-10,   0,   0],
      mixamorigLeftUpLeg:    [-85,   0,   8],
      mixamorigRightUpLeg:   [-85,   0,  -8],
      mixamorigLeftLeg:      [ 95,   0,   0],
      mixamorigRightLeg:     [ 95,   0,   0],
      mixamorigLeftArm:      [ 10,  45,   0],
      mixamorigRightArm:     [ 10, -45,   0],
      mixamorigLeftForeArm:  [ 80,   0,   0],
      mixamorigRightForeArm: [ 80,   0,   0],
    },

    // ── Push-up ────────────────────────────────────────────────────────
    pushup: {
      mixamorigHips:         [-15,   0,   0],
      mixamorigSpine:        [-10,   0,   0],
      mixamorigSpine1:       [ -5,   0,   0],
      mixamorigLeftArm:      [  0,  90,  -5],
      mixamorigRightArm:     [  0, -90,   5],
      mixamorigLeftForeArm:  [ 90,   0,   0],
      mixamorigRightForeArm: [ 90,   0,   0],
      mixamorigLeftUpLeg:    [ 10,   0,   0],
      mixamorigRightUpLeg:   [ 10,   0,   0],
      mixamorigLeftLeg:      [-10,   0,   0],
      mixamorigRightLeg:     [-10,   0,   0],
    },

    // ── Plank ─────────────────────────────────────────────────────────
    plank: {
      mixamorigHips:         [-10,   0,   0],
      mixamorigSpine:        [ -5,   0,   0],
      mixamorigSpine1:       [ -5,   0,   0],
      mixamorigLeftArm:      [  0,  90, -10],
      mixamorigRightArm:     [  0, -90,  10],
      mixamorigLeftForeArm:  [ 90,   0,   0],
      mixamorigRightForeArm: [ 90,   0,   0],
      mixamorigLeftUpLeg:    [ 15,   0,   0],
      mixamorigRightUpLeg:   [ 15,   0,   0],
    },

    // ── Yoga / Warrior II ─────────────────────────────────────────────
    yoga: {
      mixamorigHips:         [  0,  20,   0],
      mixamorigSpine:        [  0,   0,   0],
      mixamorigSpine1:       [  0,   0,   0],
      mixamorigLeftArm:      [  0,  90,  90],
      mixamorigRightArm:     [  0, -90, -90],
      mixamorigLeftForeArm:  [  0,   0,   0],
      mixamorigRightForeArm: [  0,   0,   0],
      mixamorigLeftUpLeg:    [-30,   0,  20],
      mixamorigRightUpLeg:   [ 20,   0,  -5],
      mixamorigLeftLeg:      [ 30,   0,   0],
    },

    // ── Tai Chi / Opening Form ────────────────────────────────────────
    tai_chi: {
      mixamorigHips:         [  0,   0,   0],
      mixamorigSpine:        [  5,   0,   0],
      mixamorigSpine1:       [  0,   0,   0],
      mixamorigLeftArm:      [ 20,  30,  30],
      mixamorigRightArm:     [ 20, -30, -30],
      mixamorigLeftForeArm:  [ 20,   0,   0],
      mixamorigRightForeArm: [ 20,   0,   0],
      mixamorigLeftUpLeg:    [-10,   0,   5],
      mixamorigRightUpLeg:   [-20,   0,  -5],
      mixamorigLeftLeg:      [ 15,   0,   0],
    },

    // ── Boxing / Punch Stance ─────────────────────────────────────────
    boxing: {
      mixamorigHips:         [  0,  30,   0],
      mixamorigSpine:        [ -5,  10,   0],
      mixamorigSpine1:       [ -5,   0,   0],
      mixamorigLeftArm:      [ 30,  60,  20],
      mixamorigRightArm:     [ 60, -30, -15],
      mixamorigLeftForeArm:  [ 70,   0,   0],
      mixamorigRightForeArm: [120,   0,   0],
      mixamorigLeftHand:     [  0,  20,   0],
      mixamorigRightHand:    [  0, -20,   0],
      mixamorigLeftUpLeg:    [-15,   0,  10],
      mixamorigRightUpLeg:   [-25,   0,  -5],
      mixamorigLeftLeg:      [ 20,   0,   0],
    },

    // ── Running / Sprint ─────────────────────────────────────────────
    running: {
      mixamorigHips:         [  0,   0,   0],
      mixamorigSpine:        [-15,   0,   0],
      mixamorigSpine1:       [-10,   0,   0],
      mixamorigLeftArm:      [-50,   0,  15],
      mixamorigRightArm:     [ 60,   0, -15],
      mixamorigLeftForeArm:  [ 90,   0,   0],
      mixamorigRightForeArm: [ 45,   0,   0],
      mixamorigLeftUpLeg:    [-70,   0,   5],
      mixamorigRightUpLeg:   [ 40,   0,  -5],
      mixamorigLeftLeg:      [ 80,   0,   0],
      mixamorigRightLeg:     [ 20,   0,   0],
    },

    // ── Cycling ──────────────────────────────────────────────────────
    cycling: {
      mixamorigHips:         [-20,   0,   0],
      mixamorigSpine:        [-25,   0,   0],
      mixamorigSpine1:       [-20,   0,   0],
      mixamorigLeftArm:      [-10,  20,   5],
      mixamorigRightArm:     [-10, -20,  -5],
      mixamorigLeftForeArm:  [ 30,   0,   0],
      mixamorigRightForeArm: [ 30,   0,   0],
      mixamorigLeftUpLeg:    [-60,   0,   5],
      mixamorigRightUpLeg:   [ 30,   0,  -5],
      mixamorigLeftLeg:      [ 70,   0,   0],
      mixamorigRightLeg:     [ 20,   0,   0],
    },

    // ── Swimming / Freestyle Stroke ───────────────────────────────────
    swimming: {
      mixamorigHips:         [-10,   0,   0],
      mixamorigSpine:        [-15,   0,   0],
      mixamorigSpine1:       [-10,   0,   0],
      mixamorigLeftArm:      [-80,   0,  10],
      mixamorigRightArm:     [  0, -80, -10],
      mixamorigLeftForeArm:  [ 20,   0,   0],
      mixamorigRightForeArm: [ 60,   0,   0],
      mixamorigLeftUpLeg:    [-20,   0,   5],
      mixamorigRightUpLeg:   [ 10,   0,  -5],
    },

    // ── Skipping Rope / Jump ─────────────────────────────────────────
    skipping: {
      mixamorigHips:         [-10,   0,   0],
      mixamorigSpine:        [-10,   0,   0],
      mixamorigLeftArm:      [ 20, -30,  80],
      mixamorigRightArm:     [ 20,  30, -80],
      mixamorigLeftForeArm:  [ 60,   0,   0],
      mixamorigRightForeArm: [ 60,   0,   0],
      mixamorigLeftUpLeg:    [-25,   0,   5],
      mixamorigRightUpLeg:   [-15,   0,  -5],
      mixamorigLeftLeg:      [ 30,   0,   0],
      mixamorigRightLeg:     [ 20,   0,   0],
    },

    // ── Weightlifting / Dumbbell Curl ────────────────────────────────
    weightlifting: {
      mixamorigHips:         [  0,   0,   0],
      mixamorigSpine:        [ -5,   0,   0],
      mixamorigSpine1:       [ -5,   0,   0],
      mixamorigLeftArm:      [  0,   0,  10],
      mixamorigRightArm:     [  0,   0, -10],
      mixamorigLeftForeArm:  [100,   0,   0],
      mixamorigRightForeArm: [100,   0,   0],
      mixamorigLeftHand:     [-10,   0,   0],
      mixamorigRightHand:    [-10,   0,   0],
    },

    // ── Football / Kick Stance ────────────────────────────────────────
    football: {
      mixamorigHips:         [  0,  15,   0],
      mixamorigSpine:        [-10,  -5,   0],
      mixamorigLeftArm:      [ 10,  40,  30],
      mixamorigRightArm:     [ 10, -40, -30],
      mixamorigLeftForeArm:  [ 30,   0,   0],
      mixamorigRightForeArm: [ 30,   0,   0],
      mixamorigLeftUpLeg:    [-50,   0,  10],
      mixamorigRightUpLeg:   [ 80,   0,  -5],
      mixamorigLeftLeg:      [ 30,   0,   0],
      mixamorigRightLeg:     [-60,   0,   0],
    },

    // ── Cricket / Batting Stance ──────────────────────────────────────
    cricket: {
      mixamorigHips:         [  0,  45,   0],
      mixamorigSpine:        [  0, -10,   0],
      mixamorigSpine1:       [  0,  -5,   0],
      mixamorigLeftArm:      [-20,  60,  40],
      mixamorigRightArm:     [-30, -30, -50],
      mixamorigLeftForeArm:  [ 60,   0,   0],
      mixamorigRightForeArm: [ 90,   0,   0],
      mixamorigLeftUpLeg:    [-10,   0,  15],
      mixamorigRightUpLeg:   [-10,   0, -15],
      mixamorigLeftLeg:      [ 15,   0,   0],
      mixamorigRightLeg:     [ 20,   0,   0],
    },

    // ── Dance / Samba Arms Up ─────────────────────────────────────────
    dancing: {
      mixamorigHips:         [  0,  20,  10],
      mixamorigSpine:        [  0,  10,   5],
      mixamorigLeftArm:      [ 20,  60,  80],
      mixamorigRightArm:     [ 20, -30, -60],
      mixamorigLeftForeArm:  [ 30,   0,   0],
      mixamorigRightForeArm: [ 30,   0,   0],
      mixamorigLeftUpLeg:    [-10,  10,   5],
      mixamorigRightUpLeg:   [-20, -10,  -5],
    },
  };

  // ── Scene lookup helper across different model-viewer versions ────────
  function getThreeScene(mv) {
    if (!mv) return null;
    if (mv.scene && mv.scene.traverse) return mv.scene;
    // Check internal Symbols on model-viewer element
    try {
      const syms = Object.getOwnPropertySymbols(mv);
      for (let i = 0; i < syms.length; i++) {
        const val = mv[syms[i]];
        if (val && typeof val === 'object') {
          if (val.isScene || val.isObject3D) return val;
          if (val.scene && val.scene.traverse) return val.scene;
        }
      }
    } catch (_) {}
    // Check mv.model
    if (mv.model) {
      if (mv.model.scene && mv.model.scene.traverse) return mv.model.scene;
      if (mv.model.children && mv.model.traverse) return mv.model;
      try {
        const modelSyms = Object.getOwnPropertySymbols(mv.model);
        for (let i = 0; i < modelSyms.length; i++) {
          const val = mv.model[modelSyms[i]];
          if (val && typeof val === 'object') {
            if (val.isScene || val.isObject3D) return val;
            if (val.scene && val.scene.traverse) return val.scene;
          }
        }
      } catch (_) {}
    }
    return mv.model || null;
  }

  // ── Bone lookup helper (matches both mixamorig:Name and mixamorigName) ─
  function findBone(root, targetName) {
    if (!root) return null;
    const cleanTarget = targetName.replace(/^mixamorig:?/i, '').toLowerCase();
    let found = null;
    if (root.traverse) {
      root.traverse(function(node) {
        if (found) return;
        const n = node.name || '';
        const cleanNode = n.replace(/^mixamorig:?/i, '').toLowerCase();
        if (cleanNode === cleanTarget || n === targetName || n.toLowerCase() === targetName.toLowerCase()) {
          found = node;
        }
      });
    } else {
      // Fallback recursive search if traverse is not available
      function recurse(node) {
        if (!node || found) return;
        const n = node.name || '';
        const cleanNode = n.replace(/^mixamorig:?/i, '').toLowerCase();
        if (cleanNode === cleanTarget || n === targetName) {
          found = node;
          return;
        }
        for (const child of (node.children || [])) {
          recurse(child);
        }
      }
      recurse(root);
    }
    return found;
  }

  let activeAnimationId = null;

  // ── Apply pose rotations to the model (instant base position) ───────
  function applyPose(mv, poseKey) {
    if (!mv) return;
    const pose = POSES[poseKey];
    if (!pose) return;

    const root = getThreeScene(mv);
    if (!root) return;

    try {
      for (const [boneName, rot] of Object.entries(pose)) {
        const bone = findBone(root, boneName);
        if (bone && bone.rotation) {
          bone.rotation.set(
            rot[0] * DEG,
            rot[1] * DEG,
            rot[2] * DEG
          );
        }
      }
    } catch (e) {
      // Bone manipulation not available, skip gracefully
    }
  }

  // ── Continuous Exercise Repetition Engine (60 FPS animated reps) ─────
  function startRepetitionLoop(mv, poseKey) {
    if (activeAnimationId) {
      cancelAnimationFrame(activeAnimationId);
      activeAnimationId = null;
    }

    const pose = POSES[poseKey];
    if (!pose) return;

    const root = getThreeScene(mv);
    if (!root) return;

    // Cache bone references once to eliminate per-frame overhead
    const boneMap = {};
    for (const boneName of Object.keys(pose)) {
      const b = findBone(root, boneName);
      if (b && b.rotation) boneMap[boneName] = b;
    }

    const startTime = performance.now();

    function repLoop(now) {
      const elapsed = (now - startTime) / 1000;
      // Standard tempo: 1 full rep every 2.8 seconds
      const wave = Math.sin(elapsed * (Math.PI * 2 / 2.8)); // -1 to +1
      const factor = (wave + 1) / 2; // 0.0 (top) to 1.0 (bottom of rep)

      for (const [boneName, baseRot] of Object.entries(pose)) {
        const bone = boneMap[boneName];
        if (!bone) continue;

        let xMult = 1.0;
        let yMult = 1.0;
        let zMult = 1.0;

        if (poseKey === 'squat') {
          // Knees and hips flex smoothly between standing and full depth
          if (boneName.includes('Leg')) {
            xMult = 0.30 + 0.70 * factor;
          }
          if (boneName.includes('Spine')) {
            xMult = 0.40 + 0.60 * factor;
          }
        } else if (poseKey === 'pushup') {
          // Arms compress down to floor and push up
          if (boneName.includes('ForeArm') || boneName.includes('Arm')) {
            xMult = 0.35 + 0.65 * factor;
          }
        } else if (poseKey === 'weightlifting') {
          // Bicep curl from bottom extension to top contraction
          if (boneName.includes('ForeArm')) {
            xMult = 0.20 + 0.80 * factor;
          }
        } else if (poseKey === 'swimming') {
          // Continuous alternating freestyle stroke cycle
          const stroke = Math.sin(elapsed * 3.5);
          if (boneName.includes('LeftArm')) {
            xMult = stroke;
          } else if (boneName.includes('RightArm')) {
            xMult = -stroke;
          }
        } else if (poseKey === 'boxing') {
          // Dynamic jab-cross rhythmic punching cadence
          const jab = Math.sin(elapsed * 5.0);
          if (boneName.includes('RightForeArm')) {
            xMult = 0.7 + 0.3 * Math.max(0, jab);
          } else if (boneName.includes('LeftForeArm')) {
            xMult = 0.7 + 0.3 * Math.max(0, -jab);
          }
        } else if (poseKey === 'yoga' || poseKey === 'tai_chi' || poseKey === 'plank') {
          // Deep diaphragmatic breathing & alignment expansion
          if (boneName.includes('Spine') || boneName.includes('Arm')) {
            xMult = 0.92 + 0.08 * factor;
          }
        } else if (poseKey === 'skipping') {
          // Rapid wrist & forearm rotation
          if (boneName.includes('ForeArm') || boneName.includes('Hand')) {
            zMult = 0.7 + 0.3 * Math.sin(elapsed * 6.0);
          }
        }

        bone.rotation.set(
          baseRot[0] * xMult * DEG,
          baseRot[1] * yMult * DEG,
          baseRot[2] * zMult * DEG
        );
      }

      activeAnimationId = requestAnimationFrame(repLoop);
    }

    activeAnimationId = requestAnimationFrame(repLoop);
  }

  // ── Public API exposed to Flutter / model-viewer ─────────────────────
  window.VyraExercisePose = {
    apply: function(poseKey) {
      const mv = document.querySelector('model-viewer');
      if (!mv) return;
      function doApply() {
        applyPose(mv, poseKey);
        startRepetitionLoop(mv, poseKey);
      }
      if (mv.loaded) {
        doApply();
      } else {
        mv.addEventListener('load', doApply, { once: true });
      }
    },
    stop: function() {
      if (activeAnimationId) {
        cancelAnimationFrame(activeAnimationId);
        activeAnimationId = null;
      }
    },
    poses: Object.keys(POSES),
  };
})();
