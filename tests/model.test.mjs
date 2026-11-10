// Offline tests for Model.js, the panel's logic (0.5.8): categories, the accordion's open state, the
// cursor walk, the footer, the summary line after an update, and no version number in any panel text.
// Model.js is plain QML JavaScript with no exports, so it runs here in a sandbox of its own.
//
//   node tests/model.test.mjs

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const M = {};
vm.createContext(M);
vm.runInContext(readFileSync(resolve(root, "Model.js"), "utf8"), M);

let passed = 0, failed = 0;
const ok = (name) => { passed++; console.log("ok   " + name); };
const fail = (name, why) => { failed++; console.log("FAIL " + name + (why ? ": " + why : "")); };
const eq = (name, got, want) => {
  const g = JSON.stringify(got), w = JSON.stringify(want);
  g === w ? ok(name) : fail(name, "expected " + w + ", got " + g);
};
const truthy = (name, v) => (v ? ok(name) : fail(name, String(v)));

// An app as `omarcraft state` prints it.
const app = (id, name, group, o = {}) => ({
  id, name, group, installed: false, updateReady: false, new: false, source: null, kind: "aur", repo: "",
  aurVersion: "1.2.3-1", installedVersion: "", ...o,
});
const inst = (o = {}) => ({ installed: true, source: "bin", installedVersion: "1.2.3-1", ...o });
const upd = (o = {}) => ({ ...inst(), updateReady: true, aurVersion: "1.3.0-1", installedVersion: "1.2.3-1", ...o });

// This machine after the new apps arrive: 16 of 20, two updates, four new apps.
const apps = [
  app("photocraft", "PhotoCraft", "creative", upd()),
  app("vectorcraft", "VectorCraft", "creative", inst()),
  app("filmcraft", "FilmCraft", "creative", inst()),
  app("lightcraft", "LightCraft", "creative", inst()),
  app("pdfcraft", "PdfCraft", "office", inst()),
  app("effectcraft", "EffectCraft", "creative", inst()),
  app("designcraft", "DesignCraft", "creative", inst()),
  app("figcraft", "FigCraft", "creative", inst()),
  app("wordcraft", "WordCraft", "office", upd()),
  app("soundcraft", "SoundCraft", "creative", inst()),
  app("deckcraft", "DeckCraft", "office", inst()),
  app("cadcraft", "CADCraft", "3d", inst()),
  app("gridcraft", "GridCraft", "office", inst()),
  app("texturecraft", "TextureCraft", "3d", { new: true }),
  app("materialcraft", "MaterialCraft", "3d", { new: true }),
  app("craft-anything", "Craft Anything", "solo", { new: true }),
  app("solidcraft", "SolidCraft", "3d", { new: true }),
  app("memospot", "Memospot", "office", inst()),
  app("typesetter", "Typesetter", "office", inst({ kind: "repo", repo: "extra", source: "repo" })),
  app("planify", "Planify", "office", inst({ kind: "repo", repo: "extra", source: "repo" })),
];

// --- categories ---------------------------------------------------------------------------------
const cats = M.categories(apps, []);
eq("three categories, in order", cats.map((c) => c.id), ["creative", "3d", "office"]);
eq("their labels and keys", cats.map((c) => c.label + ":" + c.key), ["Creative:c", "3D Art:3", "Office:o"]);
eq("Creative holds its eight", cats[0].apps.map((a) => a.id),
  ["photocraft", "vectorcraft", "filmcraft", "lightcraft", "effectcraft", "designcraft", "figcraft", "soundcraft"]);
eq("3D Art holds CAD, Texture, Material and Solid", cats[1].apps.map((a) => a.id), ["cadcraft", "texturecraft", "materialcraft", "solidcraft"]);
eq("Office holds its seven, Memospot and Planify included", cats[2].apps.length, 7);
eq("header counts: installed of total", cats.map((c) => c.installed + " of " + c.total), ["8 of 8", "1 of 4", "7 of 7"]);
eq("the update dot", cats.map((c) => c.updates), [1, 0, 1]);
eq("New only where an unseen app is not installed", cats.map((c) => c.hasNew), [false, true, false]);
eq("what is missing, for the install key", cats[1].missing, ["texturecraft", "materialcraft", "solidcraft"]);
eq("an installed app still flagged new does not mark its category New",
  M.categories([app("cadcraft", "CADCraft", "3d", inst({ new: true }))], [])[0].hasNew, false);
eq("all closed on the first run", cats.map((c) => c.open), [false, false, false]);
eq("open as the settings say", M.categories(apps, ["3d"]).map((c) => c.open), [false, true, false]);
eq("Craft Anything is the footer, in no category", M.footerApps(apps).map((a) => a.id), ["craft-anything"]);
truthy("and not inside any category", !cats.some((c) => c.apps.some((a) => a.id === "craft-anything")));
eq("an app of an unknown group is Creative", M.categories([app("brushcraft", "BrushCraft", "suite")], [])[0].id, "creative");
eq("an app with no build and not installed is not shown", M.categories([app("x", "X", "3d", { aurVersion: "" })], []).length, 0);
eq("an empty category is left out", M.categories([app("wordcraft", "WordCraft", "office")], []).map((c) => c.id), ["office"]);

// --- the open state -------------------------------------------------------------------------------
eq("settings string parsed, unknown ids dropped", M.parseOpen("3d, office,notes,3d"), ["3d", "office"]);
eq("nothing kept: all closed", M.parseOpen(undefined), []);
eq("toggle opens", M.toggled(["creative"], "3d"), ["creative", "3d"]);
eq("toggle closes", M.toggled(["creative", "3d"], "creative"), ["3d"]);
eq("kept as a plain string", M.openString(["office", "3d"]), "office,3d");
eq("the categories with new apps open themselves", M.newCategoryIds(apps), ["3d"]);

// --- the cursor walk ------------------------------------------------------------------------------
eq("all closed: headers, then the footer", M.cursorKeys(apps, []), ["cat:creative", "cat:3d", "cat:office", "app:craft-anything"]);
const keys = M.cursorKeys(apps, ["3d"]);
eq("an open category's apps follow its header", keys,
  ["cat:creative", "cat:3d", "app:cadcraft", "app:texturecraft", "app:materialcraft", "app:solidcraft", "cat:office", "app:craft-anything"]);
eq("down from a header to the next key", M.gridMove(keys, apps, ["3d"], 1, 0, 1, true), 2);
eq("down a line of tiles within the category", M.gridMove(keys, apps, ["3d"], 2, 0, 1, true), 5);
eq("down past the category's tiles leaves it", M.gridMove(keys, apps, ["3d"], 4, 0, 1, true), 6);
eq("up from the first line goes to the header", M.gridMove(keys, apps, ["3d"], 3, 0, -1, true), 1);
eq("right steps one key", M.gridMove(keys, apps, ["3d"], 2, 1, 0, true), 3);
eq("in rows every move is one key", M.gridMove(keys, apps, ["3d"], 2, 0, 1, false), 3);
eq("never past the last key", M.gridMove(keys, apps, ["3d"], 7, 0, 1, true), 7);

// --- badges, strip, summary -------------------------------------------------------------------------
eq("badges: Update, New, nothing", [M.badgeFor(apps[0]), M.badgeFor(apps[13]), M.badgeFor(apps[1])], ["Update", "New", ""]);
eq("Update is the urgent badge", [M.badgeIsUpdate(apps[0]), M.badgeIsUpdate(apps[13])], [true, false]);
eq("the UPDATES strip names the apps", M.updateNames(apps), "PhotoCraft · WordCraft");
eq("names joined", [["A"], ["A", "B"], ["A", "B", "C"], ["A", "B", "C", "D", "E"]].map((n) => M.joinNames(n)),
  ["A", "A and B", "A, B and C", "A, B, C and 2 more"]);
const done = (o = {}) => ({ apps, job: null, lastJob: { verb: "update", ids: ["photocraft", "wordcraft"], exit: 0, endedAt: "t1", ...o } });
eq("after a successful update: one line naming them", M.summaryLine(done()), "Updated PhotoCraft and WordCraft");
eq("after Omarchy's update too", M.summaryLine(done({ verb: "system-update", ids: ["typesetter"] })), "Updated Typesetter");
eq("not once seen", M.summaryLine(done({ seen: true })), "");
eq("not after a failure", M.summaryLine(done({ exit: 1 })), "");
eq("not after an install or a removal", [M.summaryLine(done({ verb: "install" })), M.summaryLine(done({ verb: "remove" }))], ["", ""]);
eq("not while a job runs", M.summaryLine({ ...done(), job: { verb: "update", ids: [] } }), "");
eq("not without a last job", M.summaryLine({ apps, job: null, lastJob: null }), "");

// --- no version numbers anywhere in the panel (the author's rule, 0.5.8) ------------------------------
const craft = { apps, job: null, lastJob: null, counts: { installed: 16, updates: 2 }, offline: false, catalogAgeSeconds: 60 };
const texts = [];
for (const a of apps) {
  texts.push(M.subtext(a, craft), M.tileTip(a, craft), M.actionTip(a), M.badgeFor(a));
}
for (const kind of ["install", "update", "system-update", "remove"]) {
  texts.push(M.confirmText(kind, apps, ["photocraft"]), M.confirmText(kind, apps, ["photocraft", "wordcraft", "typesetter", "planify"]));
}
texts.push(M.updateNames(apps), M.metaLine(craft), M.metaUpdates(craft), M.summaryLine(done()), M.standingLine(craft));
const versioned = texts.filter((t) => /\d+\.\d+/.test(String(t)) || /1\.2\.3|1\.3\.0/.test(String(t)));
eq("no panel text carries a version", versioned, []);
eq("the update confirm names the app", M.confirmText("update", apps, ["photocraft"]), "Update PhotoCraft · a terminal will open and ask for your password");
eq("the install subtext", M.subtext(apps[13], craft), "New · install · prebuilt, no compiling");

// --- unchanged -----------------------------------------------------------------------------------
eq("Update all: the apps that update alone", M.updateAllPlan(apps), { kind: "update", ids: ["photocraft", "wordcraft"] });
eq("the hero", M.metaLine(craft) + " " + M.metaUpdates(craft), "16 of 20 installed · 2 updates");

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed === 0 ? 0 : 1);
