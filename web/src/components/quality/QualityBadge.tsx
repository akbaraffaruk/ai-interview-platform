import { QUALITY_TONE_CLASSES } from "@/utils/constants";
import { qualityCopy } from "@/utils/qualityCopy";
import { cn } from "@/lib/utils";
import type { QualityVerdict } from "@/types";

interface Props {
  verdict?: QualityVerdict | null;
  className?: string;
}

export default function QualityBadge({ verdict, className }: Props) {
  if (!verdict) return null;

  const copy = qualityCopy(verdict);

  return (
    <span
      title={copy.detail}
      className={cn(
        "inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium",
        QUALITY_TONE_CLASSES[copy.tone],
        className
      )}
    >
      {copy.label}
    </span>
  );
}
