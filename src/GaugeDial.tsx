import React from "react";
import { View, Text, StyleSheet } from "react-native";
import Svg, { Path } from "react-native-svg";
import { scoreColor } from "./api";

interface Props {
  score: number;
  rating: string;
  size?: number;
}

function polarToCartesian(cx: number, cy: number, r: number, angleDeg: number) {
  const rad = (angleDeg * Math.PI) / 180;
  return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
}

// Arc from startAngle to endAngle (degrees, 180 = left, 360 = right).
function arcPath(cx: number, cy: number, r: number, startAngle: number, endAngle: number) {
  const start = polarToCartesian(cx, cy, r, startAngle);
  const end = polarToCartesian(cx, cy, r, endAngle);
  const largeArc = endAngle - startAngle > 180 ? 1 : 0;
  return `M ${start.x} ${start.y} A ${r} ${r} 0 ${largeArc} 1 ${end.x} ${end.y}`;
}

export default function GaugeDial({ score, rating, size = 260 }: Props) {
  const strokeWidth = 18;
  const cx = size / 2;
  const cy = size / 2;
  const r = size / 2 - strokeWidth;
  const height = cy + strokeWidth;
  const color = scoreColor(score);
  const clamped = Math.max(0, Math.min(score, 100));
  const endAngle = 180 + (clamped / 100) * 180;

  return (
    <View style={{ width: size, height, alignItems: "center" }}>
      <Svg width={size} height={height}>
        <Path
          d={arcPath(cx, cy, r, 180, 360)}
          stroke="#2a2a2e"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          fill="none"
        />
        {clamped > 0 && (
          <Path
            d={arcPath(cx, cy, r, 180, endAngle)}
            stroke={color}
            strokeWidth={strokeWidth}
            strokeLinecap="round"
            fill="none"
          />
        )}
      </Svg>
      <View style={[styles.center, { top: cy - 56 }]}>
        <Text style={[styles.score, { color }]}>{Math.round(score)}</Text>
        <Text style={styles.rating}>{rating}</Text>
      </View>
      <Text style={[styles.bound, { left: strokeWidth / 2, top: cy + 8 }]}>0</Text>
      <Text style={[styles.bound, { right: strokeWidth / 2 - 6, top: cy + 8 }]}>100</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  center: {
    position: "absolute",
    alignItems: "center",
  },
  score: {
    fontSize: 56,
    fontWeight: "700",
    fontVariant: ["tabular-nums"],
  },
  rating: {
    fontSize: 16,
    color: "#b0b0b8",
    textTransform: "capitalize",
  },
  bound: {
    position: "absolute",
    color: "#606068",
    fontSize: 12,
  },
});
