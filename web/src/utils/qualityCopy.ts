import type { QualityVerdict } from "@/types";

interface QualityCopy {
  label: string;
  tone: "neutral" | "positive" | "warning" | "danger";
  detail: string;
  candidateMessage: string;
}

const COPY: Record<QualityVerdict, QualityCopy> = {
  trustworthy: {
    label: "Session valid",
    tone: "positive",
    detail: "Every configured skill was covered and the interview followed the assessment contract.",
    candidateMessage:
      "Thank you. The interview has been recorded and the hiring team will review your results.",
  },
  review_required: {
    label: "Needs review",
    tone: "warning",
    detail: "The interview completed but part of it needs a human check before this result is used.",
    candidateMessage:
      "Thank you. The interview has been recorded; a member of the hiring team will review it before any decision is made.",
  },
  invalid: {
    label: "Not reliable",
    tone: "danger",
    detail: "The interview did not follow the assessment contract — treat this result as incomplete.",
    candidateMessage:
      "Thank you for your time. Part of this interview could not be completed as intended, so a human will review it — no automated result will be used.",
  },
};

const UNKNOWN: QualityCopy = {
  label: "Quality unknown",
  tone: "neutral",
  detail: "Quality has not been evaluated for this session yet.",
  candidateMessage:
    "Thank you. The interview has been recorded and the hiring team will review your results.",
};

export function qualityCopy(verdict?: QualityVerdict | null): QualityCopy {
  if (!verdict) return UNKNOWN;
  return COPY[verdict] ?? UNKNOWN;
}
