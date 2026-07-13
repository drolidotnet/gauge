import React from "react";
import Svg, { Polyline } from "react-native-svg";

interface Props {
  data: number[];
  color: string;
  width: number;
  height?: number;
}

export default function Sparkline({ data, color, width, height = 60 }: Props) {
  if (data.length < 2) return null;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = Math.max(1, max - min);
  const points = data
    .map((y, i) => {
      const px = (width * i) / (data.length - 1);
      const py = height - ((y - min) / range) * height;
      return `${px},${py}`;
    })
    .join(" ");

  return (
    <Svg width={width} height={height}>
      <Polyline points={points} stroke={color} strokeWidth={2} fill="none" />
    </Svg>
  );
}
