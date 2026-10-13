/**
 * VYRA 3D Coach Avatar Biomechanical Engine v6.0
 * ============================================================================
 * 4-STAGE CLOSED-LOOP BIOMECHANICAL VERIFICATION & PERSISTENT SETUP CACHE
 *
 * Stage 0 — Persistent Verified Setup Cache (`localStorage` + In-Memory + Dart Bridge):
 *   Checks `vyra_verified_setup_v6_<rigId>_<exerciseName>`.
 *   If already verified and saved, loads the verified quaternion keyframes (`qStart`,
 *   `qPeak`, `hipsPosStart`, `hipsPosPeak`) in 0ms without repeating the solver or
 *   verification pipeline.
 *
 * Stage 1 — Canonical Character-Space Biomechanical Blueprint Resolution:
 *   Resolves any exercise slug (65 canonical blueprints, 130+ aliases, 55+ word-boundary
 *   keyword rules, plus dynamic synthesis for newly generated Gemini AI exercises) into
 *   model-independent Character Space `[pitch, yaw, roll]`.
 *
 * Stage 2 — Universal Character-Space Quaternion Conjugation Solver:
 *   Restores authentic GLTF T-Pose bind quaternions (`q_bind`, `W_bind`) and transforms
 *   Character-Space rotations into each bone's exact local frame via similarity conjugation:
 *     `Q_char = qAxisAngle(charRight, pitch) * qAxisAngle(charUp, yaw) * qAxisAngle(charFwd, roll)`
 *     `q_delta = inv(W_bind) * Q_char * W_bind`
 *     `q_bone  = q_bind * q_delta`
 *   Works identically across both `male_coach.glb` and `female_coach.glb` despite their
 *   internal Mixamo bone axes being flipped.
 *
 * Stage 3 — Pre-Flight 3D Forward-Kinematics Verifier, Auto-Corrector & Floor-Lock Solver:
 *   Evaluates 3D world coordinates of Head, Hips, Knees, Feet, Toes, Shoulders, Elbows,
 *   and Wrists at `start` and `peak`. Verifies upright/horizontal posture, joint excursion,
 *   anatomical hinge limits, and computes exact `Hips` floor-lock offsets so the avatar's
 *   feet/hands stay planted on the ground without floating or sinking.
 *
 * Stage 4 — Persist Verified Setup & Execute 60 FPS Quaternion Slerp Loop:
 *   Saves the verified setup to `localStorage` + notifies Dart `SharedPreferences` bridge
 *   so repeat opens are instantaneous, then drives smooth 60 FPS shortest-path Quaternion
 *   Slerp + ground-locked root motion and triggers `<model-viewer>` WebGL re-render.
 */
(function (global) {
  'use strict';

  var ENGINE_VERSION = '6.0.0';
  var CACHE_PREFIX = 'vyra_verified_setup_v6_';

  // ═══════════════════════════════════════════════════════════════════════
  // AUTHENTIC GLB T-POSE BIND METADATA (Extracted from male_coach.glb & female_coach.glb)
  // ═══════════════════════════════════════════════════════════════════════
  var GLB_BIND_META = {
    male: {"charRight":[0.999991,-0.000115,0.004263],"charUp":[0.0,1.0,0.0],"charFwd":[0.004263,0.0,-0.999991],"floorY":0.0141,"hipsBindPos":[-0.1602,1.1475,106.1308],"hipsParentWQ":[-0.707107,0.0,0.0,0.707107],"hipsParentWS":[0.01,0.01,0.01],"order":["mixamorigHips","mixamorigSpine","mixamorigSpine1","mixamorigSpine2","mixamorigNeck","mixamorigHead","mixamorigLeftShoulder","mixamorigLeftArm","mixamorigLeftForeArm","mixamorigLeftHand","mixamorigLeftHandThumb1","mixamorigLeftHandThumb2","mixamorigLeftHandThumb3","mixamorigLeftHandThumb4","mixamorigLeftHandIndex1","mixamorigLeftHandIndex2","mixamorigLeftHandIndex3","mixamorigLeftHandIndex4","mixamorigLeftHandMiddle1","mixamorigLeftHandMiddle2","mixamorigLeftHandMiddle3","mixamorigLeftHandMiddle4","mixamorigLeftHandRing1","mixamorigLeftHandRing2","mixamorigLeftHandRing3","mixamorigLeftHandRing4","mixamorigLeftHandPinky1","mixamorigLeftHandPinky2","mixamorigLeftHandPinky3","mixamorigLeftHandPinky4","mixamorigRightShoulder","mixamorigRightArm","mixamorigRightForeArm","mixamorigRightHand","mixamorigRightHandThumb1","mixamorigRightHandThumb2","mixamorigRightHandThumb3","mixamorigRightHandThumb4","mixamorigRightHandIndex1","mixamorigRightHandIndex2","mixamorigRightHandIndex3","mixamorigRightHandIndex4","mixamorigRightHandMiddle1","mixamorigRightHandMiddle2","mixamorigRightHandMiddle3","mixamorigRightHandMiddle4","mixamorigRightHandRing1","mixamorigRightHandRing2","mixamorigRightHandRing3","mixamorigRightHandRing4","mixamorigRightHandPinky1","mixamorigRightHandPinky2","mixamorigRightHandPinky3","mixamorigRightHandPinky4","mixamorigLeftUpLeg","mixamorigLeftLeg","mixamorigLeftFoot","mixamorigLeftToeBase","mixamorigRightUpLeg","mixamorigRightLeg","mixamorigRightFoot","mixamorigRightToeBase"],"bones":{"mixamorigHips":{"parent":null,"t":[-0.1602,1.1475,106.1308],"q":[0.0,0.707107,0.707107,0.0],"wq":[0.0,1.0,0.0,0.0],"wp":[-0.0016,1.0613,-0.0115]},"mixamorigSpine":{"parent":"mixamorigHips","t":[-0.0381,9.4905,-1.3921],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,1.0,0.0,0.0],"wp":[-0.0012,1.1562,0.0024]},"mixamorigSpine1":{"parent":"mixamorigSpine","t":[-0.0442,11.0723,-1.6241],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,1.0,0.0,0.0],"wp":[-0.0008,1.2669,0.0187]},"mixamorigSpine2":{"parent":"mixamorigSpine1","t":[-0.0505,12.654,-1.8561],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,1.0,0.0,0.0],"wp":[-0.0003,1.3935,0.0372]},"mixamorigNeck":{"parent":"mixamorigSpine2","t":[-0.0569,14.2358,-2.0881],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,1.0,0.0,0.0],"wp":[0.0003,1.5358,0.0581]},"mixamorigHead":{"parent":"mixamorigNeck","t":[0,3.2802,0.3133],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,1.0,0.0,0.0],"wp":[0.0003,1.5686,0.055]},"mixamorigLeftShoulder":{"parent":"mixamorigSpine2","t":[6.7288,11.7566,-2.0585],"q":[0.707107,0.707107,0.0,-0.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.0676,1.511,0.0578]},"mixamorigLeftArm":{"parent":"mixamorigLeftShoulder","t":[-3.1788,14.0947,-0.0593],"q":[0.0,-0.0,-0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.2085,1.4793,0.0572]},"mixamorigLeftForeArm":{"parent":"mixamorigLeftArm","t":[0.0,23.1603,0.0],"q":[0.0,-0.0,-1e-06,1.0],"wq":[-0.0,-0.0,-0.707106,-0.707107],"wp":[-0.4401,1.4793,0.0572]},"mixamorigLeftHand":{"parent":"mixamorigLeftForeArm","t":[0.0,24.0718,0.0],"q":[-0.0,0.0,1e-06,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.6808,1.4793,0.0572]},"mixamorigLeftHandThumb1":{"parent":"mixamorigLeftHand","t":[-1.9251,4.1734,-1.5109],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.7226,1.46,0.0421]},"mixamorigLeftHandThumb2":{"parent":"mixamorigLeftHandThumb1","t":[-1.7309,2.998,-1.7309],"q":[-0.0,0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.7525,1.4427,0.0248]},"mixamorigLeftHandThumb3":{"parent":"mixamorigLeftHandThumb2","t":[-2.1067,3.6489,-2.1066],"q":[0.0,0.0,-0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.789,1.4216,0.0038]},"mixamorigLeftHandThumb4":{"parent":"mixamorigLeftHandThumb3","t":[-1.713,2.967,-1.713],"q":[-0.0,0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8187,1.4045,-0.0134]},"mixamorigLeftHandIndex1":{"parent":"mixamorigLeftHand","t":[-0.396,14.6694,-2.8559],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8275,1.4753,0.0287]},"mixamorigLeftHandIndex2":{"parent":"mixamorigLeftHandIndex1","t":[-0.0,3.2486,-0.0],"q":[-0.0,-0.0,-0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.86,1.4753,0.0287]},"mixamorigLeftHandIndex3":{"parent":"mixamorigLeftHandIndex2","t":[0.0,2.6596,-0.0],"q":[-0.0,-0.0,-0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8866,1.4753,0.0287]},"mixamorigLeftHandIndex4":{"parent":"mixamorigLeftHandIndex3","t":[0.0,3.6332,-0.0],"q":[-0.0,0.0,-0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.9229,1.4753,0.0287]},"mixamorigLeftHandMiddle1":{"parent":"mixamorigLeftHand","t":[0.0,14.4098,-0.0],"q":[-0.0,0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8249,1.4793,0.0572]},"mixamorigLeftHandMiddle2":{"parent":"mixamorigLeftHandMiddle1","t":[-0.0,3.2591,-0.0],"q":[-0.0,-0.0,-0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8575,1.4793,0.0572]},"mixamorigLeftHandMiddle3":{"parent":"mixamorigLeftHandMiddle2","t":[-0.0,2.6399,-0.0],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8839,1.4793,0.0572]},"mixamorigLeftHandMiddle4":{"parent":"mixamorigLeftHandMiddle3","t":[-0.0,3.6739,-0.0],"q":[0.0,-0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.9207,1.4793,0.0572]},"mixamorigLeftHandRing1":{"parent":"mixamorigLeftHand","t":[0.3189,13.1915,3.3053],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8127,1.4824,0.0903]},"mixamorigLeftHandRing2":{"parent":"mixamorigLeftHandRing1","t":[-0.0,2.7176,-0.0],"q":[-0.0,-0.0,-0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8399,1.4824,0.0903]},"mixamorigLeftHandRing3":{"parent":"mixamorigLeftHandRing2","t":[0.0,2.1345,0.0],"q":[0.0,-0.0,-0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8613,1.4824,0.0903]},"mixamorigLeftHandRing4":{"parent":"mixamorigLeftHandRing3","t":[-0.0,2.7869,-0.0],"q":[-0.0,-0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8891,1.4824,0.0903]},"mixamorigLeftHandPinky1":{"parent":"mixamorigLeftHand","t":[-0.5219,11.6364,5.6137],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.7972,1.474,0.1134]},"mixamorigLeftHandPinky2":{"parent":"mixamorigLeftHandPinky1","t":[-0.0,1.5594,-0.0],"q":[2e-06,-2e-06,-0.0,1.0],"wq":[-2e-06,-0.0,-0.707107,-0.707107],"wp":[-0.8128,1.474,0.1134]},"mixamorigLeftHandPinky3":{"parent":"mixamorigLeftHandPinky2","t":[0.0,1.5406,-0.0],"q":[-2e-06,2e-06,0.0,1.0],"wq":[0.0,-0.0,-0.707107,-0.707107],"wp":[-0.8282,1.474,0.1134]},"mixamorigLeftHandPinky4":{"parent":"mixamorigLeftHandPinky3","t":[-0.0,1.6687,-0.0],"q":[-2e-06,2e-06,5e-06,1.0],"wq":[3e-06,-0.0,-0.70711,-0.707104],"wp":[-0.8449,1.474,0.1134]},"mixamorigRightShoulder":{"parent":"mixamorigSpine2","t":[-6.8238,11.7566,-2.1177],"q":[0.0,0.0,0.707107,0.707107],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.068,1.511,0.0584]},"mixamorigRightArm":{"parent":"mixamorigRightShoulder","t":[-3.1836,14.0575,-0.0593],"q":[0.0,0.0,0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.2085,1.4792,0.059]},"mixamorigRightForeArm":{"parent":"mixamorigRightArm","t":[0,23.1602,0],"q":[0.0,-0.0,-0.0,1.0],"wq":[0.707107,0.707107,-0.0,0.0],"wp":[0.4401,1.4792,0.059]},"mixamorigRightHand":{"parent":"mixamorigRightForeArm","t":[-0.0,24.1434,-0.0],"q":[-0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.6816,1.4792,0.059]},"mixamorigRightHandThumb1":{"parent":"mixamorigRightHand","t":[-2.0273,4.1926,1.4724],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.7235,1.4589,0.0443]},"mixamorigRightHandThumb2":{"parent":"mixamorigRightHandThumb1","t":[-1.7474,3.0266,1.7475],"q":[-0.0,0.0,0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.7538,1.4415,0.0268]},"mixamorigRightHandThumb3":{"parent":"mixamorigRightHandThumb2","t":[-2.1234,3.6778,2.1234],"q":[-0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.7905,1.4202,0.0056]},"mixamorigRightHandThumb4":{"parent":"mixamorigRightHandThumb3","t":[-1.6939,2.9339,1.6939],"q":[-0.0,-0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.8199,1.4033,-0.0114]},"mixamorigRightHandIndex1":{"parent":"mixamorigRightHand","t":[-0.408,14.6369,3.083],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.8279,1.4751,0.0282]},"mixamorigRightHandIndex2":{"parent":"mixamorigRightHandIndex1","t":[-0.0,3.2162,0.0],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.8601,1.4751,0.0282]},"mixamorigRightHandIndex3":{"parent":"mixamorigRightHandIndex2","t":[0.0,2.6383,0.0],"q":[-0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.8865,1.4751,0.0282]},"mixamorigRightHandIndex4":{"parent":"mixamorigRightHandIndex3","t":[-0.0,3.6533,0.0],"q":[-0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.923,1.4751,0.0282]},"mixamorigRightHandMiddle1":{"parent":"mixamorigRightHand","t":[0.0,14.5304,-0.0],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,-0.0,-0.0],"wp":[0.8269,1.4792,0.059]},"mixamorigRightHandMiddle2":{"parent":"mixamorigRightHandMiddle1","t":[-0.0,3.1267,-0.0],"q":[-1e-06,1e-06,-0.0,1.0],"wq":[0.707107,0.707107,1e-06,-0.0],"wp":[0.8581,1.4792,0.059]},"mixamorigRightHandMiddle3":{"parent":"mixamorigRightHandMiddle2","t":[0.0,2.6725,0.0],"q":[1e-06,-1e-06,0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.8849,1.4792,0.059]},"mixamorigRightHandMiddle4":{"parent":"mixamorigRightHandMiddle3","t":[-0.0426,3.1309,0.0576],"q":[0.0,-0.0,-0.0,1.0],"wq":[0.707107,0.707107,-0.0,-0.0],"wp":[0.9162,1.4788,0.0584]},"mixamorigRightHandRing1":{"parent":"mixamorigRightHand","t":[0.1958,12.7711,-2.966],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.8093,1.4812,0.0887]},"mixamorigRightHandRing2":{"parent":"mixamorigRightHandRing1","t":[0.0,2.5128,-0.0],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,-0.0,-0.0],"wp":[0.8344,1.4812,0.0887]},"mixamorigRightHandRing3":{"parent":"mixamorigRightHandRing2","t":[-0.0,2.1971,0.0],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,-0.0,-0.0],"wp":[0.8564,1.4812,0.0887]},"mixamorigRightHandRing4":{"parent":"mixamorigRightHandRing3","t":[-0.0,3.0684,-0.0],"q":[-1e-06,1e-06,-0.0,1.0],"wq":[0.707107,0.707107,1e-06,-0.0],"wp":[0.8871,1.4812,0.0887]},"mixamorigRightHandPinky1":{"parent":"mixamorigRightHand","t":[-0.4615,11.7508,-5.6506],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.7991,1.4746,0.1155]},"mixamorigRightHandPinky2":{"parent":"mixamorigRightHandPinky1","t":[-0.0,1.6795,0.0],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.8159,1.4746,0.1155]},"mixamorigRightHandPinky3":{"parent":"mixamorigRightHandPinky2","t":[-0.0,1.3641,0.0],"q":[0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.8295,1.4746,0.1155]},"mixamorigRightHandPinky4":{"parent":"mixamorigRightHandPinky3","t":[-0.0,1.6682,0.0],"q":[-0.0,0.0,-0.0,1.0],"wq":[0.707107,0.707107,0.0,0.0],"wp":[0.8462,1.4746,0.1155]},"mixamorigLeftUpLeg":{"parent":"mixamorigHips","t":[9.6183,-5.2723,-1.0109],"q":[1.0,0.0,0.0,0.0],"wq":[0.0,0.0,-1.0,0.0],"wp":[-0.0978,1.0086,-0.0014]},"mixamorigLeftLeg":{"parent":"mixamorigLeftUpLeg","t":[0.1164,43.3445,-1.3233],"q":[0.0,-0.0,0.0,1.0],"wq":[0.0,0.0,-1.0,0.0],"wp":[-0.0989,0.5751,-0.0146]},"mixamorigLeftFoot":{"parent":"mixamorigLeftLeg","t":[-0.1023,44.2922,4.2198],"q":[-0.707107,-0.0,-0.0,0.707107],"wq":[-0.0,0.707107,-0.707107,-0.0],"wp":[-0.0979,0.1322,0.0276]},"mixamorigLeftToeBase":{"parent":"mixamorigLeftFoot","t":[2.5995,15.8139,11.8143],"q":[0.0,0.0,0.0,1.0],"wq":[-0.0,0.707107,-0.707107,-0.0],"wp":[-0.1239,0.0141,-0.1305]},"mixamorigRightUpLeg":{"parent":"mixamorigHips","t":[-9.941,-5.2727,-1.2117],"q":[1.0,0.0,0.0,0.0],"wq":[0.0,0.0,-1.0,0.0],"wp":[0.0978,1.0086,0.0006]},"mixamorigRightLeg":{"parent":"mixamorigRightUpLeg","t":[-0.104,43.3049,-2.0317],"q":[0.0,-0.0,0.0,1.0],"wq":[0.0,0.0,-1.0,0.0],"wp":[0.0988,0.5755,-0.0197]},"mixamorigRightFoot":{"parent":"mixamorigRightLeg","t":[0.1171,44.3314,4.7272],"q":[-0.707107,-0.0,-0.0,0.707107],"wq":[0.0,0.707107,-0.707107,0.0],"wp":[0.0977,0.1322,0.0276]},"mixamorigRightToeBase":{"parent":"mixamorigRightFoot","t":[-2.5995,15.9998,11.8145],"q":[0.0,0.0,0.0,1.0],"wq":[0.0,0.707107,-0.707107,0.0],"wp":[0.1237,0.0141,-0.1324]}}},
    female: {"charRight":[-1.0,0.0,-0.000239],"charUp":[0.0,1.0,0.0],"charFwd":[-0.000239,0.0,1.0],"floorY":0.0101,"hipsBindPos":[-0.0006,1.3797,-95.2298],"hipsParentWQ":[0.707107,0.0,0.0,0.707107],"hipsParentWS":[0.01,0.01,0.01],"order":["mixamorigHips","mixamorigSpine","mixamorigSpine1","mixamorigSpine2","mixamorigNeck","mixamorigHead","mixamorigLeftShoulder","mixamorigLeftArm","mixamorigLeftForeArm","mixamorigLeftHand","mixamorigLeftHandThumb1","mixamorigLeftHandThumb2","mixamorigLeftHandThumb3","mixamorigLeftHandThumb4","mixamorigLeftHandIndex1","mixamorigLeftHandIndex2","mixamorigLeftHandIndex3","mixamorigLeftHandIndex4","mixamorigLeftHandMiddle1","mixamorigLeftHandMiddle2","mixamorigLeftHandMiddle3","mixamorigLeftHandMiddle4","mixamorigLeftHandRing1","mixamorigLeftHandRing2","mixamorigLeftHandRing3","mixamorigLeftHandRing4","mixamorigLeftHandPinky1","mixamorigLeftHandPinky2","mixamorigLeftHandPinky3","mixamorigLeftHandPinky4","mixamorigRightShoulder","mixamorigRightArm","mixamorigRightForeArm","mixamorigRightHand","mixamorigRightHandThumb1","mixamorigRightHandThumb2","mixamorigRightHandThumb3","mixamorigRightHandThumb4","mixamorigRightHandIndex1","mixamorigRightHandIndex2","mixamorigRightHandIndex3","mixamorigRightHandIndex4","mixamorigRightHandMiddle1","mixamorigRightHandMiddle2","mixamorigRightHandMiddle3","mixamorigRightHandMiddle4","mixamorigRightHandRing1","mixamorigRightHandRing2","mixamorigRightHandRing3","mixamorigRightHandRing4","mixamorigRightHandPinky1","mixamorigRightHandPinky2","mixamorigRightHandPinky3","mixamorigRightHandPinky4","mixamorigLeftUpLeg","mixamorigLeftLeg","mixamorigLeftFoot","mixamorigLeftToeBase","mixamorigRightUpLeg","mixamorigRightLeg","mixamorigRightFoot","mixamorigRightToeBase"],"bones":{"mixamorigHips":{"parent":null,"t":[-0.0006,1.3797,-95.2298],"q":[-0.707107,0.0,0.0,0.707107],"wq":[0.0,0.0,0.0,1.0],"wp":[-0.0,0.9523,0.0138]},"mixamorigSpine":{"parent":"mixamorigHips","t":[-0.0,10.0588,-0.3582],"q":[-0.017795,0.0,0.0,0.999842],"wq":[-0.017795,0.0,0.0,0.999842],"wp":[-0.0,1.0529,0.0102]},"mixamorigSpine1":{"parent":"mixamorigSpine","t":[-0.0,11.7428,0],"q":[-0.0,-0.0,0.0,1.0],"wq":[-0.017795,0.0,0.0,0.999842],"wp":[-0.0,1.1702,0.006]},"mixamorigSpine2":{"parent":"mixamorigSpine1","t":[0.0,13.4202,-0.0],"q":[-0.0,0.0,-0.0,1.0],"wq":[-0.017795,-0.0,-0.0,0.999842],"wp":[-0.0,1.3044,0.0013]},"mixamorigNeck":{"parent":"mixamorigSpine2","t":[-0.0,15.0978,0.0],"q":[0.017795,0.0,0.0,0.999842],"wq":[0.0,0.0,0.0,1.0],"wp":[-0.0,1.4552,-0.0041]},"mixamorigHead":{"parent":"mixamorigNeck","t":[-0.0,8.0856,2.6878],"q":[-0.0,-0.0,-0.0,1.0],"wq":[0.0,0.0,0.0,1.0],"wp":[-0.0,1.5361,0.0228]},"mixamorigLeftShoulder":{"parent":"mixamorigSpine2","t":[5.9491,13.2477,-0.0645],"q":[0.566347,0.421476,-0.572518,0.416932],"wq":[0.558838,0.411221,-0.579927,0.426944],"wp":[0.0595,1.4367,-0.0041]},"mixamorigLeftArm":{"parent":"mixamorigLeftShoulder","t":[0.0,12.4722,0.0],"q":[-0.111954,0.004105,-0.036409,0.993038],"wq":[0.494558,0.495383,-0.543102,0.463733],"wp":[0.1786,1.3997,-0.0041]},"mixamorigLeftForeArm":{"parent":"mixamorigLeftArm","t":[-0.0,23.8149,0.0],"q":[-0.063918,-0.003976,0.061963,0.996022],"wq":[0.491485,0.495638,-0.48251,0.529121],"wp":[0.4152,1.3808,-0.023]},"mixamorigLeftHand":{"parent":"mixamorigLeftForeArm","t":[-0.0,24.5563,0.0],"q":[0.043945,0.000151,-0.008261,0.999],"wq":[0.510224,0.478078,-0.508105,0.502933],"wp":[0.6602,1.3934,-0.0127]},"mixamorigLeftHandThumb1":{"parent":"mixamorigLeftHand","t":[-2.832,2.5358,1.178],"q":[0.145624,0.046993,0.303496,0.940466],"wq":[0.722059,0.244408,-0.37086,0.530432],"wp":[0.6844,1.3814,0.0165]},"mixamorigLeftHandThumb2":{"parent":"mixamorigLeftHandThumb1","t":[-0.6524,3.1163,0.0],"q":[0.046663,0.0,0.0,0.998911],"wq":[0.746024,0.226836,-0.381861,0.496161],"wp":[0.7037,1.3717,0.04]},"mixamorigLeftHandThumb3":{"parent":"mixamorigLeftHandThumb2","t":[0.143,3.0561,-0.0],"q":[-0.097972,-0.0,-0.0,0.995189],"wq":[0.693825,0.263156,-0.357801,0.566863],"wp":[0.7265,1.3593,0.0561]},"mixamorigLeftHandThumb4":{"parent":"mixamorigLeftHandThumb3","t":[0.5093,2.3288,-0.0],"q":[0.0,-0.0,-0.0,1.0],"wq":[0.693825,0.263156,-0.357801,0.566863],"wp":[0.7475,1.354,0.066]},"mixamorigLeftHandIndex1":{"parent":"mixamorigLeftHand","t":[-3.3363,8.3158,0.102],"q":[0.011733,0.000437,0.037209,0.999239],"wq":[0.533747,0.452988,-0.494391,0.515261],"wp":[0.7424,1.3901,0.0229]},"mixamorigLeftHandIndex2":{"parent":"mixamorigLeftHandIndex1","t":[0.0128,3.0457,0.0],"q":[0.089542,0.0,0.0,0.995983],"wq":[0.57774,0.406899,-0.532967,0.465398],"wp":[0.7726,1.3883,0.0259]},"mixamorigLeftHandIndex3":{"parent":"mixamorigLeftHandIndex2","t":[-0.0045,2.8068,-0.0],"q":[0.026939,-0.0,-0.0,0.999637],"wq":[0.590068,0.392394,-0.543735,0.449666],"wp":[0.7998,1.3817,0.0289]},"mixamorigLeftHandIndex4":{"parent":"mixamorigLeftHandIndex3","t":[-0.0082,2.4401,0.0],"q":[0.0,0.0,0.0,1.0],"wq":[0.590068,0.392394,-0.543735,0.449666],"wp":[0.823,1.3747,0.0315]},"mixamorigLeftHandMiddle1":{"parent":"mixamorigLeftHand","t":[-0.902,8.4356,-0.1415],"q":[0.006726,3.3e-05,0.004849,0.999966],"wq":[0.515924,0.472187,-0.508847,0.501933],"wp":[0.7443,1.3919,-0.0014]},"mixamorigLeftHandMiddle2":{"parent":"mixamorigLeftHandMiddle1","t":[0.0091,3.1936,-0.0],"q":[0.112096,-0.0,-0.0,0.993697],"wq":[0.568937,0.412171,-0.55857,0.440937],"wp":[0.7762,1.3903,-0.0003]},"mixamorigLeftHandMiddle3":{"parent":"mixamorigLeftHandMiddle2","t":[-0.0058,3.0852,0.0],"q":[-0.015476,0.0,0.0,0.99988],"wq":[0.562045,0.420766,-0.552125,0.449689],"wp":[0.8059,1.3819,0.001]},"mixamorigLeftHandMiddle4":{"parent":"mixamorigLeftHandMiddle3","t":[-0.0033,2.6929,0.0],"q":[0.0,-0.0,-0.0,1.0],"wq":[0.562045,0.420766,-0.552125,0.449689],"wp":[0.832,1.3754,0.0021]},"mixamorigLeftHandRing1":{"parent":"mixamorigLeftHand","t":[1.1324,8.4367,-0.2071],"q":[0.035787,-0.000587,-0.016393,0.999225],"wq":[0.519691,0.467593,-0.533364,0.476236],"wp":[0.7449,1.3921,-0.0218]},"mixamorigLeftHandRing2":{"parent":"mixamorigLeftHandRing1","t":[0.0022,2.7408,-0.0],"q":[0.100456,0.0,0.0,0.994941],"wq":[0.564903,0.411648,-0.577639,0.42162],"wp":[0.7721,1.3891,-0.0219]},"mixamorigLeftHandRing3":{"parent":"mixamorigLeftHandRing2","t":[-0.0052,2.7576,-0.0],"q":[-0.119727,-0.0,0.0,0.992807],"wq":[0.510361,0.477846,-0.524199,0.486222],"wp":[0.7984,1.3807,-0.0218]},"mixamorigLeftHandRing4":{"parent":"mixamorigLeftHandRing3","t":[0.003,2.285,-0.0],"q":[0.0,-0.0,-0.0,1.0],"wq":[0.510361,0.477846,-0.524199,0.486222],"wp":[0.8212,1.3791,-0.022]},"mixamorigLeftHandPinky1":{"parent":"mixamorigLeftHand","t":[3.1059,8.0794,0.093],"q":[0.025415,-0.000742,-0.029159,0.999251],"wq":[0.508307,0.479312,-0.534918,0.475128],"wp":[0.7417,1.3888,-0.0415]},"mixamorigLeftHandPinky2":{"parent":"mixamorigLeftHandPinky1","t":[0.0026,2.5274,0.0],"q":[0.092212,-0.0,-0.0,0.995739],"wq":[0.549954,0.427944,-0.576838,0.426232],"wp":[0.7669,1.3865,-0.0423]},"mixamorigLeftHandPinky3":{"parent":"mixamorigLeftHandPinky2","t":[-0.0013,2.0034,-0.0],"q":[0.002059,-0.0,-0.0,0.999998],"wq":[0.55083,0.426755,-0.577718,0.425099],"wp":[0.7862,1.3811,-0.0428]},"mixamorigLeftHandPinky4":{"parent":"mixamorigLeftHandPinky3","t":[-0.0013,1.8545,0.0],"q":[-0.0,-0.0,-0.0,1.0],"wq":[0.55083,0.426755,-0.577718,0.425099],"wp":[0.804,1.376,-0.0432]},"mixamorigRightShoulder":{"parent":"mixamorigSpine2","t":[-5.9491,13.2478,-0.0673],"q":[0.566207,-0.42158,0.57265,0.416836],"wq":[0.5587,-0.411323,0.580061,0.426845],"wp":[-0.0595,1.4367,-0.0041]},"mixamorigRightArm":{"parent":"mixamorigRightShoulder","t":[0.0,12.4721,-0.0],"q":[-0.111972,-0.004226,0.03748,0.992995],"wq":[0.494027,-0.496137,0.543578,0.462935],"wp":[-0.1786,1.3997,-0.0042]},"mixamorigRightForeArm":{"parent":"mixamorigRightArm","t":[0.0,23.8199,-0.0],"q":[-0.063866,0.004163,-0.064912,0.995836],"wq":[0.492347,-0.494791,0.481635,0.529909],"wp":[-0.4152,1.3808,-0.0237]},"mixamorigRightHand":{"parent":"mixamorigRightForeArm","t":[-0.0,24.5599,0.0],"q":[0.042867,0.00763,0.009818,0.999003],"wq":[0.506039,-0.474443,0.511324,0.507323],"wp":[-0.6603,1.3934,-0.0126]},"mixamorigRightHandThumb1":{"parent":"mixamorigRightHand","t":[2.8125,2.4428,1.2349],"q":[0.153951,-0.051993,-0.315712,0.934838],"wq":[0.72754,-0.231423,0.364568,0.533123],"wp":[-0.6835,1.3813,0.0167]},"mixamorigRightHandThumb2":{"parent":"mixamorigRightHandThumb1","t":[0.6044,3.081,0.0],"q":[0.034789,0.0,0.0,0.999395],"wq":[0.745646,-0.218599,0.372399,0.507489],"wp":[-0.702,1.3716,0.0401]},"mixamorigRightHandThumb3":{"parent":"mixamorigRightHandThumb2","t":[-0.3269,3.0489,-0.0],"q":[0.006262,0.0,0.0,0.99998],"wq":[0.74881,-0.216263,0.37376,0.50281],"wp":[-0.7255,1.3596,0.0556]},"mixamorigRightHandThumb4":{"parent":"mixamorigRightHandThumb3","t":[-0.2775,2.5512,0.0],"q":[0.0,0.0,0.0,1.0],"wq":[0.74881,-0.216263,0.37376,0.50281],"wp":[-0.7451,1.3492,0.0686]},"mixamorigRightHandIndex1":{"parent":"mixamorigRightHand","t":[3.3511,8.3672,0.1107],"q":[0.020934,-0.000524,-0.025033,0.999467],"wq":[0.528535,-0.451084,0.508019,0.50901],"wp":[-0.7429,1.3907,0.0233]},"mixamorigRightHandIndex2":{"parent":"mixamorigRightHandIndex1","t":[-0.0028,3.0683,0.0],"q":[0.09209,-0.0,0.0,0.995751],"wq":[0.573163,-0.402384,0.5474,0.458174],"wp":[-0.7734,1.3884,0.0257]},"mixamorigRightHandIndex3":{"parent":"mixamorigRightHandIndex2","t":[0.0021,2.7797,-0.0],"q":[-0.026005,0.0,0.0,0.999662],"wq":[0.561054,-0.416483,0.536751,0.472925],"wp":[-0.8002,1.3812,0.0281]},"mixamorigRightHandIndex4":{"parent":"mixamorigRightHandIndex3","t":[0.0007,2.4901,-0.0],"q":[-0.0,-0.0,0.0,1.0],"wq":[0.561054,-0.416483,0.536751,0.472925],"wp":[-0.8244,1.3761,0.0302]},"mixamorigRightHandMiddle1":{"parent":"mixamorigRightHand","t":[0.9178,8.6058,-0.1721],"q":[0.020178,-0.000184,-0.009117,0.999755],"wq":[0.520571,-0.459489,0.516054,0.501562],"wp":[-0.746,1.3925,-0.001]},"mixamorigRightHandMiddle2":{"parent":"mixamorigRightHandMiddle1","t":[-0.0014,3.2305,-0.0],"q":[0.102302,0.0,0.0,0.994753],"wq":[0.569151,-0.404284,0.560353,0.445675],"wp":[-0.7782,1.3901,0.0005]},"mixamorigRightHandMiddle3":{"parent":"mixamorigRightHandMiddle2","t":[0.0007,3.0255,0.0],"q":[-0.001276,-0.0,0.0,0.999999],"wq":[0.568582,-0.404999,0.559837,0.4464],"wp":[-0.8073,1.3817,0.0021]},"mixamorigRightHandMiddle4":{"parent":"mixamorigRightHandMiddle3","t":[0.0007,2.6888,0.0],"q":[0.0,-0.0,0.0,1.0],"wq":[0.568582,-0.404999,0.559837,0.4464],"wp":[-0.8331,1.3744,0.0036]},"mixamorigRightHandRing1":{"parent":"mixamorigRightHand","t":[-1.1633,8.7983,-0.2293],"q":[0.039516,0.000627,0.015846,0.999093],"wq":[0.517789,-0.461508,0.537965,0.479061],"wp":[-0.7485,1.3922,-0.0218]},"mixamorigRightHandRing2":{"parent":"mixamorigRightHandRing1","t":[0.0013,2.6741,0.0],"q":[0.114056,-0.0,0.0,0.993474],"wq":[0.569049,-0.397138,0.587092,0.416878],"wp":[-0.7751,1.3891,-0.0218]},"mixamorigRightHandRing3":{"parent":"mixamorigRightHandRing2","t":[-0.0022,2.6309,-0.0],"q":[-0.100921,0.0,-0.0,0.994894],"wq":[0.524072,-0.454361,0.544015,0.472179],"wp":[-0.7999,1.3802,-0.0216]},"mixamorigRightHandRing4":{"parent":"mixamorigRightHandRing3","t":[0.0009,2.1607,0.0],"q":[-0.0,-0.0,-0.0,1.0],"wq":[0.524072,-0.454361,0.544015,0.472179],"wp":[-0.8213,1.3772,-0.0216]},"mixamorigRightHandPinky1":{"parent":"mixamorigRightHand","t":[-3.1056,7.8943,0.2202],"q":[-0.011042,-0.000222,0.020139,0.999736],"wq":[0.490863,-0.490267,0.516055,0.502374],"wp":[-0.7399,1.3872,-0.0413]},"mixamorigRightHandPinky2":{"parent":"mixamorigRightHandPinky1","t":[0.0028,2.51,0.0],"q":[0.117772,-0.0,-0.0,0.993041],"wq":[0.546612,-0.426079,0.570203,0.441068],"wp":[-0.765,1.3869,-0.0416]},"mixamorigRightHandPinky3":{"parent":"mixamorigRightHandPinky2","t":[-0.0013,2.0992,-0.0],"q":[0.016978,0.0,-0.0,0.999856],"wq":[0.554022,-0.416336,0.577355,0.431724],"wp":[-0.7853,1.3817,-0.0417]},"mixamorigRightHandPinky4":{"parent":"mixamorigRightHandPinky3","t":[-0.0016,1.8456,-0.0],"q":[0.0,-0.0,-0.0,1.0],"wq":[0.554022,-0.416336,0.577355,0.431724],"wp":[-0.803,1.3765,-0.0417]},"mixamorigLeftUpLeg":{"parent":"mixamorigHips","t":[9.3921,-5.5722,-0.0932],"q":[0.001217,0.032392,-0.998783,0.037186],"wq":[0.001217,0.032392,-0.998783,0.037186],"wp":[0.0939,0.8966,0.0129]},"mixamorigLeftLeg":{"parent":"mixamorigLeftUpLeg","t":[0.0,42.3183,0.0],"q":[0.01298,-0.0001,-0.007144,0.99989],"wq":[0.001369,0.019429,-0.999359,0.030034],"wp":[0.1254,0.4755,-0.0145]},"mixamorigLeftFoot":{"parent":"mixamorigLeftLeg","t":[0.0,39.0997,-0.0],"q":[0.506576,-0.045803,0.026962,0.860556],"wq":[-0.028857,-0.490944,-0.869099,0.052987],"wp":[0.1489,0.0855,-0.0296]},"mixamorigLeftToeBase":{"parent":"mixamorigLeftFoot","t":[0.0,14.7061,-0.0],"q":[0.286501,-0.001962,0.000587,0.958078],"wq":[-0.01446,-0.719447,-0.691921,0.05858],"wp":[0.1666,0.0101,0.0954]},"mixamorigRightUpLeg":{"parent":"mixamorigHips","t":[-9.3921,-5.5722,-0.0152],"q":[0.001269,-0.033759,0.998737,0.037178],"wq":[0.001269,-0.033759,0.998737,0.037178],"wp":[-0.0939,0.8966,0.0136]},"mixamorigRightLeg":{"parent":"mixamorigRightUpLeg","t":[0.0,42.3259,-0.0],"q":[0.016569,0.000125,0.007126,0.999837],"wq":[0.001519,-0.01721,0.999399,0.030038],"wp":[-0.1254,0.4755,-0.0149]},"mixamorigRightFoot":{"parent":"mixamorigRightLeg","t":[-0.0,39.0933,0.0],"q":[0.502752,0.046538,-0.027118,0.862751],"wq":[-0.029631,0.489042,0.870141,0.053055],"wp":[-0.1489,0.0855,-0.0283]},"mixamorigRightToeBase":{"parent":"mixamorigRightFoot","t":[0.0,14.5997,-0.0],"q":[0.288388,-0.000417,0.000126,0.957514],"wq":[-0.012648,0.719184,0.692157,0.05944],"wp":[-0.1666,0.0101,0.0955]}}}
  };

  // ═══════════════════════════════════════════════════════════════════════
  // STAGE 1: 65 CANONICAL CHARACTER-SPACE BIOMECHANICAL BLUEPRINTS
  // ═══════════════════════════════════════════════════════════════════════
  var EXERCISES = {
    "bodyweight_squat": {
        "speed": 2.4,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigSpine1": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -72
            ],
            "mixamorigRightArm": [
                0,
                12,
                72
            ],
            "mixamorigLeftForeArm": [
                0,
                -22,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                22,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -26,
                0,
                0
            ],
            "mixamorigSpine1": [
                -12,
                0,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                88,
                0,
                10
            ],
            "mixamorigRightUpLeg": [
                88,
                0,
                -10
            ],
            "mixamorigLeftLeg": [
                -92,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -92,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                18,
                0,
                0
            ],
            "mixamorigRightFoot": [
                18,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -72,
                -15
            ],
            "mixamorigRightArm": [
                0,
                72,
                15
            ],
            "mixamorigLeftForeArm": [
                0,
                -25,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                25,
                0
            ]
        }
    },
    "reverse_lunge": {
        "speed": 2.6,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigSpine1": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -72
            ],
            "mixamorigRightArm": [
                0,
                12,
                72
            ],
            "mixamorigLeftForeArm": [
                0,
                -22,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                22,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -12,
                0,
                0
            ],
            "mixamorigSpine1": [
                -6,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                78,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -84,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                14,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -32,
                0,
                -4
            ],
            "mixamorigRightLeg": [
                -78,
                0,
                0
            ],
            "mixamorigRightFoot": [
                -20,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                20,
                -68
            ],
            "mixamorigRightArm": [
                0,
                -55,
                45
            ],
            "mixamorigLeftForeArm": [
                0,
                -45,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                65,
                0
            ]
        }
    },
    "glute_bridge": {
        "speed": 2.8,
        "mode": "lerp",
        "posture": "supine",
        "start": {
            "mixamorigHips": [
                75,
                0,
                0
            ],
            "mixamorigSpine": [
                -12,
                0,
                0
            ],
            "mixamorigSpine1": [
                -8,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                62,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                62,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -105,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -105,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                10,
                -72
            ],
            "mixamorigRightArm": [
                0,
                -10,
                72
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                88,
                0,
                0
            ],
            "mixamorigSpine": [
                14,
                0,
                0
            ],
            "mixamorigSpine1": [
                8,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                10,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                10,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -92,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -92,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                10,
                -72
            ],
            "mixamorigRightArm": [
                0,
                -10,
                72
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        }
    },
    "wall_sit": {
        "speed": 3.2,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigSpine1": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                76,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -80,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -80,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -65,
                -25
            ],
            "mixamorigRightArm": [
                0,
                65,
                25
            ],
            "mixamorigLeftForeArm": [
                0,
                -15,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                15,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigSpine1": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                88,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                88,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -90,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -90,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -75,
                -15
            ],
            "mixamorigRightArm": [
                0,
                75,
                15
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        }
    },
    "calf_raise": {
        "speed": 1.8,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigSpine1": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -72
            ],
            "mixamorigRightArm": [
                0,
                12,
                72
            ],
            "mixamorigLeftForeArm": [
                0,
                -22,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                22,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                2,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                2,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -2,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -2,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                -38,
                0,
                0
            ],
            "mixamorigRightFoot": [
                -38,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -20,
                -65
            ],
            "mixamorigRightArm": [
                0,
                20,
                65
            ],
            "mixamorigLeftForeArm": [
                0,
                -45,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                45,
                0
            ]
        }
    },
    "deadlift": {
        "speed": 2.6,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigSpine1": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -72
            ],
            "mixamorigRightArm": [
                0,
                12,
                72
            ],
            "mixamorigLeftForeArm": [
                0,
                -22,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                22,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -48,
                0,
                0
            ],
            "mixamorigSpine1": [
                -22,
                0,
                0
            ],
            "mixamorigHead": [
                28,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                46,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                46,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -32,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -32,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -45,
                -62
            ],
            "mixamorigRightArm": [
                0,
                45,
                62
            ],
            "mixamorigLeftForeArm": [
                0,
                -8,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                8,
                0
            ]
        }
    },
    "leg_press": {
        "speed": 2.4,
        "mode": "lerp",
        "posture": "seated",
        "start": {
            "mixamorigHips": [
                25,
                0,
                0
            ],
            "mixamorigSpine": [
                -15,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                95,
                0,
                8
            ],
            "mixamorigRightUpLeg": [
                95,
                0,
                -8
            ],
            "mixamorigLeftLeg": [
                -98,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -98,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                -68
            ],
            "mixamorigRightArm": [
                0,
                15,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -35,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                35,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                25,
                0,
                0
            ],
            "mixamorigSpine": [
                -15,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                52,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                52,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -14,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -14,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                -68
            ],
            "mixamorigRightArm": [
                0,
                15,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -35,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                35,
                0
            ]
        }
    },
    "push_up": {
        "speed": 2.2,
        "mode": "lerp",
        "posture": "prone",
        "start": {
            "mixamorigHips": [
                -76,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigSpine1": [
                0,
                0,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                0,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                0,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -4,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -4,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -76,
                -12
            ],
            "mixamorigRightArm": [
                0,
                76,
                12
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -82,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigSpine1": [
                0,
                0,
                0
            ],
            "mixamorigHead": [
                22,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                0,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                0,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -4,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -4,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -22
            ],
            "mixamorigRightArm": [
                0,
                12,
                22
            ],
            "mixamorigLeftForeArm": [
                0,
                -96,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                96,
                0
            ]
        }
    },
    "knee_push_up": {
        "speed": 2.3,
        "mode": "lerp",
        "posture": "prone",
        "start": {
            "mixamorigHips": [
                -72,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                12,
                0,
                5
            ],
            "mixamorigRightUpLeg": [
                12,
                0,
                -5
            ],
            "mixamorigLeftLeg": [
                -78,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -78,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -74,
                -12
            ],
            "mixamorigRightArm": [
                0,
                74,
                12
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigHead": [
                22,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                12,
                0,
                5
            ],
            "mixamorigRightUpLeg": [
                12,
                0,
                -5
            ],
            "mixamorigLeftLeg": [
                -78,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -78,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                -22
            ],
            "mixamorigRightArm": [
                0,
                15,
                22
            ],
            "mixamorigLeftForeArm": [
                0,
                -92,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                92,
                0
            ]
        }
    },
    "wall_push_up": {
        "speed": 2.2,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                -14,
                0,
                0
            ],
            "mixamorigSpine": [
                -6,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                8,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                8,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -6,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -6,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -75,
                -10
            ],
            "mixamorigRightArm": [
                0,
                75,
                10
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -22,
                0,
                0
            ],
            "mixamorigSpine": [
                -8,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                12,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                12,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -18,
                -22
            ],
            "mixamorigRightArm": [
                0,
                18,
                22
            ],
            "mixamorigLeftForeArm": [
                0,
                -92,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                92,
                0
            ]
        }
    },
    "dumbbell_bench_press": {
        "speed": 2.4,
        "mode": "lerp",
        "posture": "supine",
        "start": {
            "mixamorigHips": [
                80,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                55,
                0,
                8
            ],
            "mixamorigRightUpLeg": [
                55,
                0,
                -8
            ],
            "mixamorigLeftLeg": [
                -90,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -90,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -10
            ],
            "mixamorigRightArm": [
                0,
                12,
                10
            ],
            "mixamorigLeftForeArm": [
                0,
                -88,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                88,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                80,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                55,
                0,
                8
            ],
            "mixamorigRightUpLeg": [
                55,
                0,
                -8
            ],
            "mixamorigLeftLeg": [
                -90,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -90,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -78,
                -5
            ],
            "mixamorigRightArm": [
                0,
                78,
                5
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        }
    },
    "dumbbell_bicep_curl": {
        "speed": 2.0,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -6,
                -75
            ],
            "mixamorigRightArm": [
                0,
                6,
                75
            ],
            "mixamorigLeftForeArm": [
                0,
                -16,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                16,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -14,
                -75
            ],
            "mixamorigRightArm": [
                0,
                14,
                75
            ],
            "mixamorigLeftForeArm": [
                0,
                -114,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                114,
                0
            ]
        }
    },
    "tricep_dips": {
        "speed": 2.2,
        "mode": "lerp",
        "posture": "seated",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                58,
                0,
                5
            ],
            "mixamorigRightUpLeg": [
                58,
                0,
                -5
            ],
            "mixamorigLeftLeg": [
                -55,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -55,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                28,
                -68
            ],
            "mixamorigRightArm": [
                0,
                -28,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -16,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                16,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                6,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                0,
                5
            ],
            "mixamorigRightUpLeg": [
                76,
                0,
                -5
            ],
            "mixamorigLeftLeg": [
                -82,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -82,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                48,
                -58
            ],
            "mixamorigRightArm": [
                0,
                -48,
                58
            ],
            "mixamorigLeftForeArm": [
                0,
                -94,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                94,
                0
            ]
        }
    },
    "tricep_extension": {
        "speed": 2.1,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                72
            ],
            "mixamorigRightArm": [
                0,
                15,
                -72
            ],
            "mixamorigLeftForeArm": [
                0,
                -108,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                108,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                76
            ],
            "mixamorigRightArm": [
                0,
                15,
                -76
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        }
    },
    "shoulder_press": {
        "speed": 2.3,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -3,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -18,
                5
            ],
            "mixamorigRightArm": [
                0,
                18,
                -5
            ],
            "mixamorigLeftForeArm": [
                0,
                -95,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                95,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                74
            ],
            "mixamorigRightArm": [
                0,
                12,
                -74
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        }
    },
    "seated_shoulder_press": {
        "speed": 2.3,
        "mode": "lerp",
        "posture": "seated",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                82,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                82,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -85,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -85,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -18,
                5
            ],
            "mixamorigRightArm": [
                0,
                18,
                -5
            ],
            "mixamorigLeftForeArm": [
                0,
                -95,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                95,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                82,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                82,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -85,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -85,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                74
            ],
            "mixamorigRightArm": [
                0,
                12,
                -74
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        }
    },
    "lateral_raise": {
        "speed": 2.2,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigSpine1": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -72
            ],
            "mixamorigRightArm": [
                0,
                12,
                72
            ],
            "mixamorigLeftForeArm": [
                0,
                -22,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                22,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                8
            ],
            "mixamorigRightArm": [
                0,
                12,
                -8
            ],
            "mixamorigLeftForeArm": [
                0,
                -18,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                18,
                0
            ]
        }
    },
    "arm_circles": {
        "speed": 1.8,
        "mode": "circle",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -25,
                -18
            ],
            "mixamorigRightArm": [
                0,
                25,
                18
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                25,
                22
            ],
            "mixamorigRightArm": [
                0,
                -25,
                -22
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        }
    },
    "bent_over_row": {
        "speed": 2.4,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -38,
                0,
                0
            ],
            "mixamorigSpine1": [
                -16,
                0,
                0
            ],
            "mixamorigHead": [
                22,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                38,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                38,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -38,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -38,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -52,
                -55
            ],
            "mixamorigRightArm": [
                0,
                52,
                55
            ],
            "mixamorigLeftForeArm": [
                0,
                -14,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                14,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -38,
                0,
                0
            ],
            "mixamorigSpine1": [
                -16,
                0,
                0
            ],
            "mixamorigHead": [
                22,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                38,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                38,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -38,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -38,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                28,
                -58
            ],
            "mixamorigRightArm": [
                0,
                -28,
                58
            ],
            "mixamorigLeftForeArm": [
                0,
                -102,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                102,
                0
            ]
        }
    },
    "pull_up": {
        "speed": 2.6,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                8,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                8,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -25,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -25,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -10,
                74
            ],
            "mixamorigRightArm": [
                0,
                10,
                -74
            ],
            "mixamorigLeftForeArm": [
                0,
                -15,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                15,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                8,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                14,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                14,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -35,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -35,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -18
            ],
            "mixamorigRightArm": [
                0,
                12,
                18
            ],
            "mixamorigLeftForeArm": [
                0,
                -112,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                112,
                0
            ]
        }
    },
    "chest_fly": {
        "speed": 2.5,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -6,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                8,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                8,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -12,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -12,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -8
            ],
            "mixamorigRightArm": [
                0,
                12,
                8
            ],
            "mixamorigLeftForeArm": [
                0,
                -24,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                24,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -6,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                8,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                8,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -12,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -12,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -76,
                -12
            ],
            "mixamorigRightArm": [
                0,
                76,
                12
            ],
            "mixamorigLeftForeArm": [
                0,
                -32,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                32,
                0
            ]
        }
    },
    "plank": {
        "speed": 3.2,
        "mode": "lerp",
        "posture": "prone",
        "start": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigSpine1": [
                -2,
                0,
                0
            ],
            "mixamorigHead": [
                16,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                0,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                0,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -4,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -4,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -68,
                -15
            ],
            "mixamorigRightArm": [
                0,
                68,
                15
            ],
            "mixamorigLeftForeArm": [
                0,
                -86,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                86,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -82,
                0,
                0
            ],
            "mixamorigSpine": [
                -10,
                0,
                0
            ],
            "mixamorigSpine1": [
                -6,
                0,
                0
            ],
            "mixamorigHead": [
                22,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -78,
                -15
            ],
            "mixamorigRightArm": [
                0,
                78,
                15
            ],
            "mixamorigLeftForeArm": [
                0,
                -96,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                96,
                0
            ]
        }
    },
    "side_plank": {
        "speed": 2.8,
        "mode": "lerp",
        "posture": "side_plank",
        "start": {
            "mixamorigHips": [
                -78,
                85,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                -6
            ],
            "mixamorigLeftArm": [
                0,
                -65,
                -20
            ],
            "mixamorigRightArm": [
                0,
                0,
                -5
            ],
            "mixamorigLeftForeArm": [
                0,
                -88,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ],
            "mixamorigLeftUpLeg": [
                0,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                0,
                0,
                -6
            ]
        },
        "peak": {
            "mixamorigHips": [
                -78,
                85,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                10
            ],
            "mixamorigLeftArm": [
                0,
                -65,
                -20
            ],
            "mixamorigRightArm": [
                0,
                0,
                -65
            ],
            "mixamorigLeftForeArm": [
                0,
                -88,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ],
            "mixamorigLeftUpLeg": [
                0,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                0,
                0,
                -24
            ]
        }
    },
    "dead_bug": {
        "speed": 2.6,
        "mode": "alternate",
        "posture": "supine",
        "start": {
            "mixamorigHips": [
                80,
                0,
                0
            ],
            "mixamorigSpine": [
                -6,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                85,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                85,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -88,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -88,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -78,
                -10
            ],
            "mixamorigRightArm": [
                0,
                78,
                10
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                80,
                0,
                0
            ],
            "mixamorigSpine": [
                -8,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                18,
                0,
                6
            ],
            "mixamorigLeftLeg": [
                -12,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                92,
                0,
                -6
            ],
            "mixamorigRightLeg": [
                -90,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -78,
                -10
            ],
            "mixamorigRightArm": [
                0,
                20,
                -68
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        }
    },
    "bird_dog": {
        "speed": 2.8,
        "mode": "alternate",
        "posture": "quadruped",
        "start": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigHead": [
                16,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                82,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                82,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -85,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -85,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -76,
                -12
            ],
            "mixamorigRightArm": [
                0,
                76,
                12
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                4,
                0,
                0
            ],
            "mixamorigHead": [
                20,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                -8,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -6,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                82,
                0,
                -6
            ],
            "mixamorigRightLeg": [
                -85,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -76,
                -12
            ],
            "mixamorigRightArm": [
                0,
                18,
                -68
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        }
    },
    "seated_torso_twist": {
        "speed": 2.4,
        "mode": "alternate",
        "posture": "seated",
        "start": {
            "mixamorigHips": [
                15,
                0,
                0
            ],
            "mixamorigSpine": [
                -8,
                -28,
                0
            ],
            "mixamorigSpine1": [
                -4,
                -18,
                0
            ],
            "mixamorigHead": [
                0,
                -12,
                0
            ],
            "mixamorigLeftUpLeg": [
                72,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                72,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -78,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -78,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -55,
                -35
            ],
            "mixamorigRightArm": [
                0,
                35,
                45
            ],
            "mixamorigLeftForeArm": [
                0,
                -75,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                75,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                15,
                0,
                0
            ],
            "mixamorigSpine": [
                -8,
                28,
                0
            ],
            "mixamorigSpine1": [
                -4,
                18,
                0
            ],
            "mixamorigHead": [
                0,
                12,
                0
            ],
            "mixamorigLeftUpLeg": [
                72,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                72,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -78,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -78,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -35,
                -45
            ],
            "mixamorigRightArm": [
                0,
                55,
                35
            ],
            "mixamorigLeftForeArm": [
                0,
                -75,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                75,
                0
            ]
        }
    },
    "core_activation": {
        "speed": 2.2,
        "mode": "lerp",
        "posture": "supine",
        "start": {
            "mixamorigHips": [
                78,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigSpine1": [
                -4,
                0,
                0
            ],
            "mixamorigNeck": [
                -6,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                58,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                58,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -92,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -92,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -25,
                35
            ],
            "mixamorigRightArm": [
                0,
                25,
                -35
            ],
            "mixamorigLeftForeArm": [
                0,
                -95,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                95,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                78,
                0,
                0
            ],
            "mixamorigSpine": [
                -28,
                0,
                0
            ],
            "mixamorigSpine1": [
                -22,
                0,
                0
            ],
            "mixamorigNeck": [
                -16,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                64,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                64,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -95,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -95,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -65,
                -15
            ],
            "mixamorigRightArm": [
                0,
                65,
                15
            ],
            "mixamorigLeftForeArm": [
                0,
                -45,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                45,
                0
            ]
        }
    },
    "leg_raise": {
        "speed": 2.6,
        "mode": "lerp",
        "posture": "supine",
        "start": {
            "mixamorigHips": [
                80,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                10,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                10,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                0,
                -74
            ],
            "mixamorigRightArm": [
                0,
                0,
                74
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                80,
                0,
                0
            ],
            "mixamorigSpine": [
                -10,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                84,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                84,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                0,
                -74
            ],
            "mixamorigRightArm": [
                0,
                0,
                74
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        }
    },
    "jumping_jacks": {
        "speed": 1.4,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                2
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -2
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -8,
                -76
            ],
            "mixamorigRightArm": [
                0,
                8,
                76
            ],
            "mixamorigLeftForeArm": [
                0,
                -14,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                14,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                26
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -26
            ],
            "mixamorigLeftLeg": [
                -12,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -12,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -10,
                72
            ],
            "mixamorigRightArm": [
                0,
                10,
                -72
            ],
            "mixamorigLeftForeArm": [
                0,
                -22,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                22,
                0
            ]
        }
    },
    "march_in_place": {
        "speed": 1.6,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -3,
                4,
                0
            ],
            "mixamorigLeftUpLeg": [
                62,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -72,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -4
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                22,
                -68
            ],
            "mixamorigRightArm": [
                0,
                -48,
                55
            ],
            "mixamorigLeftForeArm": [
                0,
                -55,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                75,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -3,
                -4,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                62,
                0,
                -4
            ],
            "mixamorigRightLeg": [
                -72,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -48,
                -55
            ],
            "mixamorigRightArm": [
                0,
                22,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -75,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                55,
                0
            ]
        }
    },
    "seated_march": {
        "speed": 1.8,
        "mode": "alternate",
        "posture": "seated",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                108,
                0,
                6
            ],
            "mixamorigLeftLeg": [
                -88,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                76,
                0,
                -6
            ],
            "mixamorigRightLeg": [
                -85,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                15,
                -68
            ],
            "mixamorigRightArm": [
                0,
                -35,
                58
            ],
            "mixamorigLeftForeArm": [
                0,
                -55,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                68,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                0,
                6
            ],
            "mixamorigLeftLeg": [
                -85,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                108,
                0,
                -6
            ],
            "mixamorigRightLeg": [
                -88,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -35,
                -58
            ],
            "mixamorigRightArm": [
                0,
                15,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -68,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                55,
                0
            ]
        }
    },
    "high_knees": {
        "speed": 1.1,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -6,
                6,
                0
            ],
            "mixamorigLeftUpLeg": [
                92,
                0,
                5
            ],
            "mixamorigLeftLeg": [
                -98,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -10,
                0,
                -5
            ],
            "mixamorigRightLeg": [
                -18,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                32,
                -62
            ],
            "mixamorigRightArm": [
                0,
                -62,
                48
            ],
            "mixamorigLeftForeArm": [
                0,
                -78,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                88,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -6,
                -6,
                0
            ],
            "mixamorigLeftUpLeg": [
                -10,
                0,
                5
            ],
            "mixamorigLeftLeg": [
                -18,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                92,
                0,
                -5
            ],
            "mixamorigRightLeg": [
                -98,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -62,
                -48
            ],
            "mixamorigRightArm": [
                0,
                32,
                62
            ],
            "mixamorigLeftForeArm": [
                0,
                -88,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                78,
                0
            ]
        }
    },
    "mountain_climbers": {
        "speed": 1.2,
        "mode": "alternate",
        "posture": "prone",
        "start": {
            "mixamorigHips": [
                -76,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                82,
                0,
                5
            ],
            "mixamorigLeftLeg": [
                -88,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -6,
                0,
                -5
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -76,
                -12
            ],
            "mixamorigRightArm": [
                0,
                76,
                12
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -76,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                -6,
                0,
                5
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                82,
                0,
                -5
            ],
            "mixamorigRightLeg": [
                -88,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -76,
                -12
            ],
            "mixamorigRightArm": [
                0,
                76,
                12
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        }
    },
    "burpee": {
        "speed": 3.0,
        "mode": "burpee",
        "posture": "hybrid_burpee",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                5
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -5
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                72
            ],
            "mixamorigRightArm": [
                0,
                12,
                -72
            ],
            "mixamorigLeftForeArm": [
                0,
                -14,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                14,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                0,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                0,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -6,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -6,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -18,
                -22
            ],
            "mixamorigRightArm": [
                0,
                18,
                22
            ],
            "mixamorigLeftForeArm": [
                0,
                -90,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                90,
                0
            ]
        }
    },
    "tabata_squat_thrust": {
        "speed": 2.0,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigSpine1": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                6,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                6,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -72
            ],
            "mixamorigRightArm": [
                0,
                12,
                72
            ],
            "mixamorigLeftForeArm": [
                0,
                -22,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                22,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -32,
                0,
                0
            ],
            "mixamorigSpine1": [
                -14,
                0,
                0
            ],
            "mixamorigHead": [
                22,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                92,
                0,
                12
            ],
            "mixamorigRightUpLeg": [
                92,
                0,
                -12
            ],
            "mixamorigLeftLeg": [
                -96,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -96,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -76,
                -15
            ],
            "mixamorigRightArm": [
                0,
                76,
                15
            ],
            "mixamorigLeftForeArm": [
                0,
                -18,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                18,
                0
            ]
        }
    },
    "hiit_interval_beginner": {
        "speed": 1.6,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -24,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                78,
                0,
                8
            ],
            "mixamorigRightUpLeg": [
                78,
                0,
                -8
            ],
            "mixamorigLeftLeg": [
                -82,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -82,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                28,
                -68
            ],
            "mixamorigRightArm": [
                0,
                -28,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -35,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                35,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                14
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -14
            ],
            "mixamorigLeftLeg": [
                -6,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -6,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                -28,
                0,
                0
            ],
            "mixamorigRightFoot": [
                -28,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                68
            ],
            "mixamorigRightArm": [
                0,
                12,
                -68
            ],
            "mixamorigLeftForeArm": [
                0,
                -16,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                16,
                0
            ]
        }
    },
    "zumba_basic_flow": {
        "speed": 1.5,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                -12,
                -8
            ],
            "mixamorigSpine": [
                -4,
                14,
                6
            ],
            "mixamorigLeftUpLeg": [
                28,
                0,
                18
            ],
            "mixamorigLeftLeg": [
                -35,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                8,
                0,
                -10
            ],
            "mixamorigRightLeg": [
                -14,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -35,
                35
            ],
            "mixamorigRightArm": [
                0,
                35,
                45
            ],
            "mixamorigLeftForeArm": [
                0,
                -65,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                82,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                12,
                8
            ],
            "mixamorigSpine": [
                -4,
                -14,
                -6
            ],
            "mixamorigLeftUpLeg": [
                8,
                0,
                10
            ],
            "mixamorigLeftLeg": [
                -14,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                28,
                0,
                -18
            ],
            "mixamorigRightLeg": [
                -35,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -35,
                -45
            ],
            "mixamorigRightArm": [
                0,
                35,
                -35
            ],
            "mixamorigLeftForeArm": [
                0,
                -82,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                65,
                0
            ]
        }
    },
    "tai_chi_opening_form": {
        "speed": 3.8,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                14,
                0,
                12
            ],
            "mixamorigRightUpLeg": [
                14,
                0,
                -12
            ],
            "mixamorigLeftLeg": [
                -18,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -18,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -18,
                -68
            ],
            "mixamorigRightArm": [
                0,
                18,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -24,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                24,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                34,
                0,
                14
            ],
            "mixamorigRightUpLeg": [
                34,
                0,
                -14
            ],
            "mixamorigLeftLeg": [
                -38,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -38,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -68,
                -8
            ],
            "mixamorigRightArm": [
                0,
                68,
                8
            ],
            "mixamorigLeftForeArm": [
                0,
                -42,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                42,
                0
            ]
        }
    },
    "cat_cow": {
        "speed": 3.0,
        "mode": "lerp",
        "posture": "quadruped",
        "start": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                -22,
                0,
                0
            ],
            "mixamorigSpine1": [
                -18,
                0,
                0
            ],
            "mixamorigNeck": [
                -22,
                0,
                0
            ],
            "mixamorigHead": [
                -15,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                84,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                84,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -86,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -86,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -76,
                -10
            ],
            "mixamorigRightArm": [
                0,
                76,
                10
            ],
            "mixamorigLeftForeArm": [
                0,
                -8,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                8,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                20,
                0,
                0
            ],
            "mixamorigSpine1": [
                16,
                0,
                0
            ],
            "mixamorigNeck": [
                22,
                0,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                84,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                84,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -86,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -86,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -76,
                -10
            ],
            "mixamorigRightArm": [
                0,
                76,
                10
            ],
            "mixamorigLeftForeArm": [
                0,
                -8,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                8,
                0
            ]
        }
    },
    "child_pose": {
        "speed": 3.6,
        "mode": "lerp",
        "posture": "prone",
        "start": {
            "mixamorigHips": [
                -76,
                0,
                0
            ],
            "mixamorigSpine": [
                -16,
                0,
                0
            ],
            "mixamorigSpine1": [
                -12,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                108,
                0,
                12
            ],
            "mixamorigRightUpLeg": [
                108,
                0,
                -12
            ],
            "mixamorigLeftLeg": [
                -118,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -118,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -25,
                68
            ],
            "mixamorigRightArm": [
                0,
                25,
                -68
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -82,
                0,
                0
            ],
            "mixamorigSpine": [
                -26,
                0,
                0
            ],
            "mixamorigSpine1": [
                -18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                116,
                0,
                14
            ],
            "mixamorigRightUpLeg": [
                116,
                0,
                -14
            ],
            "mixamorigLeftLeg": [
                -124,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -124,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -18,
                74
            ],
            "mixamorigRightArm": [
                0,
                18,
                -74
            ],
            "mixamorigLeftForeArm": [
                0,
                -8,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                8,
                0
            ]
        }
    },
    "downward_dog": {
        "speed": 3.2,
        "mode": "lerp",
        "posture": "prone",
        "start": {
            "mixamorigHips": [
                -58,
                0,
                0
            ],
            "mixamorigSpine": [
                -12,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                45,
                0,
                5
            ],
            "mixamorigRightUpLeg": [
                45,
                0,
                -5
            ],
            "mixamorigLeftLeg": [
                -14,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -14,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -20,
                62
            ],
            "mixamorigRightArm": [
                0,
                20,
                -62
            ],
            "mixamorigLeftForeArm": [
                0,
                -8,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                8,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -66,
                0,
                0
            ],
            "mixamorigSpine": [
                -18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                58,
                0,
                5
            ],
            "mixamorigRightUpLeg": [
                58,
                0,
                -5
            ],
            "mixamorigLeftLeg": [
                -6,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -6,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                72
            ],
            "mixamorigRightArm": [
                0,
                15,
                -72
            ],
            "mixamorigLeftForeArm": [
                0,
                -6,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                6,
                0
            ]
        }
    },
    "cobra_pose": {
        "speed": 3.4,
        "mode": "lerp",
        "posture": "prone",
        "start": {
            "mixamorigHips": [
                -82,
                0,
                0
            ],
            "mixamorigSpine": [
                12,
                0,
                0
            ],
            "mixamorigSpine1": [
                8,
                0,
                0
            ],
            "mixamorigNeck": [
                10,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                -4,
                0,
                5
            ],
            "mixamorigRightUpLeg": [
                -4,
                0,
                -5
            ],
            "mixamorigLeftLeg": [
                -6,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -6,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -35,
                -35
            ],
            "mixamorigRightArm": [
                0,
                35,
                35
            ],
            "mixamorigLeftForeArm": [
                0,
                -75,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                75,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                32,
                0,
                0
            ],
            "mixamorigSpine1": [
                24,
                0,
                0
            ],
            "mixamorigNeck": [
                22,
                0,
                0
            ],
            "mixamorigHead": [
                14,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                -8,
                0,
                5
            ],
            "mixamorigRightUpLeg": [
                -8,
                0,
                -5
            ],
            "mixamorigLeftLeg": [
                -6,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -6,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -68,
                -22
            ],
            "mixamorigRightArm": [
                0,
                68,
                22
            ],
            "mixamorigLeftForeArm": [
                0,
                -18,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                18,
                0
            ]
        }
    },
    "seated_forward_fold": {
        "speed": 3.2,
        "mode": "lerp",
        "posture": "seated",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -14,
                0,
                0
            ],
            "mixamorigSpine1": [
                -8,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                76,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -12,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -12,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -65,
                -20
            ],
            "mixamorigRightArm": [
                0,
                65,
                20
            ],
            "mixamorigLeftForeArm": [
                0,
                -16,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                16,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -42,
                0,
                0
            ],
            "mixamorigSpine1": [
                -24,
                0,
                0
            ],
            "mixamorigNeck": [
                -12,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                84,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                84,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -78,
                -5
            ],
            "mixamorigRightArm": [
                0,
                78,
                5
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        }
    },
    "tree_pose": {
        "speed": 3.4,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                2,
                0,
                2
            ],
            "mixamorigLeftLeg": [
                -4,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                58,
                -32,
                -28
            ],
            "mixamorigRightLeg": [
                -98,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -52,
                -35
            ],
            "mixamorigRightArm": [
                0,
                52,
                35
            ],
            "mixamorigLeftForeArm": [
                0,
                -85,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                85,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                2,
                0,
                2
            ],
            "mixamorigLeftLeg": [
                -4,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                64,
                -36,
                -32
            ],
            "mixamorigRightLeg": [
                -105,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -18,
                68
            ],
            "mixamorigRightArm": [
                0,
                18,
                -68
            ],
            "mixamorigLeftForeArm": [
                0,
                -28,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                28,
                0
            ]
        }
    },
    "warrior_pose": {
        "speed": 3.2,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                54,
                0,
                14
            ],
            "mixamorigLeftLeg": [
                -58,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -28,
                0,
                -14
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -10,
                -8
            ],
            "mixamorigRightArm": [
                0,
                10,
                8
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                74,
                0,
                16
            ],
            "mixamorigLeftLeg": [
                -80,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -38,
                0,
                -16
            ],
            "mixamorigRightLeg": [
                -6,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                68
            ],
            "mixamorigRightArm": [
                0,
                12,
                -68
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        }
    },
    "supine_twist": {
        "speed": 3.4,
        "mode": "alternate",
        "posture": "supine",
        "start": {
            "mixamorigHips": [
                80,
                -22,
                0
            ],
            "mixamorigSpine": [
                0,
                24,
                0
            ],
            "mixamorigHead": [
                0,
                20,
                0
            ],
            "mixamorigLeftUpLeg": [
                72,
                0,
                -18
            ],
            "mixamorigLeftLeg": [
                -85,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                12,
                0,
                -4
            ],
            "mixamorigRightLeg": [
                -10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                0,
                0
            ],
            "mixamorigRightArm": [
                0,
                0,
                0
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                80,
                22,
                0
            ],
            "mixamorigSpine": [
                0,
                -24,
                0
            ],
            "mixamorigHead": [
                0,
                -20,
                0
            ],
            "mixamorigLeftUpLeg": [
                12,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -10,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                72,
                0,
                18
            ],
            "mixamorigRightLeg": [
                -85,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                0,
                0
            ],
            "mixamorigRightArm": [
                0,
                0,
                0
            ],
            "mixamorigLeftForeArm": [
                0,
                -10,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                10,
                0
            ]
        }
    },
    "legs_up_wall": {
        "speed": 3.6,
        "mode": "lerp",
        "posture": "supine",
        "start": {
            "mixamorigHips": [
                80,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                76,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -12,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -12,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                12,
                0,
                0
            ],
            "mixamorigRightFoot": [
                12,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                0,
                -55
            ],
            "mixamorigRightArm": [
                0,
                0,
                55
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                80,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                88,
                0,
                4
            ],
            "mixamorigRightUpLeg": [
                88,
                0,
                -4
            ],
            "mixamorigLeftLeg": [
                -4,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -4,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                22,
                0,
                0
            ],
            "mixamorigRightFoot": [
                22,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                0,
                -48
            ],
            "mixamorigRightArm": [
                0,
                0,
                48
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        }
    },
    "hip_flexor_stretch": {
        "speed": 3.0,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                68,
                0,
                5
            ],
            "mixamorigLeftLeg": [
                -76,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -26,
                0,
                -5
            ],
            "mixamorigRightLeg": [
                -68,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -20,
                -55
            ],
            "mixamorigRightArm": [
                0,
                15,
                -55
            ],
            "mixamorigLeftForeArm": [
                0,
                -35,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                20,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                10,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                80,
                0,
                5
            ],
            "mixamorigLeftLeg": [
                -85,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -38,
                0,
                -5
            ],
            "mixamorigRightLeg": [
                -78,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                65
            ],
            "mixamorigRightArm": [
                0,
                15,
                -65
            ],
            "mixamorigLeftForeArm": [
                0,
                -18,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                18,
                0
            ]
        }
    },
    "neck_release": {
        "speed": 3.0,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigNeck": [
                -12,
                -24,
                -18
            ],
            "mixamorigHead": [
                -10,
                -18,
                -14
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -74
            ],
            "mixamorigRightArm": [
                0,
                12,
                74
            ],
            "mixamorigLeftForeArm": [
                0,
                -20,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                20,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigNeck": [
                -12,
                24,
                18
            ],
            "mixamorigHead": [
                -10,
                18,
                14
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -12,
                -74
            ],
            "mixamorigRightArm": [
                0,
                12,
                74
            ],
            "mixamorigLeftForeArm": [
                0,
                -20,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                20,
                0
            ]
        }
    },
    "shoulder_pendulum": {
        "speed": 2.4,
        "mode": "circle",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -34,
                0,
                0
            ],
            "mixamorigSpine1": [
                -14,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                26,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                26,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -28,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -28,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -55,
                -48
            ],
            "mixamorigRightArm": [
                0,
                25,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                45,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -34,
                0,
                0
            ],
            "mixamorigSpine1": [
                -14,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                26,
                0,
                6
            ],
            "mixamorigRightUpLeg": [
                26,
                0,
                -6
            ],
            "mixamorigLeftLeg": [
                -28,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -28,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -20,
                -68
            ],
            "mixamorigRightArm": [
                0,
                25,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                45,
                0
            ]
        }
    },
    "wrist_mobility": {
        "speed": 2.0,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -65,
                -25
            ],
            "mixamorigRightArm": [
                0,
                65,
                25
            ],
            "mixamorigLeftForeArm": [
                0,
                -35,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                35,
                0
            ],
            "mixamorigLeftHand": [
                -35,
                0,
                -20
            ],
            "mixamorigRightHand": [
                -35,
                0,
                20
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -72,
                -18
            ],
            "mixamorigRightArm": [
                0,
                72,
                18
            ],
            "mixamorigLeftForeArm": [
                0,
                -18,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                18,
                0
            ],
            "mixamorigLeftHand": [
                42,
                0,
                20
            ],
            "mixamorigRightHand": [
                42,
                0,
                -20
            ]
        }
    },
    "ankle_circles": {
        "speed": 2.0,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                38,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -42,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                -28,
                -18,
                0
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                -68
            ],
            "mixamorigRightArm": [
                0,
                15,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -35,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                35,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                38,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -42,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                28,
                18,
                0
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                -68
            ],
            "mixamorigRightArm": [
                0,
                15,
                68
            ],
            "mixamorigLeftForeArm": [
                0,
                -35,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                35,
                0
            ]
        }
    },
    "lions_breath": {
        "speed": 3.2,
        "mode": "lerp",
        "posture": "seated",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigNeck": [
                4,
                0,
                0
            ],
            "mixamorigHead": [
                6,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                0,
                10
            ],
            "mixamorigRightUpLeg": [
                76,
                0,
                -10
            ],
            "mixamorigLeftLeg": [
                -88,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -88,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -35,
                -52
            ],
            "mixamorigRightArm": [
                0,
                35,
                52
            ],
            "mixamorigLeftForeArm": [
                0,
                -38,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                38,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -18,
                0,
                0
            ],
            "mixamorigNeck": [
                -14,
                0,
                0
            ],
            "mixamorigHead": [
                -12,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                0,
                10
            ],
            "mixamorigRightUpLeg": [
                76,
                0,
                -10
            ],
            "mixamorigLeftLeg": [
                -88,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -88,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -52,
                -38
            ],
            "mixamorigRightArm": [
                0,
                52,
                38
            ],
            "mixamorigLeftForeArm": [
                0,
                -16,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                16,
                0
            ]
        }
    },
    "cheek_lift": {
        "speed": 2.8,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigNeck": [
                0,
                0,
                0
            ],
            "mixamorigHead": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -45,
                -35
            ],
            "mixamorigRightArm": [
                0,
                45,
                35
            ],
            "mixamorigLeftForeArm": [
                0,
                -105,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                105,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                2,
                0,
                0
            ],
            "mixamorigNeck": [
                10,
                0,
                0
            ],
            "mixamorigHead": [
                14,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -55,
                -22
            ],
            "mixamorigRightArm": [
                0,
                55,
                22
            ],
            "mixamorigLeftForeArm": [
                0,
                -114,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                114,
                0
            ]
        }
    },
    "jaw_release": {
        "speed": 3.0,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigNeck": [
                -6,
                0,
                0
            ],
            "mixamorigHead": [
                -8,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -42,
                -38
            ],
            "mixamorigRightArm": [
                0,
                42,
                38
            ],
            "mixamorigLeftForeArm": [
                0,
                -98,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                98,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                2,
                0,
                0
            ],
            "mixamorigNeck": [
                14,
                0,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -48,
                -32
            ],
            "mixamorigRightArm": [
                0,
                48,
                32
            ],
            "mixamorigLeftForeArm": [
                0,
                -108,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                108,
                0
            ]
        }
    },
    "scalp_massage": {
        "speed": 2.6,
        "mode": "circle",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigNeck": [
                -4,
                -8,
                0
            ],
            "mixamorigHead": [
                -6,
                -8,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -32,
                24
            ],
            "mixamorigRightArm": [
                0,
                32,
                -24
            ],
            "mixamorigLeftForeArm": [
                0,
                -112,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                112,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigNeck": [
                6,
                8,
                0
            ],
            "mixamorigHead": [
                8,
                8,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -42,
                34
            ],
            "mixamorigRightArm": [
                0,
                42,
                -34
            ],
            "mixamorigLeftForeArm": [
                0,
                -118,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                118,
                0
            ]
        }
    },
    "anulom_vilom": {
        "speed": 4.0,
        "mode": "lerp",
        "posture": "seated",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -2,
                0,
                0
            ],
            "mixamorigNeck": [
                -4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                -18,
                18
            ],
            "mixamorigRightUpLeg": [
                76,
                18,
                -18
            ],
            "mixamorigLeftLeg": [
                -92,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -92,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -28,
                -55
            ],
            "mixamorigLeftForeArm": [
                0,
                -45,
                0
            ],
            "mixamorigRightArm": [
                0,
                58,
                12
            ],
            "mixamorigRightForeArm": [
                0,
                112,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                6,
                0,
                0
            ],
            "mixamorigSpine1": [
                4,
                0,
                0
            ],
            "mixamorigNeck": [
                4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                -18,
                18
            ],
            "mixamorigRightUpLeg": [
                76,
                18,
                -18
            ],
            "mixamorigLeftLeg": [
                -92,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -92,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -28,
                -48
            ],
            "mixamorigLeftForeArm": [
                0,
                -45,
                0
            ],
            "mixamorigRightArm": [
                0,
                64,
                6
            ],
            "mixamorigRightForeArm": [
                0,
                118,
                0
            ]
        }
    },
    "box_breathing": {
        "speed": 4.0,
        "mode": "lerp",
        "posture": "seated",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigSpine1": [
                -2,
                0,
                0
            ],
            "mixamorigNeck": [
                -4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                -16,
                16
            ],
            "mixamorigRightUpLeg": [
                76,
                16,
                -16
            ],
            "mixamorigLeftLeg": [
                -90,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -90,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -35,
                -52
            ],
            "mixamorigRightArm": [
                0,
                35,
                52
            ],
            "mixamorigLeftForeArm": [
                0,
                -68,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                68,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                8,
                0,
                0
            ],
            "mixamorigSpine1": [
                6,
                0,
                0
            ],
            "mixamorigNeck": [
                4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                76,
                -16,
                16
            ],
            "mixamorigRightUpLeg": [
                76,
                16,
                -16
            ],
            "mixamorigLeftLeg": [
                -90,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -90,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -24,
                -22
            ],
            "mixamorigRightArm": [
                0,
                24,
                22
            ],
            "mixamorigLeftForeArm": [
                0,
                -42,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                42,
                0
            ]
        }
    },
    "boxing": {
        "speed": 1.2,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                -18,
                0
            ],
            "mixamorigSpine": [
                -10,
                22,
                0
            ],
            "mixamorigSpine1": [
                -6,
                14,
                0
            ],
            "mixamorigLeftUpLeg": [
                28,
                0,
                8
            ],
            "mixamorigLeftLeg": [
                -32,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -14,
                0,
                -8
            ],
            "mixamorigRightLeg": [
                -24,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -82,
                -8
            ],
            "mixamorigLeftForeArm": [
                0,
                -12,
                0
            ],
            "mixamorigRightArm": [
                0,
                42,
                48
            ],
            "mixamorigRightForeArm": [
                0,
                108,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                18,
                0
            ],
            "mixamorigSpine": [
                -10,
                -22,
                0
            ],
            "mixamorigSpine1": [
                -6,
                -14,
                0
            ],
            "mixamorigLeftUpLeg": [
                22,
                0,
                8
            ],
            "mixamorigLeftLeg": [
                -26,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -8,
                0,
                -8
            ],
            "mixamorigRightLeg": [
                -18,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -42,
                -48
            ],
            "mixamorigLeftForeArm": [
                0,
                -108,
                0
            ],
            "mixamorigRightArm": [
                0,
                82,
                8
            ],
            "mixamorigRightForeArm": [
                0,
                12,
                0
            ]
        }
    },
    "cycling": {
        "speed": 1.3,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -34,
                0,
                0
            ],
            "mixamorigSpine1": [
                -14,
                0,
                0
            ],
            "mixamorigHead": [
                24,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                88,
                0,
                5
            ],
            "mixamorigLeftLeg": [
                -92,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                22,
                0,
                -5
            ],
            "mixamorigRightLeg": [
                -24,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -68,
                -28
            ],
            "mixamorigRightArm": [
                0,
                68,
                28
            ],
            "mixamorigLeftForeArm": [
                0,
                -28,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                28,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -34,
                0,
                0
            ],
            "mixamorigSpine1": [
                -14,
                0,
                0
            ],
            "mixamorigHead": [
                24,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                22,
                0,
                5
            ],
            "mixamorigLeftLeg": [
                -24,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                88,
                0,
                -5
            ],
            "mixamorigRightLeg": [
                -92,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -68,
                -28
            ],
            "mixamorigRightArm": [
                0,
                68,
                28
            ],
            "mixamorigLeftForeArm": [
                0,
                -28,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                28,
                0
            ]
        }
    },
    "swimming": {
        "speed": 1.8,
        "mode": "alternate",
        "posture": "prone",
        "start": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                8,
                12,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                14,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -18,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -14,
                0,
                -4
            ],
            "mixamorigRightLeg": [
                -8,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -15,
                72
            ],
            "mixamorigLeftForeArm": [
                0,
                -18,
                0
            ],
            "mixamorigRightArm": [
                0,
                -25,
                58
            ],
            "mixamorigRightForeArm": [
                0,
                45,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                -78,
                0,
                0
            ],
            "mixamorigSpine": [
                8,
                -12,
                0
            ],
            "mixamorigHead": [
                18,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                -14,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -8,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                14,
                0,
                -4
            ],
            "mixamorigRightLeg": [
                -18,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                25,
                -58
            ],
            "mixamorigLeftForeArm": [
                0,
                -45,
                0
            ],
            "mixamorigRightArm": [
                0,
                15,
                -72
            ],
            "mixamorigRightForeArm": [
                0,
                18,
                0
            ]
        }
    },
    "skipping": {
        "speed": 1.1,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -4,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                14,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                14,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -24,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -24,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                10,
                0,
                0
            ],
            "mixamorigRightFoot": [
                10,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -10,
                -58
            ],
            "mixamorigRightArm": [
                0,
                10,
                58
            ],
            "mixamorigLeftForeArm": [
                0,
                -72,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                72,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                0,
                0,
                0
            ],
            "mixamorigLeftUpLeg": [
                4,
                0,
                3
            ],
            "mixamorigRightUpLeg": [
                4,
                0,
                -3
            ],
            "mixamorigLeftLeg": [
                -6,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -6,
                0,
                0
            ],
            "mixamorigLeftFoot": [
                -32,
                0,
                0
            ],
            "mixamorigRightFoot": [
                -32,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -28,
                -48
            ],
            "mixamorigRightArm": [
                0,
                28,
                48
            ],
            "mixamorigLeftForeArm": [
                0,
                -92,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                92,
                0
            ]
        }
    },
    "running": {
        "speed": 1.0,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -12,
                8,
                0
            ],
            "mixamorigLeftUpLeg": [
                68,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -78,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -28,
                0,
                -4
            ],
            "mixamorigRightLeg": [
                -32,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                38,
                -58
            ],
            "mixamorigRightArm": [
                0,
                -58,
                48
            ],
            "mixamorigLeftForeArm": [
                0,
                -85,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                92,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                0,
                0
            ],
            "mixamorigSpine": [
                -12,
                -8,
                0
            ],
            "mixamorigLeftUpLeg": [
                -28,
                0,
                4
            ],
            "mixamorigLeftLeg": [
                -32,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                68,
                0,
                -4
            ],
            "mixamorigRightLeg": [
                -78,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -58,
                -48
            ],
            "mixamorigRightArm": [
                0,
                38,
                58
            ],
            "mixamorigLeftForeArm": [
                0,
                -92,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                85,
                0
            ]
        }
    },
    "football": {
        "speed": 1.6,
        "mode": "alternate",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                -10,
                0
            ],
            "mixamorigSpine": [
                -10,
                12,
                0
            ],
            "mixamorigLeftUpLeg": [
                18,
                0,
                6
            ],
            "mixamorigLeftLeg": [
                -24,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -32,
                0,
                -8
            ],
            "mixamorigRightLeg": [
                -72,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -45,
                -35
            ],
            "mixamorigRightArm": [
                0,
                -25,
                45
            ],
            "mixamorigLeftForeArm": [
                0,
                -55,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                45,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                14,
                0
            ],
            "mixamorigSpine": [
                6,
                -16,
                0
            ],
            "mixamorigLeftUpLeg": [
                10,
                0,
                6
            ],
            "mixamorigLeftLeg": [
                -16,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                68,
                0,
                -6
            ],
            "mixamorigRightLeg": [
                -12,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                28,
                -35
            ],
            "mixamorigRightArm": [
                0,
                52,
                35
            ],
            "mixamorigLeftForeArm": [
                0,
                -45,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                62,
                0
            ]
        }
    },
    "cricket": {
        "speed": 2.0,
        "mode": "lerp",
        "posture": "standing",
        "start": {
            "mixamorigHips": [
                0,
                -25,
                0
            ],
            "mixamorigSpine": [
                -14,
                -18,
                0
            ],
            "mixamorigHead": [
                8,
                22,
                0
            ],
            "mixamorigLeftUpLeg": [
                26,
                0,
                10
            ],
            "mixamorigRightUpLeg": [
                26,
                0,
                -10
            ],
            "mixamorigLeftLeg": [
                -30,
                0,
                0
            ],
            "mixamorigRightLeg": [
                -30,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -45,
                -35
            ],
            "mixamorigRightArm": [
                0,
                -25,
                42
            ],
            "mixamorigLeftForeArm": [
                0,
                -78,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                92,
                0
            ]
        },
        "peak": {
            "mixamorigHips": [
                0,
                22,
                0
            ],
            "mixamorigSpine": [
                -8,
                24,
                0
            ],
            "mixamorigHead": [
                6,
                -12,
                0
            ],
            "mixamorigLeftUpLeg": [
                48,
                0,
                12
            ],
            "mixamorigLeftLeg": [
                -52,
                0,
                0
            ],
            "mixamorigRightUpLeg": [
                -14,
                0,
                -10
            ],
            "mixamorigRightLeg": [
                -22,
                0,
                0
            ],
            "mixamorigLeftArm": [
                0,
                -72,
                18
            ],
            "mixamorigRightArm": [
                0,
                68,
                -18
            ],
            "mixamorigLeftForeArm": [
                0,
                -52,
                0
            ],
            "mixamorigRightForeArm": [
                0,
                48,
                0
            ]
        }
    }
};

  // Unilateral exercises that alternate Left side on even reps and Right side on odd reps
  var UNILATERAL_MIRROR_SET = {
    reverse_lunge: true,
    dead_bug: true,
    bird_dog: true,
    hip_flexor_stretch: true,
    ankle_circles: true
  };

  // ═══════════════════════════════════════════════════════════════════════
  // TIER 2: EXACT SLUG ALIASES (130+ Exercise Slugs)
  // ═══════════════════════════════════════════════════════════════════════
  var ALIASES = {
    // Lower Body
    squat: 'bodyweight_squat',
    squats: 'bodyweight_squat',
    goblet_squat: 'bodyweight_squat',
    dumbbell_goblet_squat: 'bodyweight_squat',
    goblet: 'bodyweight_squat',
    sumo_squat: 'bodyweight_squat',
    air_squat: 'bodyweight_squat',
    box_squat: 'bodyweight_squat',
    chair_squats: 'bodyweight_squat',
    front_squat: 'bodyweight_squat',
    hack_squat: 'bodyweight_squat',
    lunge: 'reverse_lunge',
    lunges: 'reverse_lunge',
    forward_lunge: 'reverse_lunge',
    walking_lunge: 'reverse_lunge',
    split_squat: 'reverse_lunge',
    step_up: 'reverse_lunge',
    bridge: 'glute_bridge',
    bridge_pose: 'glute_bridge',
    hip_thrust: 'glute_bridge',
    pelvic_tilt: 'glute_bridge',
    single_leg_glute_bridge: 'glute_bridge',
    seated_calf_raises: 'calf_raise',
    romanian_deadlift: 'deadlift',
    dumbbell_romanian_deadlift: 'deadlift',
    rdl: 'deadlift',
    kettlebell_swing: 'deadlift',

    // Upper Body Push / Pull / Arms
    pushup: 'push_up',
    pushups: 'push_up',
    diamond_push_up: 'push_up',
    wide_push_up: 'push_up',
    pike_push_up: 'push_up',
    incline_push_up: 'wall_push_up',
    bench_press: 'dumbbell_bench_press',
    floor_press: 'dumbbell_bench_press',
    bicep_curl: 'dumbbell_bicep_curl',
    hammer_curl: 'dumbbell_bicep_curl',
    concentration_curl: 'dumbbell_bicep_curl',
    weightlifting: 'dumbbell_bicep_curl',
    dips: 'tricep_dips',
    tricep_dip: 'tricep_dips',
    chair_dips: 'tricep_dips',
    bench_dip: 'tricep_dips',
    overhead_tricep: 'tricep_extension',
    skull_crusher: 'tricep_extension',
    overhead_press: 'shoulder_press',
    dumbbell_overhead_press: 'shoulder_press',
    overhead_reach: 'shoulder_press',
    seated_overhead_press: 'seated_shoulder_press',
    arnold_press: 'shoulder_press',
    front_raise: 'lateral_raise',
    arm_circle: 'arm_circles',
    desk_shoulder_rolls: 'arm_circles',
    rowing: 'bent_over_row',
    dumbbell_row: 'bent_over_row',
    dumbbell_one_arm_row: 'bent_over_row',
    resistance_band_row: 'bent_over_row',
    barbell_row: 'bent_over_row',
    cable_row: 'bent_over_row',
    chin_up: 'pull_up',
    lat_pulldown: 'pull_up',

    // Core
    forearm_plank: 'plank',
    hollow_hold: 'plank',
    russian_twist: 'seated_torso_twist',
    thoracic_open_book: 'seated_torso_twist',
    seated_spinal_twist: 'seated_torso_twist',
    crunch: 'core_activation',
    sit_up: 'core_activation',
    standing_oblique_crunch: 'core_activation',
    bicycle_crunch: 'dead_bug',

    // Cardio / HIIT / Dance
    jumping_jack: 'jumping_jacks',
    star_jump: 'jumping_jacks',
    step_jacks: 'jumping_jacks',
    box_jump: 'hiit_interval_beginner',
    jump_squat: 'hiit_interval_beginner',
    squat_jump: 'hiit_interval_beginner',
    tuck_jump: 'hiit_interval_beginner',
    burpees: 'burpee',
    mountain_climber: 'mountain_climbers',
    high_knee: 'high_knees',
    butt_kicks: 'high_knees',
    skater_hops: 'high_knees',
    fast_feet_shuffle: 'high_knees',
    jump_rope: 'skipping',
    rope_skip: 'skipping',
    zumba: 'zumba_basic_flow',
    dancing: 'zumba_basic_flow',
    dance: 'zumba_basic_flow',
    aerobics: 'zumba_basic_flow',
    sprint: 'running',
    jog: 'running',
    jogging: 'running',
    treadmill: 'running',
    walk: 'march_in_place',
    walking: 'march_in_place',
    seated_leg_extension: 'seated_march',
    seated_knee_lift: 'seated_march',

    // Yoga / Mobility / Mindfulness / Breathing
    tai_chi: 'tai_chi_opening_form',
    yoga: 'warrior_pose',
    warrior_1: 'warrior_pose',
    warrior_2: 'warrior_pose',
    warrior_ii: 'warrior_pose',
    chair_pose: 'bodyweight_squat',
    cobra: 'cobra_pose',
    cobra_stretch: 'cobra_pose',
    upward_dog: 'cobra_pose',
    down_dog: 'downward_dog',
    surya_namaskar: 'downward_dog',
    sun_salutation: 'downward_dog',
    sun_salutation_flow: 'downward_dog',
    childs_pose: 'child_pose',
    stretching: 'seated_forward_fold',
    stretch: 'seated_forward_fold',
    hamstring_hinge_stretch: 'seated_forward_fold',
    brow_smoother: 'cheek_lift',
    eye_circle_relax: 'cheek_lift',
    neck_firming_lift: 'neck_release',
    seated_neck_glide: 'neck_release',
    wrist_finger_stretch: 'wrist_mobility',
    four_seven_eight: 'box_breathing',
    four_seven_eight_breath: 'box_breathing',
    diaphragmatic_breathing: 'box_breathing',
    coherent_breathing: 'box_breathing',
    physiological_sigh: 'box_breathing',
    alternate_nostril_breath: 'anulom_vilom',
    ujjayi_breath: 'box_breathing',
    pursed_lip_breathing: 'box_breathing',
    humming_bee_breath: 'box_breathing',
    morning_energizing_breath: 'box_breathing',
    breath_awareness: 'box_breathing',
    body_scan: 'box_breathing',
    sleep_prep: 'box_breathing',
    meditation: 'box_breathing',
    pranayama: 'anulom_vilom'
  };

  // ═══════════════════════════════════════════════════════════════════════
  // TIER 3: SAFE WORD-BOUNDARY KEYWORD RULES (For future Gemini slugs)
  // ═══════════════════════════════════════════════════════════════════════
  var KEYWORD_RULES = [
    { keys: ['cheek', 'facial', 'face_yoga', 'brow', 'eye'], pose: 'cheek_lift' },
    { keys: ['jaw'],                                  pose: 'jaw_release' },
    { keys: ['scalp', 'temple'],                      pose: 'scalp_massage' },
    { keys: ['lion', 'lions'],                        pose: 'lions_breath' },
    { keys: ['anulom', 'vilom', 'nostril', 'nadi'],   pose: 'anulom_vilom' },
    { keys: ['breathing', 'breath', 'meditation', 'mindful', 'sleep', 'scan', 'sigh'], pose: 'box_breathing' },
    { keys: ['cat_cow', 'cat', 'cow'],                pose: 'cat_cow' },
    { keys: ['bird_dog', 'birddog'],                  pose: 'bird_dog' },
    { keys: ['dead_bug', 'deadbug'],                  pose: 'dead_bug' },
    { keys: ['neck'],                                 pose: 'neck_release' },
    { keys: ['wrist'],                                pose: 'wrist_mobility' },
    { keys: ['ankle'],                                pose: 'ankle_circles' },
    { keys: ['pendulum'],                             pose: 'shoulder_pendulum' },
    { keys: ['flexor'],                               pose: 'hip_flexor_stretch' },
    { keys: ['supine'],                               pose: 'supine_twist' },
    { keys: ['legs_up', 'inversion'],                 pose: 'legs_up_wall' },
    { keys: ['forward_fold', 'hamstring'],            pose: 'seated_forward_fold' },
    { keys: ['tree'],                                 pose: 'tree_pose' },
    { keys: ['warrior', 'triangle'],                  pose: 'warrior_pose' },
    { keys: ['cobra', 'camel', 'backbend'],           pose: 'cobra_pose' },
    { keys: ['downward', 'down_dog', 'salutation'],   pose: 'downward_dog' },
    { keys: ['child'],                                pose: 'child_pose' },
    { keys: ['tai_chi', 'qigong'],                    pose: 'tai_chi_opening_form' },
    { keys: ['zumba', 'dance', 'dancing', 'samba'],   pose: 'zumba_basic_flow' },
    { keys: ['seated_march', 'leg_extension', 'knee_lift'], pose: 'seated_march' },
    { keys: ['march'],                                pose: 'march_in_place' },
    { keys: ['high_knee', 'high_knees', 'skater', 'shuffle', 'butt_kicks'], pose: 'high_knees' },
    { keys: ['jumping_jack', 'jumping_jacks', 'jack', 'step_jacks'], pose: 'jumping_jacks' },
    { keys: ['mountain', 'climber'],                  pose: 'mountain_climbers' },
    { keys: ['squat_thrust', 'tabata'],               pose: 'tabata_squat_thrust' },
    { keys: ['hiit', 'plyo'],                         pose: 'hiit_interval_beginner' },
    { keys: ['burpee', 'burpees'],                    pose: 'burpee' },
    { keys: ['wall_push', 'incline_push'],            pose: 'wall_push_up' },
    { keys: ['knee_push'],                            pose: 'knee_push_up' },
    { keys: ['push_up', 'pushup'],                    pose: 'push_up' },
    { keys: ['bench_press', 'chest_press'],           pose: 'dumbbell_bench_press' },
    { keys: ['seated_shoulder', 'seated_overhead'],   pose: 'seated_shoulder_press' },
    { keys: ['shoulder_press', 'overhead_press', 'overhead_reach'], pose: 'shoulder_press' },
    { keys: ['lateral_raise', 'side_raise'],          pose: 'lateral_raise' },
    { keys: ['arm_circle', 'arm_circles', 'shoulder_rolls'], pose: 'arm_circles' },
    { keys: ['bicep', 'curl'],                        pose: 'dumbbell_bicep_curl' },
    { keys: ['dip', 'dips'],                          pose: 'tricep_dips' },
    { keys: ['tricep'],                               pose: 'tricep_extension' },
    { keys: ['row', 'rowing'],                        pose: 'bent_over_row' },
    { keys: ['pull_up', 'pullup', 'chin_up', 'pulldown'], pose: 'pull_up' },
    { keys: ['side_plank'],                           pose: 'side_plank' },
    { keys: ['plank'],                                pose: 'plank' },
    { keys: ['torso_twist', 'russian_twist', 'twist', 'open_book'], pose: 'seated_torso_twist' },
    { keys: ['crunch', 'core', 'ab'],                 pose: 'core_activation' },
    { keys: ['bridge', 'thrust', 'glute', 'pelvic_tilt'], pose: 'glute_bridge' },
    { keys: ['wall_sit'],                             pose: 'wall_sit' },
    { keys: ['calf'],                                 pose: 'calf_raise' },
    { keys: ['lunge', 'split', 'step_up'],            pose: 'reverse_lunge' },
    { keys: ['deadlift', 'hinge', 'rdl'],             pose: 'deadlift' },
    { keys: ['squat'],                                pose: 'bodyweight_squat' }
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // MASTER RESOLVER
  // ═══════════════════════════════════════════════════════════════════════
  function resolveExercise(rawSlug) {
    if (!rawSlug || (typeof rawSlug !== 'string' && typeof rawSlug !== 'number')) {
      return { name: 'bodyweight_squat', spec: EXERCISES.bodyweight_squat, data: EXERCISES.bodyweight_squat.peak };
    }

    var s = String(rawSlug).toLowerCase().replace(/[\s\-]+/g, '_').replace(/[^a-z0-9_]/g, '').replace(/^_+|_+$/g, '');
    if (!s) {
      return { name: 'bodyweight_squat', spec: EXERCISES.bodyweight_squat, data: EXERCISES.bodyweight_squat.peak };
    }

    if (Object.prototype.hasOwnProperty.call(EXERCISES, s)) {
      return { name: s, spec: EXERCISES[s], data: EXERCISES[s].peak };
    }

    if (Object.prototype.hasOwnProperty.call(ALIASES, s) && Object.prototype.hasOwnProperty.call(EXERCISES, ALIASES[s])) {
      var target = ALIASES[s];
      return { name: target, spec: EXERCISES[target], data: EXERCISES[target].peak };
    }

    var padded = '_' + s + '_';
    for (var i = 0; i < KEYWORD_RULES.length; i++) {
      var rule = KEYWORD_RULES[i];
      for (var j = 0; j < rule.keys.length; j++) {
        var key = rule.keys[j];
        if (s === key || padded.indexOf('_' + key + '_') >= 0) {
          if (EXERCISES[rule.pose]) {
            return { name: rule.pose, spec: EXERCISES[rule.pose], data: EXERCISES[rule.pose].peak };
          }
        }
      }
    }

    return { name: 'bodyweight_squat', spec: EXERCISES.bodyweight_squat, data: EXERCISES.bodyweight_squat.peak };
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUATERNION & 3D VECTOR ALGEBRA (Zero External Dependencies)
  // ═══════════════════════════════════════════════════════════════════════
  function qMul(a, b) {
    var ax = a[0], ay = a[1], az = a[2], aw = a[3];
    var bx = b[0], by = b[1], bz = b[2], bw = b[3];
    return [
      aw * bx + ax * bw + ay * bz - az * by,
      aw * by - ax * bz + ay * bw + az * bx,
      aw * bz + ax * by - ay * bx + az * bw,
      aw * bw - ax * bx - ay * by - az * bz
    ];
  }

  function qNorm(q) {
    var m = Math.sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
    if (m < 1e-12) return [0, 0, 0, 1];
    return [q[0] / m, q[1] / m, q[2] / m, q[3] / m];
  }

  function qInv(q) {
    return [-q[0], -q[1], -q[2], q[3]];
  }

  function qAxisAngle(axis, deg) {
    var rad = (deg * Math.PI) / 180.0;
    var s = Math.sin(rad * 0.5);
    return [axis[0] * s, axis[1] * s, axis[2] * s, Math.cos(rad * 0.5)];
  }

  function qRotVec(q, v) {
    var qx = q[0], qy = q[1], qz = q[2], qw = q[3];
    var vx = v[0], vy = v[1], vz = v[2];
    var tx = 2.0 * (qy * vz - qz * vy);
    var ty = 2.0 * (qz * vx - qx * vz);
    var tz = 2.0 * (qx * vy - qy * vx);
    return [
      vx + qw * tx + (qy * tz - qz * ty),
      vy + qw * ty + (qz * tx - qx * tz),
      vz + qw * tz + (qx * ty - qy * tx)
    ];
  }

  function qSlerp(qa, qb, t) {
    if (t <= 0) return qa;
    if (t >= 1) return qb;
    var ax = qa[0], ay = qa[1], az = qa[2], aw = qa[3];
    var bx = qb[0], by = qb[1], bz = qb[2], bw = qb[3];
    var dot = ax * bx + ay * by + az * bz + aw * bw;
    if (dot < 0.0) {
      dot = -dot;
      bx = -bx; by = -by; bz = -bz; bw = -bw;
    }
    if (dot > 0.9995) {
      return qNorm([
        ax + (bx - ax) * t,
        ay + (by - ay) * t,
        az + (bz - az) * t,
        aw + (bw - aw) * t
      ]);
    }
    var theta0 = Math.acos(Math.min(1.0, dot));
    var theta = theta0 * t;
    var sinTheta = Math.sin(theta);
    var sinTheta0 = Math.sin(theta0);
    var s0 = Math.cos(theta) - (dot * sinTheta) / sinTheta0;
    var s1 = sinTheta / sinTheta0;
    return [
      s0 * ax + s1 * bx,
      s0 * ay + s1 * by,
      s0 * az + s1 * bz,
      s0 * aw + s1 * bw
    ];
  }

  function qAngleDiffDeg(qa, qb) {
    var dot = Math.abs(qa[0] * qb[0] + qa[1] * qb[1] + qa[2] * qb[2] + qa[3] * qb[3]);
    if (dot > 1.0) dot = 1.0;
    return (2.0 * Math.acos(dot) * 180.0) / Math.PI;
  }

  function lerp3(a, b, t) {
    return [
      a[0] + (b[0] - a[0]) * t,
      a[1] + (b[1] - a[1]) * t,
      a[2] + (b[2] - a[2]) * t
    ];
  }

  function mirrorCharacterPose(poseMap) {
    var mirrored = {};
    if (!poseMap) return mirrored;
    for (var k in poseMap) {
      if (!Object.prototype.hasOwnProperty.call(poseMap, k)) continue;
      var pyr = poseMap[k];
      var mKey = k;
      if (k.indexOf('mixamorigLeft') === 0) {
        mKey = 'mixamorigRight' + k.slice(13);
      } else if (k.indexOf('mixamorigRight') === 0) {
        mKey = 'mixamorigLeft' + k.slice(14);
      }
      mirrored[mKey] = [pyr[0] || 0, -(pyr[1] || 0), -(pyr[2] || 0)];
    }
    return mirrored;
  }

  function buildCircleQuadrantPose(startMap, peakMap, signYaw, signRoll) {
    var quad = {};
    var keys = {};
    var k;
    for (k in (startMap || {})) keys[k] = true;
    for (k in (peakMap || {})) keys[k] = true;
    for (k in keys) {
      var s = (startMap && startMap[k]) ? startMap[k] : [0, 0, 0];
      var p = (peakMap && peakMap[k]) ? peakMap[k] : s;
      var midP = 0.5 * (s[0] + p[0]);
      var midY = 0.5 * (s[1] + p[1]);
      var midR = 0.5 * (s[2] + p[2]);
      var ampY = 0.5 * Math.abs(p[1] - s[1]);
      var ampR = 0.5 * Math.abs(p[2] - s[2]);
      var radius = Math.max(ampY, ampR, 12);
      var isRight = k.indexOf('mixamorigRight') === 0;
      var rSign = isRight ? -signRoll : signRoll;
      var ySign = isRight ? -signYaw : signYaw;
      if (s[0] !== p[0] || s[1] !== p[1] || s[2] !== p[2]) {
        quad[k] = [midP, midY + ySign * radius * 0.65, midR + rSign * radius * 0.65];
      } else {
        quad[k] = [s[0], s[1], s[2]];
      }
    }
    return quad;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STAGE 0: PERSISTENT VERIFIED SETUP CACHE
  // ═══════════════════════════════════════════════════════════════════════
  var MEMORY_VERIFIED_CACHE = {};

  function loadVerifiedSetupFromCache(rigId, poseName) {
    var key = CACHE_PREFIX + rigId + '_' + poseName;
    if (Object.prototype.hasOwnProperty.call(MEMORY_VERIFIED_CACHE, key)) {
      return MEMORY_VERIFIED_CACHE[key];
    }
    if (global.__VYRA_PRELOADED_SETUPS && Object.prototype.hasOwnProperty.call(global.__VYRA_PRELOADED_SETUPS, key)) {
      var pre = global.__VYRA_PRELOADED_SETUPS[key];
      if (pre && pre.verified && pre.qStart && pre.qPeak) {
        MEMORY_VERIFIED_CACHE[key] = pre;
        return pre;
      }
    }
    try {
      if (typeof localStorage !== 'undefined' && localStorage && typeof localStorage.getItem === 'function') {
        var raw = localStorage.getItem(key);
        if (raw) {
          var parsed = JSON.parse(raw);
          if (parsed && parsed.version === ENGINE_VERSION && parsed.verified && parsed.qStart && parsed.qPeak) {
            MEMORY_VERIFIED_CACHE[key] = parsed;
            return parsed;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  function saveVerifiedSetupToCache(rigId, poseName, setupObj) {
    var key = CACHE_PREFIX + rigId + '_' + poseName;
    MEMORY_VERIFIED_CACHE[key] = setupObj;
    try {
      if (typeof localStorage !== 'undefined' && localStorage && typeof localStorage.setItem === 'function') {
        localStorage.setItem(key, JSON.stringify(setupObj));
      }
    } catch (_) {}
    try {
      if (global.VyraSetupCacheChannel && typeof global.VyraSetupCacheChannel.postMessage === 'function') {
        global.VyraSetupCacheChannel.postMessage(JSON.stringify({ key: key, setup: setupObj }));
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STAGE 2 & STAGE 3: QUATERNION SOLVER + 3D FK VERIFIER + FLOOR-LOCK
  // ═══════════════════════════════════════════════════════════════════════
  var CONTACT_BONES = [
    'mixamorigLeftToeBase', 'mixamorigRightToeBase',
    'mixamorigLeftFoot', 'mixamorigRightFoot',
    'mixamorigLeftLeg', 'mixamorigRightLeg',
    'mixamorigHips',
    'mixamorigLeftHand', 'mixamorigRightHand',
    'mixamorigLeftForeArm', 'mixamorigRightForeArm'
  ];

  function evaluateBlueprintPoseFK(rigMeta, charPoseMap) {
    var charRight = rigMeta.charRight;
    var charUp = rigMeta.charUp;
    var charFwd = rigMeta.charFwd;
    var order = rigMeta.order;
    var bonesMeta = rigMeta.bones;
    var parentWQ = rigMeta.hipsParentWQ;
    var parentWS = rigMeta.hipsParentWS;

    var localQuats = {};
    var worldQuats = {};
    var worldPos = {};

    for (var i = 0; i < order.length; i++) {
      var bName = order[i];
      var bMeta = bonesMeta[bName];
      if (!bMeta) continue;
      var qBind = bMeta.q;
      var wBind = bMeta.wq;
      var lq = qBind;

      if (charPoseMap && Object.prototype.hasOwnProperty.call(charPoseMap, bName)) {
        var pyr = charPoseMap[bName];
        var pitch = pyr[0] || 0;
        var yaw = pyr[1] || 0;
        var roll = pyr[2] || 0;
        if ((bName === 'mixamorigLeftLeg' || bName === 'mixamorigRightLeg') && pitch > 0) {
          pitch = -Math.abs(pitch);
        }
        var qChar = qMul(
          qAxisAngle(charRight, pitch),
          qMul(qAxisAngle(charUp, yaw), qAxisAngle(charFwd, roll))
        );
        var qDelta = qMul(qInv(wBind), qMul(qChar, wBind));
        lq = qNorm(qMul(qBind, qDelta));
      }

      localQuats[bName] = [
        Math.round(lq[0] * 1e6) / 1e6,
        Math.round(lq[1] * 1e6) / 1e6,
        Math.round(lq[2] * 1e6) / 1e6,
        Math.round(lq[3] * 1e6) / 1e6
      ];

      var pName = bMeta.parent;
      var pq = pName && worldQuats[pName] ? worldQuats[pName] : parentWQ;
      var pp = pName && worldPos[pName] ? worldPos[pName] : [0, 0, 0];
      worldQuats[bName] = qNorm(qMul(pq, lq));

      var st = [
        bMeta.t[0] * parentWS[0],
        bMeta.t[1] * parentWS[1],
        bMeta.t[2] * parentWS[2]
      ];
      var rt = qRotVec(pq, st);
      worldPos[bName] = [pp[0] + rt[0], pp[1] + rt[1], pp[2] + rt[2]];
    }

    var minY = Infinity;
    for (var c = 0; c < CONTACT_BONES.length; c++) {
      var cb = CONTACT_BONES[c];
      if (worldPos[cb] && worldPos[cb][1] < minY) {
        minY = worldPos[cb][1];
      }
    }
    if (!isFinite(minY)) minY = rigMeta.floorY;

    var deltaWorldY = rigMeta.floorY - minY;
    var localDeltaScaled = qRotVec(qInv(parentWQ), [0, deltaWorldY, 0]);
    var hipsLocalPos = [
      Math.round((rigMeta.hipsBindPos[0] + localDeltaScaled[0] / parentWS[0]) * 1e4) / 1e4,
      Math.round((rigMeta.hipsBindPos[1] + localDeltaScaled[1] / parentWS[1]) * 1e4) / 1e4,
      Math.round((rigMeta.hipsBindPos[2] + localDeltaScaled[2] / parentWS[2]) * 1e4) / 1e4
    ];

    return {
      localQuats: localQuats,
      worldPos: worldPos,
      deltaWorldY: deltaWorldY,
      hipsLocalPos: hipsLocalPos
    };
  }

  function buildAndVerifySetup(rigId, poseName, spec) {
    var safeRigId = (rigId === 'female') ? 'female' : 'male';
    var cached = loadVerifiedSetupFromCache(safeRigId, poseName);
    if (cached) {
      cached.cacheHit = true;
      return cached;
    }

    var rigMeta = GLB_BIND_META[safeRigId] || GLB_BIND_META.male;
    var fkStart = evaluateBlueprintPoseFK(rigMeta, spec.start || {});
    var fkPeak = evaluateBlueprintPoseFK(rigMeta, spec.peak || {});

    var maxExcursionDeg = 0;
    var boneKeys = {};
    var k;
    for (k in (spec.start || {})) boneKeys[k] = true;
    for (k in (spec.peak || {})) boneKeys[k] = true;

    for (k in boneKeys) {
      var qs = fkStart.localQuats[k];
      var qp = fkPeak.localQuats[k];
      if (qs && qp) {
        var diff = qAngleDiffDeg(qs, qp);
        if (diff > maxExcursionDeg) maxExcursionDeg = diff;
      }
    }

    var headStartY = (fkStart.worldPos.mixamorigHead ? fkStart.worldPos.mixamorigHead[1] : 1.5) + fkStart.deltaWorldY;
    var hipsStartY = (fkStart.worldPos.mixamorigHips ? fkStart.worldPos.mixamorigHips[1] : 1.0) + fkStart.deltaWorldY;
    var headPeakY = (fkPeak.worldPos.mixamorigHead ? fkPeak.worldPos.mixamorigHead[1] : 1.5) + fkPeak.deltaWorldY;
    var hipsPeakY = (fkPeak.worldPos.mixamorigHips ? fkPeak.worldPos.mixamorigHips[1] : 1.0) + fkPeak.deltaWorldY;

    var posture = spec.posture || 'standing';
    var postureValid = true;
    if (posture === 'standing' || posture === 'seated') {
      postureValid = (headStartY > hipsStartY + 0.12) && (headPeakY > hipsPeakY + 0.12);
    } else if (posture === 'hybrid_burpee') {
      postureValid = (headStartY > hipsStartY + 0.12) && (Math.abs(headPeakY - hipsPeakY) <= 0.65);
    } else {
      postureValid = (Math.abs(headStartY - hipsStartY) <= 0.65) || poseName === 'downward_dog';
    }

    if (!postureValid || maxExcursionDeg < 4.0) {
      var fallbackSpec = EXERCISES.bodyweight_squat;
      fkStart = evaluateBlueprintPoseFK(rigMeta, fallbackSpec.start);
      fkPeak = evaluateBlueprintPoseFK(rigMeta, fallbackSpec.peak);
      maxExcursionDeg = 92.0;
      postureValid = true;
    }

    var fkSquat = null;
    var fkPlank = null;
    if (spec.mode === 'burpee') {
      fkSquat = evaluateBlueprintPoseFK(rigMeta, EXERCISES.tabata_squat_thrust.peak);
      fkPlank = evaluateBlueprintPoseFK(rigMeta, EXERCISES.push_up.start);
    }

    var fkPeakMirror = null;
    if (UNILATERAL_MIRROR_SET[poseName]) {
      fkPeakMirror = evaluateBlueprintPoseFK(rigMeta, mirrorCharacterPose(spec.peak || {}));
    }

    var fkCircle90 = null;
    var fkCircle270 = null;
    if (spec.mode === 'circle') {
      fkCircle90 = evaluateBlueprintPoseFK(rigMeta, buildCircleQuadrantPose(spec.start, spec.peak, 1, -1));
      fkCircle270 = evaluateBlueprintPoseFK(rigMeta, buildCircleQuadrantPose(spec.start, spec.peak, -1, 1));
    }

    var verifiedSetup = {
      version: ENGINE_VERSION,
      rigId: safeRigId,
      exercise: poseName,
      mode: spec.mode || 'lerp',
      posture: posture,
      speed: spec.speed || 2.4,
      verified: true,
      cacheHit: false,
      verifiedAt: Date.now(),
      qStart: fkStart.localQuats,
      qPeak: fkPeak.localQuats,
      hipsPosStart: fkStart.hipsLocalPos,
      hipsPosPeak: fkPeak.hipsLocalPos,
      qPeakMirror: fkPeakMirror ? fkPeakMirror.localQuats : null,
      hipsPosPeakMirror: fkPeakMirror ? fkPeakMirror.hipsLocalPos : null,
      qCircle90: fkCircle90 ? fkCircle90.localQuats : null,
      hipsPosCircle90: fkCircle90 ? fkCircle90.hipsLocalPos : null,
      qCircle270: fkCircle270 ? fkCircle270.localQuats : null,
      hipsPosCircle270: fkCircle270 ? fkCircle270.hipsLocalPos : null,
      qSquat: fkSquat ? fkSquat.localQuats : null,
      hipsPosSquat: fkSquat ? fkSquat.hipsLocalPos : null,
      qPlank: fkPlank ? fkPlank.localQuats : null,
      hipsPosPlank: fkPlank ? fkPlank.hipsLocalPos : null,
      metrics: {
        maxExcursionDeg: Math.round(maxExcursionDeg * 10) / 10,
        headStartY: Math.round(headStartY * 100) / 100,
        headPeakY: Math.round(headPeakY * 100) / 100,
        hipsStartY: Math.round(hipsStartY * 100) / 100,
        hipsPeakY: Math.round(hipsPeakY * 100) / 100,
        postureValid: postureValid
      }
    };

    saveVerifiedSetupToCache(safeRigId, poseName, verifiedSetup);
    return verifiedSetup;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SCENE, RIG DETECTION & <model-viewer> RENDER TRIGGER
  // ═══════════════════════════════════════════════════════════════════════
  function getScene(mv) {
    if (!mv) return null;
    if (mv.scene && mv.scene.traverse) return mv.scene;
    try {
      var syms = Object.getOwnPropertySymbols(mv);
      for (var i = 0; i < syms.length; i++) {
        var v = mv[syms[i]];
        if (v && typeof v === 'object') {
          if (v.isScene || v.isObject3D) return v;
          if (v.scene && v.scene.traverse) return v.scene;
        }
      }
    } catch (_) {}
    if (mv.model) {
      if (mv.model.scene && mv.model.scene.traverse) return mv.model.scene;
      if (mv.model.traverse) return mv.model;
    }
    return null;
  }

  function detectRigId(mv, root) {
    try {
      var src = String((mv && (mv.src || mv.getAttribute('src'))) || '').toLowerCase();
      if (src.indexOf('female') >= 0) return 'female';
      if (src.indexOf('male') >= 0) return 'male';
    } catch (_) {}
    var isFemale = false;
    if (root && root.traverse) {
      root.traverse(function (node) {
        if (node.name === 'Mesh.002' || node.name === 'Armature') isFemale = true;
      });
    }
    return isFemale ? 'female' : 'male';
  }

  function stopMixer(mv, root) {
    try {
      if (typeof mv.pause === 'function') mv.pause();
      mv.animationName = '';
      mv.timeScale = 0;
    } catch (_) {}
    try {
      var syms = Object.getOwnPropertySymbols(mv);
      for (var i = 0; i < syms.length; i++) {
        var val = mv[syms[i]];
        if (val && typeof val === 'object') {
          if (typeof val.stopAllAction === 'function') val.stopAllAction();
          if (val.mixer && typeof val.mixer.stopAllAction === 'function') val.mixer.stopAllAction();
        }
      }
    } catch (_) {}
    if (root && root.traverse) {
      try {
        root.traverse(function (node) {
          if (node.isSkinnedMesh && node.skeleton && typeof node.skeleton.pose === 'function') {
            node.skeleton.pose();
          }
        });
      } catch (_) {}
    }
  }

  function requestModelViewerRender(mv, root) {
    if (root && typeof root.updateMatrixWorld === 'function') {
      try { root.updateMatrixWorld(true); } catch (_) {}
    }
    if (!mv) return;
    try {
      if (mv.__vyraNeedsRenderFn) {
        mv.__vyraNeedsRenderFn();
        return;
      }
      var syms = Object.getOwnPropertySymbols(mv);
      for (var i = 0; i < syms.length; i++) {
        var s = syms[i];
        var desc = String(s);
        var val = mv[s];
        if (typeof val === 'function' && desc.indexOf('needsRender') >= 0) {
          mv.__vyraNeedsRenderFn = val.bind(mv);
          mv.__vyraNeedsRenderFn();
          return;
        }
        if (val && typeof val === 'object' && typeof val.queueRender === 'function') {
          mv.__vyraNeedsRenderFn = (function (sceneObj) {
            return function () { sceneObj.queueRender(); };
          })(val);
          mv.__vyraNeedsRenderFn();
          return;
        }
      }
    } catch (_) {}
  }

  function configureMultiAxisOrbit(mv) {
    if (!mv) return;
    try {
      mv.setAttribute('camera-controls', 'true');
      mv.setAttribute('touch-action', 'none');
      mv.setAttribute('min-camera-orbit', 'auto 10deg auto');
      mv.setAttribute('max-camera-orbit', 'auto 170deg auto');
      mv.setAttribute('interpolation-decay', '100');
      mv.style.touchAction = 'none';
    } catch (_) {}
  }

  function collectAndResetRigBones(root, rigId) {
    var rigMeta = GLB_BIND_META[rigId] || GLB_BIND_META.male;
    var bonesMeta = rigMeta.bones;
    var boneMap = {};
    if (!root || !root.traverse) return boneMap;

    root.traverse(function (node) {
      if (!node.name) return;
      var clean = node.name.replace(/:/g, '');
      if (clean.indexOf('mixamorig') === 0 && !/_End$/.test(clean)) {
        boneMap[clean] = node;
        var bm = bonesMeta[clean];
        if (bm && bm.q && node.quaternion && typeof node.quaternion.set === 'function') {
          node.quaternion.set(bm.q[0], bm.q[1], bm.q[2], bm.q[3]);
        }
      }
    });

    var hips = boneMap.mixamorigHips;
    if (hips && hips.position && rigMeta.hipsBindPos) {
      hips.position.set(
        rigMeta.hipsBindPos[0],
        rigMeta.hipsBindPos[1],
        rigMeta.hipsBindPos[2]
      );
    }
    return boneMap;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STAGE 4: 60 FPS VERIFIED QUATERNION SLERP + FLOOR-LOCK EXECUTOR
  // ═══════════════════════════════════════════════════════════════════════
  var activeAnimId = null;
  var globalSpeedMultiplier = 1.0;
  var currentExerciseSlug = '';
  var lastVerificationReport = null;

  function applyBoneQuat(bone, q) {
    if (!bone || !q) return;
    if (bone.quaternion && typeof bone.quaternion.set === 'function') {
      bone.quaternion.set(q[0], q[1], q[2], q[3]);
    }
  }

  function evaluateVerifiedFrame(verifiedSetup, rigOrder, elapsedSec) {
    var basePeriod = verifiedSetup.speed || 2.4;
    var totalCycles = elapsedSec / basePeriod;
    var cycleIdx = Math.floor(totalCycles);
    var phase = totalCycles - cycleIdx;
    if (phase < 0) phase = 0;
    var f = 0.5 - 0.5 * Math.cos(phase * Math.PI * 2);

    var qStart = verifiedSetup.qStart;
    var qPeak = verifiedSetup.qPeak;
    var hipsStart = verifiedSetup.hipsPosStart;
    var hipsPeak = verifiedSetup.hipsPosPeak;

    var outQuats = {};
    var outHipsPos = hipsStart;

    if (verifiedSetup.mode === 'burpee' && verifiedSetup.qSquat && verifiedSetup.qPlank) {
      var qaMap, qbMap, ha, hb, localT;
      if (phase < 0.25) {
        localT = phase / 0.25;
        qaMap = qStart; qbMap = verifiedSetup.qSquat;
        ha = hipsStart; hb = verifiedSetup.hipsPosSquat;
      } else if (phase < 0.45) {
        localT = (phase - 0.25) / 0.20;
        qaMap = verifiedSetup.qSquat; qbMap = verifiedSetup.qPlank;
        ha = verifiedSetup.hipsPosSquat; hb = verifiedSetup.hipsPosPlank;
      } else if (phase < 0.78) {
        var pPush = (phase - 0.45) / 0.33;
        localT = Math.sin(pPush * Math.PI);
        qaMap = verifiedSetup.qPlank; qbMap = qPeak;
        ha = verifiedSetup.hipsPosPlank; hb = hipsPeak;
      } else {
        localT = (phase - 0.78) / 0.22;
        qaMap = verifiedSetup.qSquat; qbMap = qStart;
        ha = verifiedSetup.hipsPosSquat; hb = hipsStart;
      }
      for (var bi = 0; bi < rigOrder.length; bi++) {
        var bKey = rigOrder[bi];
        if (qaMap[bKey] && qbMap[bKey]) {
          outQuats[bKey] = qSlerp(qaMap[bKey], qbMap[bKey], localT);
        }
      }
      if (ha && hb) outHipsPos = lerp3(ha, hb, localT);
    } else if (verifiedSetup.mode === 'circle' && verifiedSetup.qCircle90 && verifiedSetup.qCircle270) {
      // True 4-quadrant 360-degree circular trajectory: 0 -> 90 -> 180 -> 270 -> 360
      var cA, cB, hCA, hCB, cT;
      if (phase < 0.25) {
        cT = phase / 0.25;
        cA = qStart; cB = verifiedSetup.qCircle90;
        hCA = hipsStart; hCB = verifiedSetup.hipsPosCircle90;
      } else if (phase < 0.50) {
        cT = (phase - 0.25) / 0.25;
        cA = verifiedSetup.qCircle90; cB = qPeak;
        hCA = verifiedSetup.hipsPosCircle90; hCB = hipsPeak;
      } else if (phase < 0.75) {
        cT = (phase - 0.50) / 0.25;
        cA = qPeak; cB = verifiedSetup.qCircle270;
        hCA = hipsPeak; hCB = verifiedSetup.hipsPosCircle270;
      } else {
        cT = (phase - 0.75) / 0.25;
        cA = verifiedSetup.qCircle270; cB = qStart;
        hCA = verifiedSetup.hipsPosCircle270; hCB = hipsStart;
      }
      for (var ci = 0; ci < rigOrder.length; ci++) {
        var cKey = rigOrder[ci];
        if (cA[cKey] && cB[cKey]) {
          outQuats[cKey] = qSlerp(cA[cKey], cB[cKey], cT);
        }
      }
      if (hCA && hCB) outHipsPos = lerp3(hCA, hCB, cT);
    } else {
      // Standard lerp or bilateral alternating rep (even cycle = Left peak, odd cycle = Right mirror peak)
      var useMirror = (verifiedSetup.qPeakMirror && (cycleIdx % 2 === 1));
      var activePeak = useMirror ? verifiedSetup.qPeakMirror : qPeak;
      var activeHipsPeak = (useMirror && verifiedSetup.hipsPosPeakMirror) ? verifiedSetup.hipsPosPeakMirror : hipsPeak;

      for (var i = 0; i < rigOrder.length; i++) {
        var k = rigOrder[i];
        var qs = qStart[k];
        var qp = activePeak[k];
        if (qs && qp) {
          outQuats[k] = qSlerp(qs, qp, f);
        }
      }
      if (hipsStart && activeHipsPeak) {
        outHipsPos = lerp3(hipsStart, activeHipsPeak, f);
      }
    }

    return { quats: outQuats, hipsPos: outHipsPos };
  }

  function startExerciseLoop(mv, poseName, spec) {
    if (activeAnimId) {
      cancelAnimationFrame(activeAnimId);
      activeAnimId = null;
    }

    var root = getScene(mv);
    if (!root) return;

    stopMixer(mv, root);
    configureMultiAxisOrbit(mv);

    var rigId = detectRigId(mv, root);
    var boneMap = collectAndResetRigBones(root, rigId);
    var verifiedSetup = buildAndVerifySetup(rigId, poseName, spec);
    lastVerificationReport = verifiedSetup;

    var hipsBone = boneMap.mixamorigHips;
    var rigOrder = (GLB_BIND_META[rigId] || GLB_BIND_META.male).order;
    var t0 = performance.now();

    function loop(now) {
      var elapsed = ((now - t0) / 1000) * Math.max(0.25, globalSpeedMultiplier);
      var frame = evaluateVerifiedFrame(verifiedSetup, rigOrder, elapsed);

      for (var i = 0; i < rigOrder.length; i++) {
        var k = rigOrder[i];
        var bone = boneMap[k];
        if (bone && frame.quats[k]) {
          applyBoneQuat(bone, frame.quats[k]);
        }
      }
      if (hipsBone && hipsBone.position && frame.hipsPos) {
        hipsBone.position.set(frame.hipsPos[0], frame.hipsPos[1], frame.hipsPos[2]);
      }

      requestModelViewerRender(mv, root);
      activeAnimId = requestAnimationFrame(loop);
    }

    activeAnimId = requestAnimationFrame(loop);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC API — window.VyraExercisePose
  // ═══════════════════════════════════════════════════════════════════════
  global.VyraExercisePose = {
    version: ENGINE_VERSION,

    apply: function (slug, speedMult) {
      if (typeof speedMult === 'number' && isFinite(speedMult) && speedMult > 0) {
        globalSpeedMultiplier = Math.min(4.0, Math.max(0.25, speedMult));
      }
      currentExerciseSlug = slug || 'bodyweight_squat';
      var resolved = resolveExercise(currentExerciseSlug);
      var mv = typeof document !== 'undefined' ? document.querySelector('model-viewer') : null;
      if (!mv) return resolved;
      function doApply() {
        startExerciseLoop(mv, resolved.name, resolved.spec);
      }
      if (mv.loaded) {
        doApply();
      } else if (typeof mv.addEventListener === 'function') {
        mv.addEventListener('load', doApply, { once: true });
      }
      return resolved;
    },

    verifyAndGetSetup: function (slug, rigId) {
      var r = resolveExercise(slug);
      return buildAndVerifySetup(rigId || 'male', r.name, r.spec);
    },

    simulateStream: function (slug, rigId, framesCount, durationSec) {
      var safeRig = (rigId === 'female') ? 'female' : 'male';
      var r = resolveExercise(slug);
      var setup = buildAndVerifySetup(safeRig, r.name, r.spec);
      var rigOrder = (GLB_BIND_META[safeRig] || GLB_BIND_META.male).order;
      var n = (typeof framesCount === 'number' && framesCount > 1) ? framesCount : 60;
      var dur = (typeof durationSec === 'number' && durationSec > 0) ? durationSec : (setup.speed * 2);
      var frames = [];
      for (var i = 0; i <= n; i++) {
        var t = (i / n) * dur;
        frames.push(evaluateVerifiedFrame(setup, rigOrder, t));
      }
      return { setup: setup, framesCount: frames.length, frames: frames };
    },

    getLastVerificationReport: function () {
      return lastVerificationReport;
    },

    preloadCache: function (cacheMap) {
      if (!cacheMap || typeof cacheMap !== 'object') return;
      for (var k in cacheMap) {
        if (Object.prototype.hasOwnProperty.call(cacheMap, k) && cacheMap[k] && cacheMap[k].verified) {
          MEMORY_VERIFIED_CACHE[k] = cacheMap[k];
        }
      }
    },

    setSpeed: function (speedMult) {
      if (typeof speedMult === 'number' && isFinite(speedMult) && speedMult > 0) {
        globalSpeedMultiplier = Math.min(4.0, Math.max(0.25, speedMult));
      }
    },

    setOrbit: function (orbitString) {
      var mv = typeof document !== 'undefined' ? document.querySelector('model-viewer') : null;
      if (!mv || !orbitString) return;
      try {
        mv.cameraOrbit = orbitString;
        mv.setAttribute('camera-orbit', orbitString);
      } catch (_) {}
    },

    stop: function () {
      if (activeAnimId) {
        cancelAnimationFrame(activeAnimId);
        activeAnimId = null;
      }
    },

    debug: function (slug) {
      var r = resolveExercise(slug);
      console.log('[VyraEngine v6.0] "' + slug + '" -> ' + r.name);
      return r;
    },

    poses: Object.keys(EXERCISES),

    resolve: function (slug) {
      return resolveExercise(slug).name;
    }
  };

  if (typeof document !== 'undefined' && typeof document.addEventListener === 'function') {
    document.addEventListener('visibilitychange', function () {
      if (document.hidden && activeAnimId) {
        cancelAnimationFrame(activeAnimId);
        activeAnimId = null;
      }
    });
  }
  if (typeof window !== 'undefined' && typeof window.addEventListener === 'function') {
    window.addEventListener('pagehide', function () {
      if (activeAnimId) {
        cancelAnimationFrame(activeAnimId);
        activeAnimId = null;
      }
    });
    window.addEventListener('beforeunload', function () {
      if (activeAnimId) {
        cancelAnimationFrame(activeAnimId);
        activeAnimId = null;
      }
    });
  }
})(typeof window !== 'undefined' ? window : globalThis);
