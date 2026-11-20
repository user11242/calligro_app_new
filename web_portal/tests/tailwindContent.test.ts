import { readdirSync, readFileSync, statSync } from "fs";
import { join } from "path";
import { describe, expect, it } from "vitest";

/**
 * Tailwind generates a class only if it finds it in a file it scans. When the UI moved
 * from src/components to src/shared + src/features, the scan list was not updated and
 * every class used only there vanished (the navbar lost its z-index and position, etc.).
 */
const config = readFileSync("tailwind.config.ts", "utf8");
const scanned = [...config.matchAll(/"\.\/src\/([^/*"]+)\/\*\*\//g)].map((m) => m[1]);

function hasUiFiles(dir: string): boolean {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) {
      if (hasUiFiles(p)) return true;
    } else if (/\.(tsx|jsx)$/.test(name)) {
      return true;
    }
  }
  return false;
}

describe("tailwind content", () => {
  it("scans every src folder that holds components", () => {
    const uiFolders = readdirSync("src").filter((d) => statSync(join("src", d)).isDirectory() && hasUiFiles(join("src", d)));
    expect(uiFolders.length).toBeGreaterThan(0);
    for (const folder of uiFolders) expect(scanned, `src/${folder} is not scanned by Tailwind`).toContain(folder);
  });

  it("the navbar's own classes are in a scanned folder", () => {
    expect(scanned).toContain("shared");
  });
});
