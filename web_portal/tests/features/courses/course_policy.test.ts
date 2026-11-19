/** Course rules the catalog, the teacher page and the home page share (one copy). */
import { describe, it, expect } from "vitest";
import {
  isVisibleInCatalog,
  matchesSearch,
  matchesCategory,
  newestFirst,
  teacherStudentCount,
} from "../../../src/features/courses/domain/coursePolicy";

const NOW = new Date("2026-12-01T12:00:00Z");
const ts = (iso: string) => ({ toDate: () => new Date(iso), seconds: Date.parse(iso) / 1000 });

describe("isVisibleInCatalog: started courses are hidden unless you are in them", () => {
  it("not started yet → visible", () => {
    expect(isVisibleInCatalog({ startDate: ts("2026-12-05T00:00:00Z") }, null, NOW)).toBe(true);
  });
  it("started, not enrolled → hidden", () => {
    expect(isVisibleInCatalog({ startDate: ts("2026-11-20T00:00:00Z"), enrolledStudents: ["x"] }, "s1", NOW)).toBe(false);
    expect(isVisibleInCatalog({ startDate: ts("2026-11-20T00:00:00Z") }, null, NOW)).toBe(false);
  });
  it("started, enrolled → visible", () => {
    expect(isVisibleInCatalog({ startDate: ts("2026-11-20T00:00:00Z"), enrolledStudents: ["s1"] }, "s1", NOW)).toBe(true);
  });
  it("no start date or an unreadable one → visible (as before)", () => {
    expect(isVisibleInCatalog({}, null, NOW)).toBe(true);
    expect(isVisibleInCatalog({ startDate: "not a date" }, null, NOW)).toBe(true);
    expect(isVisibleInCatalog({ startDate: "2026-11-20T00:00:00Z" }, null, NOW)).toBe(false);
  });
});

describe("search and category (the catalog)", () => {
  const c = { courseName: "Thuluth Basics", teacherName: "Ustadh Ali", selectedCategory: "Beginner", courseDescription: "Learn alif", enrolledStudents: ["s1"] };
  it("search: name, title, teacher, level, description; case-insensitive; empty matches all", () => {
    for (const term of ["thuluth", "ALI", "beginner", "alif", ""]) expect(matchesSearch(c, term), term).toBe(true);
    expect(matchesSearch({ courseTitle: "Naskh" }, "naskh")).toBe(true);
    expect(matchesSearch(c, "diwani")).toBe(false);
  });
  it("category: All, My courses (enrolled only), or the level", () => {
    expect(matchesCategory(c, "All", null)).toBe(true);
    expect(matchesCategory(c, "MyCourses", "s1")).toBe(true);
    expect(matchesCategory(c, "MyCourses", "s2")).toBe(false);
    expect(matchesCategory(c, "Beginner", null)).toBe(true);
    expect(matchesCategory(c, "Advanced", null)).toBe(false);
  });
});

describe("newestFirst and teacherStudentCount", () => {
  it("newest created first; missing dates last", () => {
    const list = [{ id: "a", createdAt: ts("2026-01-01T00:00:00Z") }, { id: "b" }, { id: "c", createdAt: ts("2026-06-01T00:00:00Z") }];
    expect(newestFirst(list).map((x) => x.id)).toEqual(["c", "a", "b"]);
  });
  it("students of a teacher: everyone enrolled in their courses (+ the old studentsEnrolled number), as the home page counted", () => {
    expect(teacherStudentCount([{ enrolledStudents: ["a", "b"] }, { enrolledStudents: ["c"], studentsEnrolled: 2 }, {}])).toBe(5);
  });
});
