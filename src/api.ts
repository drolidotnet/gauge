const API_URL = "https://production.dataviz.cnn.io/index/fearandgreed/graphdata";

// CNN's API bot-blocks (HTTP 418) unless the request looks like a real browser.
const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
  Accept: "application/json",
  Referer: "https://edition.cnn.com/",
};

export interface FearGreed {
  score: number;
  rating: string;
  timestamp: string;
  previous_close: number;
  previous_1_week: number;
  previous_1_month: number;
  previous_1_year: number;
}

export interface GraphData {
  fear_and_greed: FearGreed;
  fear_and_greed_historical: {
    data: { x: number; y: number; rating: string }[];
  };
}

export async function fetchGauge(): Promise<GraphData> {
  const res = await fetch(API_URL, { headers: HEADERS });
  if (!res.ok) {
    throw new Error(`CNN API responded with ${res.status}`);
  }
  return res.json();
}

// Port of GaugeColor.scoreColor: red (fear) -> yellow (neutral) -> green (greed).
export function scoreColor(score: number): string {
  const t = Math.max(0, Math.min(score, 100)) / 100;
  const red = t < 0.5 ? 1 : 1 - (t - 0.5) * 2;
  const green = t < 0.5 ? t : 0.5 + (t - 0.5);
  const r = Math.round(255 * Math.pow(red, 0.9));
  const g = Math.round(255 * Math.pow(green, 0.9));
  return `rgb(${r}, ${g}, 0)`;
}
