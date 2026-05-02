import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import { env } from '../config/env.js';

export function signAccessToken(payload) {
  return jwt.sign(payload, env.jwtAccessSecret, { expiresIn: env.jwtAccessTtl });
}

// Phase 4.16 follow-up — refresh tokens carry a `jti` claim that maps
// to a RefreshToken DB row. The DB row is the source of truth for
// revocation; the JWT signature is the first-pass auth. The `jti`
// flows through a freshly-generated UUID per token so each row is
// uniquely addressable.
export function signRefreshToken(payload, { jti } = {}) {
  const finalJti = jti ?? crypto.randomUUID();
  return {
    token: jwt.sign({ ...payload, jti: finalJti }, env.jwtRefreshSecret, { expiresIn: env.jwtRefreshTtl }),
    jti: finalJti,
  };
}

export function verifyAccessToken(token) {
  return jwt.verify(token, env.jwtAccessSecret);
}

export function verifyRefreshToken(token) {
  return jwt.verify(token, env.jwtRefreshSecret);
}

// Compute the absolute expiry the JWT will encode, so we can mirror
// it on the DB row. jsonwebtoken's `expiresIn` accepts seconds-or-string;
// we keep the parsing in one place by signing once and decoding the
// `exp` claim back out.
export function refreshTokenExpiry(token) {
  const decoded = jwt.decode(token);
  if (!decoded || typeof decoded !== 'object' || !decoded.exp) {
    throw new Error('refresh token has no exp claim');
  }
  return new Date(Number(decoded.exp) * 1000);
}

// Phase 4.16 follow-up — short-lived challenge token for the 2FA login
// flow. Signed with the same secret as access tokens but stamped with
// `type: '2fa_challenge'` so it can't be used as an access token.
// 5-minute TTL — long enough to fish out the authenticator app, too
// short to be useful if intercepted.
export function signChallengeToken(payload) {
  return jwt.sign({ ...payload, type: '2fa_challenge' }, env.jwtAccessSecret, { expiresIn: '5m' });
}

export function verifyChallengeToken(token) {
  const payload = jwt.verify(token, env.jwtAccessSecret);
  if (payload?.type !== '2fa_challenge') {
    throw new Error('not a 2fa challenge token');
  }
  return payload;
}
