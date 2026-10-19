import { Link } from "react-router-dom";
import { AlertTriangle, ShieldCheck } from "lucide-react";
import QualityBadge from "./QualityBadge";
import { qualityCopy } from "@/utils/qualityCopy";
import type { SessionQuality } from "@/types";

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

  return (
    <section className="rounded-lg border p-4 space-y-3" aria-label="Interview quality">
      <header className="flex items-center gap-2">
        {blockers.length > 0 ? (
          <AlertTriangle className="h-4 w-4 text-red-600" aria-hidden />
        ) : (
          <ShieldCheck className="h-4 w-4 text-green-600" aria-hidden />
        )}
        <h2 className="text-sm font-semibold">Interview quality</h2>
        <QualityBadge verdict={quality.verdict} />
        <span className="ml-auto text-xs text-muted-foreground">score {quality.score}/100</span>
      </header>

      <p className="text-sm text-muted-foreground">{copy.detail}</p>

      {quality.findings.length === 0 ? (
        <p className="text-sm text-green-700">No contract violations detected in this session.</p>
      ) : (
        <ul className="space-y-2">
          {[...blockers, ...warnings].map((finding) => (
            <li key={finding.code} className="text-sm">
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
