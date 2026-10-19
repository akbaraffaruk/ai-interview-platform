import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const getTranscript = vi.fn();
const getSession = vi.fn();

vi.mock("@/services/sessions", () => ({
  sessionsApi: {
    getTranscript: (...args: unknown[]) => getTranscript(...args),
    get: (...args: unknown[]) => getSession(...args),
  },
}));

vi.mock("react-router-dom", async () => {
  const actual = await vi.importActual<Record<string, unknown>>("react-router-dom");
  return { ...actual, useParams: () => ({ id: "1", sessionId: "9" }) };
});

import { MemoryRouter } from "react-router-dom";

import TranscriptPage from "./TranscriptPage";

describe("TranscriptPage", () => {
  beforeEach(() => {
    getTranscript.mockReset();
    getSession.mockReset();
    getTranscript.mockResolvedValue({
      data: {
        turns: [
          {
            id: 1,
            turn_number: 2,
            speaker: "candidate",
            text: "We built a dashboard.",
            created_at: "2026-01-01T00:00:00Z",
          },
        ],
        total: 1,
      },
    });
    getSession.mockResolvedValue({ data: { session: { candidate_name: "Budi Santoso" } } });
  });

  it("gives each turn a stable anchor id so a quality finding can link to its evidence", async () => {
    render(
      <MemoryRouter>
        <TranscriptPage />
      </MemoryRouter>
    );

    expect(await screen.findByText("We built a dashboard.")).toBeInTheDocument();
    expect(document.getElementById("turn-2")).not.toBeNull();
  });
});
