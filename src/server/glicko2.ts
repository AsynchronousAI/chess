// Based on the Glicko-2 paper (Mark E. Glickman) algorithm.
// Defaults follow common choices: rating scale 1500, q = ln(10)/400, conversion factor = 173.7178.

export type PlayerRating = {
  elo: number; // e.g. 1500
  rd: number; // rating deviation, e.g. 200
  vol: number; // volatility, e.g. 0.06
};

export type OpponentRating = {
  elo: number; // opponent rating
  rd: number; // opponent rating deviation
  score: number; // 1 = win, 0.5 = draw, 0 = loss
};

const TAU_DEFAULT = 0.5;
const EPSILON = 1e-6;
const CONVERSION = 173.7178; // 1/q where q = ln(10)/400

function toGlicko2Rating(r: number): number {
  return (r - 1500) / CONVERSION;
}
function fromGlicko2Rating(mu: number): number {
  return mu * CONVERSION + 1500;
}
function toGlicko2RD(rd: number): number {
  return rd / CONVERSION;
}
function fromGlicko2RD(phi: number): number {
  return phi * CONVERSION;
}

function g(phi: number): number {
  const pi = math.pi;
  return 1 / math.sqrt(1 + (3 * phi * phi) / (pi * pi));
}

function E(mu: number, mu_j: number, phi_j: number): number {
  return 1 / (1 + math.exp(-g(phi_j) * (mu - mu_j)));
}

/**
 * Update single player's rating given a set of opponent results.
 * If opponents array is empty, only RD increases (period of inactivity).
 *
 * @param player current player
 * @param opponents array of opponent results for the rating period
 * @param tau system constant (typical 0.3-1.2). Default 0.5.
 * @returns new Player { rating, rd, vol }
 */
export function computeNewRating(
  player: PlayerRating,
  opponents: OpponentRating[],
  tau = TAU_DEFAULT,
): PlayerRating {
  const mu = toGlicko2Rating(player.elo);
  const phi = toGlicko2RD(player.rd);
  const sigma = player.vol;

  if (opponents.size() === 0) {
    // No games this period: only increase RD
    const phiPrime = math.sqrt(phi * phi + sigma * sigma);
    return {
      elo: player.elo,
      rd: fromGlicko2RD(phiPrime),
      vol: sigma,
    };
  }

  // Step 2: compute v (variance)
  let vInv = 0;
  let deltaSum = 0;
  for (const opp of opponents) {
    const mu_j = toGlicko2Rating(opp.elo);
    const phi_j = toGlicko2RD(opp.rd);
    const gPhi = g(phi_j);
    const EVal = E(mu, mu_j, phi_j);
    vInv += gPhi * gPhi * EVal * (1 - EVal);
    deltaSum += gPhi * (opp.score - EVal);
  }
  const v = 1 / vInv;

  // Step 3: compute delta
  const delta = v * deltaSum;

  // Step 4: find new volatility sigmaPrime by solving f(x)=0 for x = ln(sigma'^2)
  const a = math.log(sigma * sigma);
  const tau2 = tau * tau;

  function f(x: number): number {
    const ex = math.exp(x);
    const num = ex * (delta * delta - phi * phi - v - ex);
    const den = 2 * math.pow(phi * phi + v + ex, 2);
    return num / den - (x - a) / tau2;
  }

  // Initial bracket
  let A = a;
  let B: number;
  if (delta * delta > phi * phi + v) {
    B = math.log(delta * delta - phi * phi - v);
  } else {
    let k = 1;
    while (f(a - k * tau) < 0) {
      k += 1;
      // safety cap
      if (k > 100) break;
    }
    B = a - k * tau;
  }

  let fA = f(A);
  let fB = f(B);

  // Now use the iterative algorithm (Illinois/Brent-like secant)
  let iter = 0;
  while (math.abs(B - A) > EPSILON && iter < 100) {
    // Secant step
    const C = A + ((A - B) * fA) / (fB - fA);
    const fC = f(C);

    // Decide which interval to keep
    if (fC * fB < 0) {
      A = B;
      fA = fB;
      B = C;
      fB = fC;
    } else {
      fA = fA / 2;
      B = C;
      fB = fC;
    }
    iter += 1;
  }

  const xPrime = B;
  const sigmaPrime = math.exp(xPrime / 2);

  // Step 5: update phi*
  const phiStar = math.sqrt(phi * phi + sigmaPrime * sigmaPrime);

  // Step 6: update phi' and mu'
  const phiPrime = 1 / math.sqrt(1 / (phiStar * phiStar) + 1 / v);
  const muPrime = mu + phiPrime * phiPrime * deltaSum;

  // Convert back
  return {
    elo: fromGlicko2Rating(muPrime),
    rd: fromGlicko2RD(phiPrime),
    vol: sigmaPrime,
  };
}
