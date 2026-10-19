import { describe, expect, it } from "vitest";
import {
  COVERAGE_STATE_COLOR,
  COVERAGE_STATE_LABELS,
  COVERAGE_STATE_WIDTH,
  LEVEL_LABELS,
  parseLevel,
} from "./constants";

describe("coverage state mapping", () => {
  const states = ["not_yet", "initiated", "partial", "covered"];

  it("labels every state", () => {
    expect(Object.keys(COVERAGE_STATE_LABELS).sort()).toEqual([...states].sort());
  });

  it("keeps progress monotonic so the monitor bar never moves backwards as an interview advances", () => {
    const widths = states.map((state) => COVERAGE_STATE_WIDTH[state]);
    expect(widths).toEqual([...widths].sort((a, b) => a - b));
    expect(COVERAGE_STATE_WIDTH.covered).toBe(100);
  });

  it("gives every state a colour class", () => {
    states.forEach((state) => expect(COVERAGE_STATE_COLOR[state]).toMatch(/^bg-/));
  });
});

describe("level helpers", () => {
  it("maps 1-5 to L labels", () => {
    expect(LEVEL_LABELS[3]).toBe("L3");
  });

  it("parses labels and passes numbers through, defaulting to 1", () => {
    expect(parseLevel("L4")).toBe(4);
    expect(parseLevel(2)).toBe(2);
    expect(parseLevel("nonsense")).toBe(1);
  });
});
