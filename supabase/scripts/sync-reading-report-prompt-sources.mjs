import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const functionDirectory = path.resolve(scriptDirectory, "../functions/reading-report");
const outputPath = path.join(functionDirectory, "prompt_sources.ts");

const encode = async (fileName) => Buffer.from(
  await readFile(path.join(functionDirectory, fileName)),
).toString("base64");

const chunkedConstant = (name, value) => {
  const chunks = value.match(/.{1,160}/g) ?? [""];
  return `export const ${name} = [\n${chunks.map((chunk) => `  "${chunk}",`).join("\n")}\n].join("");`;
};

let source = await readFile(outputPath, "utf8");
const openingRules = await encode("报告开头文案库.md");
const cognitiveRules = await encode("认知展开文案库.md");
const writingTemplate = await encode("writing-system-template.md");

const replaceOnce = (pattern, replacement, name) => {
  const matches = source.match(new RegExp(pattern.source, pattern.flags.includes("g") ? pattern.flags : `${pattern.flags}g`));
  if (matches?.length !== 1) throw new Error(`Expected exactly one ${name} declaration, found ${matches?.length ?? 0}`);
  source = source.replace(pattern, replacement);
};

replaceOnce(
  /export const OPENING_RULES_BASE64 = "[^"]*";/,
  `export const OPENING_RULES_BASE64 = "${openingRules}";`,
  "opening rules",
);
replaceOnce(
  /export const COGNITIVE_RULES_BASE64 = "[^"]*";/,
  `export const COGNITIVE_RULES_BASE64 = "${cognitiveRules}";`,
  "cognitive rules",
);
replaceOnce(
  /export const WRITING_SYSTEM_TEMPLATE_SINGLE_NEWLINES_EXACT_BASE64 = \[[\s\S]*?\n\]\.join\(""\);/,
  chunkedConstant("WRITING_SYSTEM_TEMPLATE_SINGLE_NEWLINES_EXACT_BASE64", writingTemplate),
  "active writing template",
);

await writeFile(outputPath, source);
