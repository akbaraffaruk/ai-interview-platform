import { Link } from "react-router-dom";
import { AlertTriangle, ShieldCheck, type LucideIcon } from "lucide-react";
import QualityBadge from "./QualityBadge";
import { qualityCopy } from "@/utils/qualityCopy";
import type { QualityVerdict, SessionQuality } from "@/types";

const VERDICT_ICONS: Record<QualityVerdict, { Icon: LucideIcon; className: string }> = {
  invalid: { Icon: AlertTriangle, className: "text-red-600" },
  review_required: { Icon: AlertTriangle, className: "text-amber-600" },
  trustworthy: { Icon: ShieldCheck, className: "text-green-600" },
};

interface Props {
  quality: SessionQuality | null;
  assessmentId: string;
  sessionId: string;
}

export default function QualityFindingsPanel({ quality, assessmentId, sessionId }: Props) {
  if (!quality) return null;

  const copy = qualityCopy(quality.verdict);
  const blockers = quality.findings.filter((f) => f.severity === "blocker");
  const warnings = quality.findings.filter((f) => f.severity === "warning");
  const { Icon: VerdictIcon, className: verdictIconClass } = VERDICT_ICONS[quality.verdict];

  return (
    <section className="rounded-lg border p-4 space-y-3" aria-label="Interview quality">
      <header className="flex items-center gap-2">
        <VerdictIcon className={`h-4 w-4 ${verdictIconClass}`} aria-hidden />
        <h2 className="text-sm font-semibold">Interview quality</h2>
        <QualityBadge verdict={quality.verdict} />
        <span className="ml-auto text-xs text-muted-foreground">score {quality.score}/100</span>
      </header>

      <p className="text-sm text-muted-foreground">{copy.detail}</p>

      {quality.findings.length === 0 ? (
        <p className="text-sm text-green-700">No contract violations detected in this session.</p>
      ) : (
        <ul className="space-y-2">
          {[...blockers, ...warnings].map((finding, index) => (
            <li key={`${finding.code}-${index}`} className="text-sm">
              <span className={finding.severity === "blocker" ? "font-medium text-red-700" : "font-medium text-amber-700"}>
                {finding.severity === "blocker" ? "Blocker" : "Warning"}
              </span>{" "}
              {finding.message}
              {finding.turn_numbers.length > 0 && (
                <span className="ml-1 text-muted-foreground">
                  (
                  {finding.turn_numbers.map((turn, index) => (
                    <span key={turn}>
                      {index > 0 && ", "}
                      <Link
                        className="underline"
                        to={`/assessments/${assessmentId}/sessions/${sessionId}/transcript#turn-${turn}`}
                      >
                        turn {turn}
                      </Link>
                    </span>
                  ))}
                  )
                </span>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
