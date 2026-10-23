import {
  buildAnalysisSystem,
  buildWritingRequest,
  chooseAnalysisOptions,
  parseAndValidateAnalysis,
  shanghaiProfile,
  validateReportBody,
} from "./pipeline.ts";

const assertEquals = (actual: unknown, expected: unknown) => {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
};

Deno.test("analysis options keep process from selecting result-only value", () => {
  const options = chooseAnalysisOptions(() => 0.1);
  assertEquals(options, { coreCategory: "认知过程", valueComponent: "对本次认知贡献的认可" });
});

Deno.test("validates the exact two-component analysis contract", () => {
  const result = parseAndValidateAnalysis(JSON.stringify({
    level: 2,
    action: "自我映射",
    traces: [{ source: "用户笔记", content: "我把文章机制联系到自己的工作。" }],
    content_components: [
      { category: "认知结果", component: "生成成果", summary: "提出了一个具体检验办法。" },
      { category: "认知价值", component: "对认知结果的价值阐释", summary: "让原先模糊的判断变得可验证。" },
    ],
    认知展开: { 论述组织: { 切入对象: "生成成果", 认可方式: "具体成果体现分量" } },
  }), { coreCategory: "认知结果", valueComponent: "对认知结果的价值阐释" });
  assertEquals(result.content_components.length, 2);
});

Deno.test("writing input includes full article and fixed demo metrics", () => {
  const request = buildWritingRequest("标题", "完整原文", {
    level: 2,
    action: "理解",
    traces: [{ source: "用户笔记", content: "笔记" }],
    content_components: [
      { category: "认知过程", component: "用户完成的认知行为", summary: "概括" },
      { category: "认知价值", component: "对本次认知贡献的认可", summary: "价值" },
    ],
    认知展开: { 论述组织: { 切入对象: "用户完成的认知行为", 认可方式: "有分量的动作命名" } },
  }, { ...shanghaiProfile(20, new Date("2026-10-22T04:00:00Z")), conversationCount: 10 }, () => 0);
  if (!request.user.includes("完整原文") || !request.user.includes('"累计阅读时长分钟": 20') || !request.user.includes('"深度对话次数": 10')) {
    throw new Error("writing input omitted required context");
  }
  if (request.user.includes('"traces"') || /\{\{(?:REPORT_OPENING|COGNITIVE_ORGANIZATION|COGNITIVE_COMPONENTS)\}\}/.test(request.system)) {
    throw new Error("writing assembly did not follow the handoff protocol");
  }
  if (!request.system.includes("# 报告开头") || !request.system.includes("# 认知展开")) {
    throw new Error("writing system omitted assembled handoff rules");
  }
  if (request.system.includes("本次认可方式") || request.user.includes('"认可方式"')) {
    throw new Error("demo writing request must not pass the recognition mode to the second call");
  }
  if (!request.system.includes("只有本次加载的报告开头文案明确要求使用阅读时长时")) {
    throw new Error("writing system omitted the conditional reading-duration rule");
  }
});

Deno.test("report body preserves model output even when it exceeds the suggested length", () => {
  const body = "这是一段由模型按照原始提示词生成的报告正文。".repeat(20);
  assertEquals(validateReportBody(body), body);
});

Deno.test("analysis system is loaded from the original handoff prompt", () => {
  const prompt = buildAnalysisSystem();
  if (!prompt.includes("# 角色与任务") || !prompt.includes("## 单条笔记可识别的认知动作")) {
    throw new Error("original analysis prompt was not loaded");
  }
});
