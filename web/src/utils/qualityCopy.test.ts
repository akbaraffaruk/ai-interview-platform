import { describe, expect, it } from "vitest";
import { qualityCopy } from "./qualityCopy";

describe("qualityCopy", () => {
  it("labels every verdict", () => {
    expect(qualityCopy("trustworthy").label).toBe("Session valid");
    expect(qualityCopy("review_required").label).toBe("Needs review");
    expect(qualityCopy("invalid").label).toBe("Not reliable");
  });

  it("never tells a candidate their interview went well when it did not", () => {
    expect(qualityCopy("invalid").candidateMessage).toMatch(/review/i);
    expect(qualityCopy("invalid").candidateMessage).not.toMatch(/recorded successfully/i);
  });

  it("falls back safely for an unknown verdict", () => {
    expect(qualityCopy(undefined).label).toBe("Quality unknown");
  });
});
