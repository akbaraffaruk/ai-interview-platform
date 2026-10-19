import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import QualityBadge from "./QualityBadge";

describe("QualityBadge", () => {
  it("renders the verdict label", () => {
    render(<QualityBadge verdict="invalid" />);
    expect(screen.getByText("Not reliable")).toBeInTheDocument();
  });

  it("renders nothing when the verdict is unknown", () => {
    const { container } = render(<QualityBadge verdict={undefined} />);
    expect(container).toBeEmptyDOMElement();
  });
});
