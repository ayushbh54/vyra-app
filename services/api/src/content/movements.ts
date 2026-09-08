/**
 * =============================================================================
 * VYRA MOVEMENT DEFINITIONS — the code-driven 3D exercise avatar's data layer
 * =============================================================================
 * Each entry drives the SAME reusable rig (see the Flutter WebView island
 * that hosts the three.js scene) through a different sequence of joint
 * targets. Adding an animated exercise means adding an entry here — never
 * writing new rendering code.
 *
 * `jointTargets` angles are in degrees, on the same joint names the rig
 * exposes: leftElbow/rightElbow, leftShoulder/rightShoulder, leftHip/
 * rightHip, leftKnee/rightKnee. A joint omitted from a phase holds its
 * previous target — the renderer tweens between phases, it does not require
 * every joint to be specified every time.
 *
 * MVP scope is deliberately 3 exercises (bicep curl, squat, push-up) to
 * validate the architecture before authoring more.
 * =============================================================================
 */

import type { MovementDefinition } from '../store';

export const MOVEMENT_DEFINITIONS: MovementDefinition[] = [
  {
    exerciseSlug: 'dumbbell-bicep-curl',
    rigId: 'humanoid_v1',
    tempo: '2-1-3-0',
    targetMuscle: 'Biceps',
    cameraViews: ['front', 'side_90', 'diag_45', 'orbit_360'],
    phases: [
      {
        id: 'hang', label: '1. Hang',
        cue: 'Start with arms fully extended, elbows pinned to your torso.',
        jointTargets: { leftElbow: 175, rightElbow: 175 },
        durationSec: 1,
      },
      {
        id: 'lift', label: '2. Lift (Active)',
        cue: 'Smooth upward curl without body sway.',
        jointTargets: { leftElbow: 40, rightElbow: 40 },
        durationSec: 2,
      },
      {
        id: 'peak', label: '3. Peak',
        cue: 'Squeeze the bicep at peak flexion.',
        jointTargets: { leftElbow: 35, rightElbow: 35 },
        durationSec: 1,
      },
      {
        id: 'lower', label: '4. Lower',
        cue: 'Three-second controlled release back to a full hang.',
        jointTargets: { leftElbow: 175, rightElbow: 175 },
        durationSec: 3,
      },
    ],
    correctMechanics: [
      'Elbows tucked closely against the ribcage without flaring.',
      'Neutral wrist alignment — prevent backward hyperextension under load.',
      'Three-second controlled eccentric release back to a full hang.',
    ],
    avoidCheats: [
      'Lower-back hip swinging or torso momentum generation.',
      'Shoulders rounding forward or hiking towards the ears during the lift.',
    ],
  },
  {
    exerciseSlug: 'bodyweight-squat',
    rigId: 'humanoid_v1',
    tempo: '2-1-2-0',
    targetMuscle: 'Quadriceps & Glutes',
    cameraViews: ['front', 'side_90', 'diag_45'],
    phases: [
      {
        id: 'stand', label: '1. Stand',
        cue: 'Feet shoulder-width apart, chest tall, weight in your heels.',
        jointTargets: { leftHip: 175, rightHip: 175, leftKnee: 175, rightKnee: 175 },
        durationSec: 1,
      },
      {
        id: 'descend', label: '2. Descend',
        cue: 'Push your hips back and bend your knees, as if sitting into a chair.',
        jointTargets: { leftHip: 95, rightHip: 95, leftKnee: 95, rightKnee: 95 },
        durationSec: 2,
      },
      {
        id: 'bottom', label: '3. Bottom',
        cue: 'Thighs roughly parallel to the floor, knees tracking over your toes.',
        jointTargets: { leftHip: 90, rightHip: 90, leftKnee: 90, rightKnee: 90 },
        durationSec: 1,
      },
      {
        id: 'drive', label: '4. Drive up',
        cue: 'Push through your heels to stand back up.',
        jointTargets: { leftHip: 175, rightHip: 175, leftKnee: 175, rightKnee: 175 },
        durationSec: 2,
      },
    ],
    correctMechanics: [
      'Knees track in line with your toes, never caving inward.',
      'Chest stays tall — the movement comes from the hips, not the lower back rounding.',
      'Weight stays in your heels through the entire rep.',
    ],
    avoidCheats: [
      'Heels lifting off the floor at the bottom of the squat.',
      'Knees collapsing inward under load.',
    ],
  },
  {
    exerciseSlug: 'push-up',
    rigId: 'humanoid_v1',
    tempo: '1-0-2-0',
    targetMuscle: 'Chest & Triceps',
    cameraViews: ['side_90', 'diag_45'],
    phases: [
      {
        id: 'plank', label: '1. Plank',
        cue: 'Body in one straight line from head to heels, hands under your shoulders.',
        jointTargets: { leftElbow: 175, rightElbow: 175, leftShoulder: 60, rightShoulder: 60 },
        durationSec: 1,
      },
      {
        id: 'lower', label: '2. Lower',
        cue: 'Lower your chest towards the floor with control.',
        jointTargets: { leftElbow: 90, rightElbow: 90 },
        durationSec: 1,
      },
      {
        id: 'bottom', label: '3. Bottom',
        cue: 'Elbows at roughly forty-five degrees from your torso, not flared to ninety.',
        jointTargets: { leftElbow: 80, rightElbow: 80 },
        durationSec: 1,
      },
      {
        id: 'press', label: '4. Press up',
        cue: 'Press back up without letting your hips drop or pike.',
        jointTargets: { leftElbow: 175, rightElbow: 175 },
        durationSec: 2,
      },
    ],
    correctMechanics: [
      'Straight line from head to heels throughout the entire rep.',
      'Elbows at roughly a forty-five-degree angle from the torso.',
      'Neck stays neutral — eyes toward the floor, not straight ahead.',
    ],
    avoidCheats: [
      'Hips sagging toward the floor or piking up.',
      'Only lowering halfway on every rep.',
    ],
  },
];
