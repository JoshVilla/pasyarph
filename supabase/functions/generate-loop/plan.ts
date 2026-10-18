// Target lengths and how a generated loop is judged.

export type Duration = 'quick' | 'half' | 'full';

/** Target loop length in meters. Tune here. */
export const TARGET_LENGTH_M: Record<Duration, number> = {
  quick: 50_000,
  half: 120_000,
  full: 220_000,
};

/** A loop within this share of the target is close enough. */
export const LENGTH_TOLERANCE = 0.25;

/** "Avoid highways" accepts a loop with less expressway than this. */
export const MAX_MOTORWAY_M = 500;

/** "Avoid unpaved" accepts a loop with less known-unpaved road than this. */
export const MAX_UNPAVED_M = 2_000;

export interface Preferences {
  targetM: number;
  avoidHighways: boolean;
  avoidUnpaved: boolean;
}

export interface Candidate {
  distance_m: number;
  motorway_m: number;
  unpaved_m: number;
}

export function isCloseEnough(actualM: number, targetM: number) {
  return Math.abs(actualM - targetM) <= targetM * LENGTH_TOLERANCE;
}

/** Requested round-trip distance for a retry, from how far off the last
 * one came out. Clamped so one odd route can't send the next to extremes. */
export function correctedDistance(
  requestedM: number,
  actualM: number,
  targetM: number,
) {
  const next = requestedM * (targetM / actualM);
  return Math.min(targetM * 2, Math.max(targetM * 0.3, next));
}

export function meetsPreferences(c: Candidate, p: Preferences) {
  return isCloseEnough(c.distance_m, p.targetM) &&
    (!p.avoidHighways || c.motorway_m < MAX_MOTORWAY_M) &&
    (!p.avoidUnpaved || c.unpaved_m < MAX_UNPAVED_M);
}

/** Lower is better: share off target, plus heavy penalties for the roads
 * the rider asked to avoid. */
export function penalty(c: Candidate, p: Preferences) {
  let score = Math.abs(c.distance_m - p.targetM) / p.targetM;
  if (p.avoidHighways) score += (c.motorway_m / 1000) * 0.5;
  if (p.avoidUnpaved) score += (c.unpaved_m / 1000) * 0.1;
  return score;
}

/** Why the chosen loop doesn't fully match, for the rider. */
export function warningsFor(c: Candidate, p: Preferences): string[] {
  const km = (m: number) => Math.max(1, Math.round(m / 1000));
  const warnings: string[] = [];
  if (p.avoidHighways && c.motorway_m >= MAX_MOTORWAY_M) {
    warnings.push(
      `This loop uses an expressway for about ${km(c.motorway_m)} km.`,
    );
  }
  if (p.avoidUnpaved && c.unpaved_m >= MAX_UNPAVED_M) {
    warnings.push(`About ${km(c.unpaved_m)} km of this loop is unpaved.`);
  }
  return warnings;
}
