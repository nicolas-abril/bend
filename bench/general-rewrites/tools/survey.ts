// survey.ts FILE: check FILE, run the survey hook, print one JSON line
const BEND = "/private/tmp/bend-opt/gen/hk/bend2";
const Bend = await import(BEND + "/bend.ts");
const Comp = await import(BEND + "/comp.ts");
const book = Bend.book_nil();
await Bend.book_load(book, process.argv[2], "", new Map());
Bend.book_valid(book, 0);
const r = Comp.survey(book);
console.log(JSON.stringify({ file: process.argv[2], ...r }));
