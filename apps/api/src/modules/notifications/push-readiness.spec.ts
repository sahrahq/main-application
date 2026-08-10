import { PUSH_PLATFORMS, pushReadiness, pushReadinessBanner } from './push-readiness';

/**
 * The one answer three things read: the startup banner, `/health`, and the send
 * path. Two sources for "can we reach an iPhone?" would eventually disagree,
 * and the health check would be the one that said yes.
 */
describe('pushReadiness', () => {
  it('nothing configured — every platform is unreachable', () => {
    const r = pushReadiness(null, {} as NodeJS.ProcessEnv);
    expect(r.configured).toBe(false);
    expect(r.unreachable.sort()).toEqual([...PUSH_PLATFORMS].sort());
  });

  it('Android only — the state shipped on 2026-08-10', () => {
    const r = pushReadiness('sahra-4881d', {} as NodeJS.ProcessEnv);
    expect(r.configured).toBe(true);
    expect(r.platforms.find((p) => p.platform === 'android')!.deliverable).toBe(true);
    expect(r.platforms.find((p) => p.platform === 'ios')!.deliverable).toBe(false);
    expect(r.unreachable).toContain('ios');
  });

  it('iOS is OPT-IN, and any value other than "1" is off', () => {
    // A default of "configured" would mean the day somebody adds an iOS build
    // with no APNs key, everything reports healthy and every iPhone is silent.
    for (const value of [undefined, '', '0', 'true', 'yes', 'TRUE']) {
      const r = pushReadiness('p', { FIREBASE_IOS_CONFIGURED: value } as NodeJS.ProcessEnv);
      expect(r.platforms.find((p) => p.platform === 'ios')!.deliverable).toBe(false);
    }
    const on = pushReadiness('p', { FIREBASE_IOS_CONFIGURED: '1' } as NodeJS.ProcessEnv);
    expect(on.platforms.find((p) => p.platform === 'ios')!.deliverable).toBe(true);
  });

  it('every platform `POST /devices` accepts has a readiness answer', () => {
    // Enumerated from the catalogue, so a platform added to the DTO without
    // being considered here fails rather than defaulting to deliverable.
    const r = pushReadiness('p', {} as NodeJS.ProcessEnv);
    expect(r.platforms.map((p) => p.platform).sort()).toEqual([...PUSH_PLATFORMS].sort());
  });

  it('an unreachable platform always says WHY', () => {
    // The reason ends up in `notifications.delivery_error` and in `/health`.
    // "false" with no explanation is a dead end for whoever has to fix it.
    const r = pushReadiness('p', {} as NodeJS.ProcessEnv);
    for (const p of r.platforms.filter((x) => !x.deliverable)) {
      expect(p.reason.length).toBeGreaterThan(20);
    }
    for (const p of r.platforms.filter((x) => x.deliverable)) {
      expect(p.reason).toBe('');
    }
  });
});

describe('the startup banner', () => {
  it('says push is off when nothing is configured', () => {
    const lines = pushReadinessBanner(pushReadiness(null, {} as NodeJS.ProcessEnv)).join('\n');
    expect(lines).toMatch(/NOT CONFIGURED/);
  });

  it('NAMES iOS when Android works and iOS does not', () => {
    // The failure this whole design exists to prevent is silence. A banner that
    // said "push configured" would be the silence.
    const lines = pushReadinessBanner(
      pushReadiness('sahra-4881d', {} as NodeJS.ProcessEnv),
    ).join('\n');
    expect(lines).toMatch(/IOS CANNOT BE REACHED/);
    expect(lines).toMatch(/APNs/);
    expect(lines).toMatch(/Do not read that as "push works"/);
  });

  it('and does NOT shout when everything is deliverable', () => {
    // Guards the guard: a banner that shouted unconditionally would be ignored
    // unconditionally, and then it would be shouting on the day it mattered.
    const lines = pushReadinessBanner(
      pushReadiness('p', { FIREBASE_IOS_CONFIGURED: '1' } as NodeJS.ProcessEnv),
    ).join('\n');
    expect(lines).not.toMatch(/CANNOT BE REACHED/);
    expect(lines).toMatch(/all platforms deliverable/);
  });

  it('web alone never triggers the alarm', () => {
    // It is out of scope (doc 02), not broken. Treating it as a degradation
    // would make the alarm permanently on, which is the same as off.
    const lines = pushReadinessBanner(
      pushReadiness('p', { FIREBASE_IOS_CONFIGURED: '1' } as NodeJS.ProcessEnv),
    ).join('\n');
    expect(lines).not.toMatch(/WEB CANNOT/);
  });
});
