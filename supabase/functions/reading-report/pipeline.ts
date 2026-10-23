import {
  ANALYSIS_SYSTEM_BASE64,
  COGNITIVE_RULES_BASE64,
  OPENING_HOLIDAYS_BASE64,
  OPENING_RULES_BASE64,
  WRITING_SYSTEM_TEMPLATE_SINGLE_NEWLINES_EXACT_BASE64,
} from "./prompt_sources.ts";

export const DEEPSEEK_MODEL = "deepseek-flash";
export const ANALYSIS_MAX_TOKENS = 1_400;
export const WRITING_MAX_TOKENS = 400;
// Reserve the worst case when usage limits are enabled: the analysis contract
// may be retried once before the single writing call.
export const RESERVED_OUTPUT_TOKENS = ANALYSIS_MAX_TOKENS * 2 + WRITING_MAX_TOKENS;

function decodePrompt(encoded: string): string {
  const binary = atob(encoded);
  return new TextDecoder().decode(Uint8Array.from(binary, (character) => character.charCodeAt(0)));
}

const analysisSystemSource = decodePrompt(ANALYSIS_SYSTEM_BASE64);
const writingSystemTemplateSource = decodePrompt(WRITING_SYSTEM_TEMPLATE_SINGLE_NEWLINES_EXACT_BASE64);
const openingRulesSource = decodePrompt(OPENING_RULES_BASE64);
const cognitiveRulesSource = decodePrompt(COGNITIVE_RULES_BASE64);
const openingHolidaysSource = decodePrompt(OPENING_HOLIDAYS_BASE64);

const analysisSystem = analysisSystemSource.trim();
const writingSystemTemplate = writingSystemTemplateSource.trim();
const openingHolidays = JSON.parse(openingHolidaysSource) as Record<string, string>;

export type CoreCategory = "认知过程" | "认知结果";
export interface AnalysisOptions {
  coreCategory: CoreCategory;
  valueComponent: "对本次认知贡献的认可" | "对认知结果的价值阐释" | "对认知成长方向的认可";
}
export interface ContentComponent {
  category: "认知过程" | "认知结果" | "认知价值";
  component: string;
  summary: string;
}
export interface AnalysisResult {
  level: 2;
  action: string;
  traces: Array<{ source: "用户笔记"; content: string }>;
  content_components: ContentComponent[];
  认知展开?: { 论述组织: { 切入对象: string; 认可方式?: string } };
}
export interface WritingProfile {
  userName: string;
  focusMinutes: number;
  conversationCount: number;
  currentDate: string;
  currentTime: string;
  period: string;
}
interface PreparedBasicProfile {
  用户名称: string;
  用户时区: string;
  本次阅读: { 已完成: true; 累计阅读时长分钟: number; 深度对话次数: number };
  当前日期: string;
  当前时间: string;
  当前时段: string;
  节假日名称: string;
}
interface OpeningOption {
  切入内容: "文章整体概括" | "阅读情境寒暄";
  论述组织: "直接陈述" | "提问切入" | "对话式切入";
  寒暄内容?: "完成阅读" | "时间投入" | "日期或时间段问候";
  肯定角度?: "肯定阅读投入" | "肯定泛化的文章知识收获";
  问候语?: string;
}
interface WritingContext {
  basicProfile: PreparedBasicProfile;
  writingOptions: { 报告开头: OpeningOption };
}
export interface WritingRequest {
  system: string;
  user: string;
  profile: PreparedBasicProfile;
  writingOptions: { 报告开头: OpeningOption };
}

const valueComponents: AnalysisOptions["valueComponent"][] = ["对本次认知贡献的认可", "对认知结果的价值阐释", "对认知成长方向的认可"];
const validActions = new Set(["理解", "辨析", "抽象", "整合", "推演", "延伸", "自我映射", "未解决张力"]);
const recognitionModes = new Set(["评价性修饰语", "显性评价引导", "有分量的动作命名", "具体成果体现分量", "跨度或变化体现分量"]);
const openingContents: OpeningOption["切入内容"][] = ["文章整体概括", "阅读情境寒暄"];
const articleOrganizations: OpeningOption["论述组织"][] = ["直接陈述", "提问切入", "对话式切入"];
const greetings: NonNullable<OpeningOption["寒暄内容"]>[] = ["完成阅读", "时间投入", "日期或时间段问候"];
const angles: NonNullable<OpeningOption["肯定角度"]>[] = ["肯定阅读投入", "肯定泛化的文章知识收获"];

function pick<T>(items: T[], random: () => number): T {
  return items[Math.min(items.length - 1, Math.floor(random() * items.length))];
}

export function chooseAnalysisOptions(random = Math.random): AnalysisOptions {
  const coreCategory: CoreCategory = random() < 0.5 ? "认知过程" : "认知结果";
  const candidates = coreCategory === "认知过程" ? valueComponents.filter((value) => value !== "对认知结果的价值阐释") : valueComponents;
  return { coreCategory, valueComponent: pick(candidates, random) };
}

export function buildAnalysisSystem(): string { return analysisSystem; }

export function buildAnalysisUser(title: string, articleBody: string, note: string, options: AnalysisOptions): string {
  const base = [
    `文章标题：${title}`, "", "文章全文：", articleBody, "",
    "本次用户笔记（单条原始记录，可同时支撑多个分析组件）：", note,
  ].join("\n");
  const activeOptions = { 主内容类别: options.coreCategory, 认知价值组件: options.valueComponent, 固定表达选择: {} };
  return `${base}\n\n本次程序选项（主内容类别和认知价值组件已经选定）：\n认知价值的 component 必须使用下方“认知价值组件”；summary 统一按“对本次认知贡献的认可”概括，不随组件名称改变写作口径。\n${JSON.stringify(activeOptions, null, 2)}`;
}

function asRecord(value: unknown, error: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(error);
  return value as Record<string, unknown>;
}
function requireExactFields(value: Record<string, unknown>, fields: string[], location: string): void {
  for (const field of fields) if (!Object.hasOwn(value, field)) throw new Error(`${location} 缺少必填字段：${field}`);
  const extras = Object.keys(value).filter((field) => !fields.includes(field));
  if (extras.length) throw new Error(`${location} 包含未约定字段：${extras.join(", ")}`);
}

export function parseAndValidateAnalysis(raw: string, options: AnalysisOptions): AnalysisResult {
  const unfenced = raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
  const value = asRecord(JSON.parse(unfenced), "分析结果必须是 JSON 对象");
  const allowedRoot = ["level", "action", "traces", "content_components", "认知展开"];
  for (const field of ["level", "action", "traces", "content_components"]) if (!Object.hasOwn(value, field)) throw new Error(`分析结果缺少必填字段：${field}`);
  const extras = Object.keys(value).filter((field) => !allowedRoot.includes(field));
  if (extras.length) throw new Error(`分析结果包含未约定字段：${extras.join(", ")}`);
  if (value.level !== 2 || typeof value.action !== "string" || !validActions.has(value.action)) throw new Error("单笔记 demo 的等级或认知动作不符合约定");
  if (!Array.isArray(value.traces) || value.traces.length !== 1) throw new Error("单笔记 demo 的 traces 必须恰好包含一项用户笔记");
  const trace = asRecord(value.traces[0], "痕迹必须是对象");
  requireExactFields(trace, ["source", "content"], "痕迹");
  if (trace.source !== "用户笔记" || typeof trace.content !== "string" || !trace.content.trim()) throw new Error("单笔记 demo 的 traces 必须恰好包含一项用户笔记");
  if (!Array.isArray(value.content_components) || value.content_components.length !== 2) throw new Error("本次仅允许主内容与认知价值，共两项组件");
  const components = value.content_components.map((item) => {
    const component = asRecord(item, "内容组件必须是对象");
    requireExactFields(component, ["category", "component", "summary"], "内容组件");
    if (["category", "component", "summary"].some((field) => typeof component[field] !== "string" || !String(component[field]).trim())) throw new Error("内容组件字段必须是非空字符串");
    return component;
  });
  const categoryCount = (category: string) => components.filter((item) => item.category === category).length;
  const otherCategory = options.coreCategory === "认知过程" ? "认知结果" : "认知过程";
  if (categoryCount(options.coreCategory) !== 1 || categoryCount(otherCategory) !== 0 || categoryCount("认知价值") !== 1) throw new Error("主内容类别与程序选项不一致");
  const core = components.find((item) => item.category === options.coreCategory)!;
  const valueComponent = components.find((item) => item.category === "认知价值")!;
  const validCore = options.coreCategory === "认知过程" ? core.component === "用户完成的认知行为" : ["识别结果", "改变结果", "生成成果"].includes(String(core.component));
  if (!validCore || valueComponent.component !== options.valueComponent) throw new Error("分析组件与程序选项不一致");
  if (Object.hasOwn(value, "认知展开")) {
    const expansion = asRecord(value.认知展开, "认知展开必须是对象");
    requireExactFields(expansion, ["论述组织"], "认知展开");
    const organization = asRecord(expansion.论述组织, "认知展开.论述组织必须是对象");
    requireExactFields(organization, ["切入对象", "认可方式"], "认知展开.论述组织");
    if (organization.切入对象 !== core.component || typeof organization.认可方式 !== "string" || !recognitionModes.has(organization.认可方式)) throw new Error("认知展开的表达选择不符合约定");
  }
  return value as unknown as AnalysisResult;
}

function shanghaiParts(now: Date): Record<string, string> {
  return Object.fromEntries(new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Shanghai", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(now).map(({ type, value }) => [type, value]));
}
export function shanghaiProfile(focusMinutes: number, now = new Date()): WritingProfile {
  const parts = shanghaiParts(now);
  const hour = Number(parts.hour);
  return {
    userName: "Edison", focusMinutes, conversationCount: 10,
    currentDate: `${parts.year}-${parts.month}-${parts.day}`,
    currentTime: `${parts.hour}:${parts.minute}`,
    period: hour >= 5 && hour < 11 ? "早上" : hour < 14 ? "中午" : hour < 18 ? "下午" : "晚上",
  };
}

function prepareOpening(profile: WritingProfile, random: () => number): WritingContext {
  const holiday = openingHolidays[profile.currentDate] || openingHolidays[profile.currentDate.slice(5)] || "";
  const basicProfile: PreparedBasicProfile = {
    用户名称: profile.userName,
    用户时区: "Asia/Shanghai",
    本次阅读: { 已完成: true, 累计阅读时长分钟: profile.focusMinutes, 深度对话次数: profile.conversationCount },
    当前日期: profile.currentDate, 当前时间: profile.currentTime, 当前时段: profile.period, 节假日名称: holiday,
  };
  const opening: OpeningOption = { 切入内容: pick(openingContents, random), 论述组织: "直接陈述" };
  if (opening.切入内容 === "文章整体概括") {
    opening.论述组织 = pick(articleOrganizations, random);
  } else {
    opening.论述组织 = "对话式切入";
    opening.寒暄内容 = pick(greetings, random);
    opening.肯定角度 = opening.寒暄内容 === "完成阅读" ? "肯定泛化的文章知识收获" : pick(angles, random);
    if (opening.寒暄内容 === "日期或时间段问候") opening.问候语 = holiday ? `${holiday}快乐` : `${profile.period}好`;
  }
  return { basicProfile, writingOptions: { 报告开头: opening } };
}

interface HeadingMatch { level: number; title: string; index: number; length: number }
function markdownHeadings(markdown: string): HeadingMatch[] {
  return [...markdown.matchAll(/^(#{2,3}) (.+)\r?$/gm)].map((match) => ({ level: match[1].length, title: match[2], index: match.index ?? 0, length: match[0].length }));
}
function parseOpeningRules(markdown: string): Record<string, string> {
  const rules: Record<string, string> = {};
  const headings = markdownHeadings(markdown);
  for (let index = 0; index < headings.length; index += 1) {
    const current = headings[index];
    const end = headings.slice(index + 1).find((heading) => heading.level <= current.level);
    const key = current.title.trim().replace("整体文章概括", "文章整体概括").replace(/^内容：文章整体概括$/, "文章整体概括");
    if (key === "阅读情境寒暄（对话式切入）") continue;
    if (rules[key]) throw new Error(`重复的报告开头文案标题：${key}`);
    rules[key] = markdown.slice(current.index + current.length, end?.index ?? markdown.length).trim();
  }
  return rules;
}
const valueAliases: Record<string, string> = { 认知结果的价值阐释: "对认知结果的价值阐释", 认知成长方向的认可: "对认知成长方向的认可" };
function parseCognitiveRules(markdown: string): Record<string, string> {
  const rules: Record<string, string> = {};
  const headings = markdownHeadings(markdown);
  for (let index = 0; index < headings.length; index += 1) {
    const heading = headings[index];
    if (["认知过程", "认知结果", "认知价值"].includes(heading.title)) continue;
    const end = headings.slice(index + 1).find((next) => next.level <= heading.level);
    let key = valueAliases[heading.title] || heading.title;
    key = key.replace("切入对象：认知结果-认知过程", "切入对象：认知过程-用户完成的认知行为");
    if (rules[key]) throw new Error(`重复的认知展开文案标题：${key}`);
    rules[key] = markdown.slice(heading.index + heading.length, end?.index ?? markdown.length).trim();
  }
  return rules;
}
const openingRules = parseOpeningRules(openingRulesSource);
const cognitiveRules = parseCognitiveRules(cognitiveRulesSource);

function normalizeWritingAnalysis(analysis: AnalysisResult): AnalysisResult {
  const cores = analysis.content_components.filter((component) => ["认知过程", "认知结果"].includes(component.category));
  const entry = analysis.认知展开?.论述组织?.切入对象;
  const core = cores.length === 1 ? cores[0] : cores.find((component) => [component.component, `${component.category}-${component.component}`].includes(entry ?? ""));
  const values = analysis.content_components.filter((component) => component.category === "认知价值");
  if (!core || values.length !== 1) throw new Error("写作需要一项可确定的认知过程或认知结果，以及一项认知价值");
  const value = { ...values[0], component: valueAliases[values[0].component] || values[0].component };
  if (core.category === "认知过程" && value.component === "对认知结果的价值阐释") throw new Error("认知过程不能搭配对认知结果的价值阐释");
  return {
    ...analysis,
    content_components: [core, value],
    认知展开: { 论述组织: { 切入对象: core.component } },
  };
}

function composeCognitiveSystem(base: string, rules: Record<string, string>, analysis: AnalysisResult, writingOptions: WritingContext["writingOptions"]): string {
  const [core, value] = analysis.content_components;
  const rule = (key: string) => { if (!rules[key]) throw new Error(`缺少认知展开文案：${key}`); return rules[key]; };
  const entryKey = `本次认知展开的切入对象：${core.category}-${core.component}`;
  const transition = writingOptions.报告开头.切入内容 === "文章整体概括"
    ? rule("从报告开头到认知展开的转场")
    : "- 寒暄之后直接进入本次选定的认知展开切入对象，用‘在你的笔记中’等表达标记来源，不额外补写文章概括。";
  const organization = `## ${entryKey}\n${rule(entryKey)}\n\n## 从报告开头到认知展开的转场\n${transition}`;
  const components = `## ${core.category}\n### ${core.component}\n${rule(core.component)}\n\n## 认知价值\n### ${value.component}\n${rule(value.component)}`;
  for (const token of ["{{COGNITIVE_ORGANIZATION}}", "{{COGNITIVE_COMPONENTS}}"]) if (!base.includes(token)) throw new Error(`写作基础模板缺少占位符：${token}`);
  return base.replace("{{COGNITIVE_ORGANIZATION}}", organization).replace("{{COGNITIVE_COMPONENTS}}", components);
}
function composeWritingSystem(base: string, rules: Record<string, string>, writingOptions: WritingContext["writingOptions"]): string {
  const opening = writingOptions.报告开头;
  const rule = (key: string) => { if (!rules[key]) throw new Error(`缺少报告开头文案：${key}`); return rules[key]; };
  let content: string;
  if (opening.切入内容 === "阅读情境寒暄") {
    const key = `${opening.寒暄内容}：${opening.肯定角度}`;
    content = `## 阅读情境寒暄（对话式切入）\n### ${key}\n${rule(key)}`;
  } else {
    content = `## 文章整体概括\n${rule("文章整体概括")}`;
    if (opening.论述组织 !== "直接陈述") content += `\n\n# 本次报告开头的论述组织\n## ${opening.论述组织}\n${rule(`文章概括的${opening.论述组织}`)}`;
  }
  return base.replace("{{REPORT_OPENING}}", content);
}
function buildWritingUserMessage(title: string, body: string, analysis: AnalysisResult, context: WritingContext): string {
  const { traces: _traces, ...writingAnalysis } = analysis;
  return [
    "用户基础资料：", JSON.stringify(context.basicProfile, null, 2), "",
    "程序写作选项：", JSON.stringify(context.writingOptions, null, 2), "",
    `文章标题：${title}`, "", "文章全文：", body, "",
    "第一阶段已审核的阅读证据分析结果：", JSON.stringify(writingAnalysis, null, 2),
  ].join("\n");
}

export function buildWritingRequest(title: string, body: string, analysis: AnalysisResult, profile: WritingProfile, random = Math.random): WritingRequest {
  const normalizedAnalysis = normalizeWritingAnalysis(analysis);
  const context = prepareOpening(profile, random);
  const system = composeWritingSystem(
    composeCognitiveSystem(writingSystemTemplate, cognitiveRules, normalizedAnalysis, context.writingOptions),
    openingRules,
    context.writingOptions,
  );
  return { system, user: buildWritingUserMessage(title, body, normalizedAnalysis, context), profile: context.basicProfile, writingOptions: context.writingOptions };
}

export function validateReportBody(value: string): string {
  const body = value.trim();
  if (!body) throw new Error("writing_invalid_body");
  return body;
}
