# 输出生成策略 Output Generation Strategy
输出生成策略用于定义 AI 搜索最终返回给用户的响应形态。
本策略发生在 Step6 结果归一化、去重与排序之后。系统基于前序字段决定输出形态，LLM 只在已确定的输出形态下生成文案、摘要和分点内容。

## 1. 策略定位
输出生成策略负责：
- 判断本次请求应该使用哪种输出形态。
- 生成 AI 文案。
- 决定是否展示结果列表。
- 决定结果列表展示哪些内容对象。
- 决定解释类和主题整理类回答中，来源内容卡片如何绑定和折叠。

输出生成策略不负责：
- 判断用户意图。
- 判断知识库内容是否可用。
- 执行完整检索。
- 对结果做归一化、去重或排序。
- 改变文章或阅读资产卡片的展示形态。

## 2. 通用路由输入字段
输出生成策略使用前序流程已经产生的字段作为输入，不新增上游 LLM 结构化输出字段。

### 2.1 字段总览
```json
{
  "query": "有没有关于消费主义的笔记",
  "task_type": "content_locate",
  "target_content_types": ["note"],
  "query_rewrite": "消费主义 笔记",
  "kb_content_usable_for_answer": true,
  "missing_target_content_types": [],
  "supplemental_content_types": [],
  "normalized_results": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 0,
    "note": 0
  }
}
```

### 2.2 字段说明
- `query`：用户原始输入，用于输出文案生成和显式内容类型词判断。
- `task_type`：用户任务类型，决定进入哪一种输出策略。
- `target_content_types`：用户希望查找或使用的目标内容类型。
- `query_rewrite`：检索用查询文本，可用于输出文案中的主题表达。
- `kb_content_usable_for_answer`：知识库内容是否可用于回答。
- `missing_target_content_types`：用户指定但未命中的目标内容类型。
- `supplemental_content_types`：用户未指定，但系统基于同主题相关性补充返回的内容类型。
- `normalized_results`：Step6 输出的业务对象级结果集合，是最终展示和生成回答的来源。
- `result_type_counts`：`normalized_results` 中各内容类型的数量统计，用于判断当前实际命中的内容类型。

## 3. content_locate 输出策略
`content_locate` 用于满足用户“找内容”的请求。
该任务类型的核心目标是帮助用户定位知识库中已有的文章、划线或笔记。输出应以结果列表为主，AI 文案只做简短说明和结果摘要，不展开长篇解释。

### 3.2 输出结构与字段生成规则
```json
{
  "response_intro": "",
  "result_summary_blocks": [
    {
      "summary": "这条划线提到消费主义与身份表达之间的关系。",
      "result_id": "asset_023"
    }
  ],
  "answer_blocks": []
}
```

字段规则：
- `response_intro`：LLM 生成，用于简要说明本次查找结果。
- `result_summary_blocks`：LLM 生成，最多 5 条，用于前 5 个结果的分点摘要。
- `result_summary_blocks.summary`：简短说明该内容为什么与用户 query 相关。
- `result_summary_blocks.result_id`：对应 `normalized_results` 中的业务对象 ID，不引用完整检索阶段的字段级命中块。
- `answer_blocks`：content_locate 不使用，固定为空数组。

UI 渲染规则：
1. 前端以 `normalized_results` 作为唯一的结果卡片数据来源。
2. 前端按 `normalized_results` 的排序顺序依次渲染结果卡片。
3. 对于 `normalized_results` 中排序前 5 的结果：
   - LLM 必须基于对应结果内容生成一条 `result_summary_blocks` 摘要。
   - 每条 `result_summary_blocks` 必须通过 `result_id` 绑定一个前 5 个 `normalized_results` 结果。
4. 对于 `normalized_results` 中第 6 到第 10 个结果：
   - 只展示结果卡片。
   - 不生成、不展示 `result_summary_blocks` 摘要。
5. 对于 `normalized_results` 中第 11 个及之后的结果：
   - 默认折叠。
   - 用户点击答案最末尾的“查看更多”后，继续以结果卡片的形式展示余下的所有结果。

### 3.3 response_intro 生成规则
它只用于说明当前查找结果状态，包括：
- 找到了哪些相关内容类型。
- 是否有用户显式指定的内容类型未找到。
- 是否返回了补充类型内容。
- 所有类型均无结果时的无结果提示。

#### 3.3.1 针对显式内容类型词的弱规则
输出阶段根据用户原始 `query` 判断是否出现明确内容类型词。

明确内容类型词包括：
- article：文章、推文、那篇文章、那篇推文、每日好文、往期推文。
- highlight：划线、摘录、标注、原文、某句话、某段内容。
- note：笔记、想法、观点、思考、记录。

规则：
- 如果用户 `query` 未明确提到内容类型，只是说“内容”“相关内容”或只输入主题词，`response_intro` 只说明当前找到了哪些实际命中的内容类型，即使 `missing_target_content_types` 不为空，`response_intro` 不主动说明哪些类型未找到。
- 如果用户 `query` 显式提到某类内容类型
  - 如果 `missing_target_content_types` 不为空，`response_intro` 需要说明该 `missing_target_content_types` 中的类型未找到。
  - 如果 `supplemental_content_types` 不为空，`response_intro` 需要说明找到了哪些补充类型，即 `supplemental_content_types` 的内容。
- 当前实际命中的内容类型由 `result_type_counts` 判断。
- `response_intro` 中只使用文章、划线、笔记三种内容类型称呼。`article` 在输出中写作“文章”、`highlight` 在输出中写作“划线”、`note` 在输出中写作“笔记”。
- 不在 `response_intro` 中说明具体命中数量，只说明命中的内容类型。

### 3.4 content_locate 输出示例
```json
{
  "response_intro": "没有找到消费主义相关笔记，但为你找到了相关文章和划线。",
  "result_summary_blocks": [
    {
      "summary": "这条划线提到消费主义与身份表达之间的关系。",
      "result_id": "asset_023"
    },
    {
      "summary": "这篇文章讨论了消费主义如何塑造身份认同。",
      "result_id": "article_001"
    }
  ],
  "answer_blocks": []
}
```

## 4. explain 输出策略
`explain` 用于解释用户提出的概念、主题或内容对象。

### 4.1 任务定位
explain 回答的是：
```text
这个概念、主题或内容对象是什么意思？
应该怎么理解？
它的原因、机制或核心价值是什么？
```

explain 不负责：
- 单纯查找结果位置。
- 对整个主题做全貌整理。
- 展示所有相关结果。

### 4.2 输出结构与字段生成规则
```json
{
  "response_intro": null,
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "核心价值",
      "content": "Transformer 的核心价值在于用注意力机制替代传统循环结构，从而提升并行计算效率和长距离依赖建模能力。",
      "source_content_ids": ["article_001", "asset_023"],
      "sources_collapsed_by_default": true
    }
  ]
}
```

字段规则：
- `response_intro`：LLM 生成，可为空，用于多分点总述或显式内容类型词场景下的信息源说明。
- `result_summary_blocks`：explain 不使用，固定为空数组。
- `answer_blocks`：LLM 生成，是解释正文主体。可以生成一个或多个解释点，每个解释点应围绕一个清晰的解释角度展开。
- `answer_blocks.title`：LLM 生成，是解释点标题，应简短概括该解释点。
- `answer_blocks.content`：LLM 生成，解释点正文，应基于 `normalized_results` 中的内容生成。
- `answer_blocks.source_content_ids`：该解释点使用的来源内容对象 ID，必须引用 `normalized_results`中的业务对象 ID，不引用完整检索阶段的字段级命中块。
- `answer_blocks.sources_collapsed_by_default`：来源卡片是否默认折叠，由系统按折叠规则确定。

UI 渲染规则：
1. 如果 `response_intro` 不为空，先展示 `response_intro`。
2. 展示 `answer_blocks`。
3. 每个解释点绑定 1 到 5 个来源内容对象，来源内容对象必须来自 `normalized_results`。
4. 同一个来源内容对象在 MVP 阶段只绑定到一个最相关的解释点，不重复绑定到多个解释点。
5. 来源内容对象与解释点必须存在明确支撑关系，不能为了展示数量而强行绑定。
6. 来源折叠规则：
- 当 `answer_blocks.length = 1` 时，不需要展示分点后的折叠按钮，绑定的相关内容卡片直接放在答案末尾。并且不影响未被绑定到解释点的结果在答案最末尾的“查看更多”中展示。
- 当 `answer_blocks.length > 1` 时，每个分点后展示“展开来源”按钮，来源内容卡片默认折叠。并且不影响未被绑定到解释点的结果在答案最末尾的“查看更多”中展示。
- 用户点击折叠按钮，展开后，以结果卡片的形式，展示绑定的来源内容对象。
7. `normalized_results` 中，未被绑定到解释点的结果，作为后续扩展展示：
   - 默认折叠。
   - 用户点击答案最末尾的“查看更多”后，继续以结果卡片的形式，展示未被绑定到解释点的所有结果。

### 4.3 response_intro 生成规则
`response_intro` 由两类内容组成，它们彼此独立：
- 多分点总结：当 `answer_blocks.length >= 2` 时触发，用于概括后续解释将从哪些方面展开。
- 信息源说明：只有当用户 `query` 出现显式内容类型词时才触发，用于说明当前解释基于哪些类型内容，或说明未命中的目标内容类型、使用了哪些补充类型。

因此 explain 的 `response_intro` 可能有四种情况：
- 有多分点总结 + 有信息源说明。
- 只有多分点总结。
- 只有信息源说明。
- `response_intro = null`。

#### 4.3.1 信息源说明触发规则/针对显式内容类型词的弱规则
输出阶段根据用户原始 `query` 判断是否出现明确内容类型词。

明确内容类型词包括：
- article：文章、推文、那篇文章、那篇推文、每日好文、往期推文。
- highlight：划线、摘录、标注、原文、某句话、某段内容。
- note：笔记、想法、观点、思考、记录。

explain 与 content_locate 不同。
content_locate 是查找任务，即使用户没有显式内容类型词，也需要说明找到了哪些类型的内容。
explain 是解释任务。只有当用户 `query` 出现显式内容类型词时，`response_intro` 才加入“信息源说明”。

规则：
- 如果用户 `query` 没有显式内容类型词，不输出“信息源说明”。
- 如果用户 `query` 出现显式内容类型词，`response_intro` 才加入“信息源说明”内容，“信息源说明”需要说明当前找到了哪些实际命中的内容类型。并且：
  - 如果 `missing_target_content_types` 不为空，“信息源说明”需要说明该 `missing_target_content_types` 中的类型未找到。
  - 如果 `supplemental_content_types` 不为空，“信息源说明”需要说明找到了哪些补充类型，即 `supplemental_content_types` 的内容。
- 当前实际使用的内容类型由 `result_type_counts` 判断。
- “信息源说明”中只使用文章、划线、笔记三种内容类型称呼。`article` 在输出中写作“文章”、`highlight` 在输出中写作“划线”、`note` 在输出中写作“笔记”。
- 不在“信息源说明”中说明具体命中数量，只说明命中的内容类型。

#### 4.3.2 多分点总结生成规则
条件：
- `answer_blocks.length >= 2`

生成规则：
- 生成一句对所有分点的总括说明。
- 总结后续会从哪些方面解释该对象。
- 不需要在这句话里说明信息来源，除非同时触发信息源说明规则。

### 4.4 explain 输出示例
#### 4.4.1 `response_intro` 形态：信息源说明 + 多分点总结
条件：
- 用户 `query` 出现显式内容类型词
- `answer_blocks.length >= 2`
输出结构：
```json
{
  "response_intro": "以下解释基于你保存的消费主义相关笔记和划线，我会从身份表达、欲望制造和情绪补偿三个方面说明。",
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "身份表达",
      "content": "消费主义不只是购买行为，也常常被用来表达身份。相关笔记中提到，人们会通过品牌、品味和生活方式展示自己希望被看见的样子。",
      "source_content_ids": ["asset_023", "asset_041"],
      "sources_collapsed_by_default": true
    },
    {
      "title": "欲望制造",
      "content": "消费主义会不断制造新的需求，让原本可有可无的商品被包装成个人成长、审美升级或社会认同的必要条件。",
      "source_content_ids": ["article_001"],
      "sources_collapsed_by_default": true
    },
    {
      "title": "情绪补偿",
      "content": "部分划线内容指出，消费也可能成为缓解焦虑和空虚感的方式。它短期内提供满足感，但不一定真正解决情绪来源。",
      "source_content_ids": ["asset_058"],
      "sources_collapsed_by_default": true
    }
  ]
}
```

#### 4.4.2 `response_intro` 形态：仅多分点总结
条件：
- 用户 `query` 未出现显式内容类型词
- `answer_blocks.length >= 2`
输出结构：
```json
{
  "response_intro": "可以从身份表达、欲望制造和情绪补偿三个方面理解消费主义。",
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "身份表达",
      "content": "消费主义常常把购买行为和身份建构绑定在一起。用户不只是购买商品，也是在选择一种可被他人识别的生活方式。",
      "source_content_ids": ["asset_023"],
      "sources_collapsed_by_default": true
    },
    {
      "title": "欲望制造",
      "content": "它通过广告、社交比较和审美标准不断制造新的需求，使人持续感觉自己还缺少某种东西。",
      "source_content_ids": ["article_001"],
      "sources_collapsed_by_default": true
    },
    {
      "title": "情绪补偿",
      "content": "消费还可能被用来补偿焦虑、疲惫或空虚感，因此它不仅是经济行为，也和情绪调节有关。",
      "source_content_ids": ["asset_058"],
      "sources_collapsed_by_default": true
    }
  ]
}
```

#### 4.4.3 `response_intro` 形态：仅信息源说明
条件：
- 用户 `query` 出现显式内容类型词
- `answer_blocks.length = 1`
输出结构：
```json
{
  "response_intro": "以下解释基于你保存的消费主义相关笔记。",
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "核心含义",
      "content": "消费主义可以理解为一种把消费置于生活中心的价值取向。相关笔记中强调，它不只是买东西，而是把身份、审美和自我价值感都纳入消费逻辑中。",
      "source_content_ids": ["asset_023", "asset_041"],
      "sources_collapsed_by_default": false
    }
  ]
}
```

#### 4.4.4 `response_intro` 形态：`response_intro` 为空
条件：
- 用户 `query` 没有显式内容类型词
- `answer_blocks.length = 1`
输出结构：
```json
{
  "response_intro": null,
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "核心含义",
      "content": "消费主义可以理解为一种以消费来组织欲望、身份和社会认同的价值体系。它让购买行为超出满足基本需求的范围，转而承担表达自我、获得认同和缓解情绪的功能。",
      "source_content_ids": ["asset_023"],
      "sources_collapsed_by_default": false
    }
  ]
}
```

## 5. topic_explore 输出策略
`topic_explore` 用于围绕某一主题整理知识库中的相关内容。

### 5.1 任务定位
topic_explore 回答的是：

```text
这个主题在我的知识库里是如何被讨论的？
有哪些方向、观点或内容线索？
这些内容可以如何结构化整理？
```

topic_explore 不负责：
- 单纯查找某条内容。
- 解释一个孤立概念。
- 生成超出知识库内容支撑范围的完整研究报告。

### 5.2 输出结构与字段生成规则
```json
{
  "response_intro": null,
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "长期压力累积",
      "content": "多条内容都提到，职业倦怠往往不是单次事件造成的，而是长期压力和恢复不足共同作用的结果。",
      "source_content_ids": ["asset_101", "asset_102"],
      "sources_collapsed_by_default": true
    }
  ]
}
```

字段规则：
- `response_intro`：LLM 生成，可为空，用于多分点总述或显式内容类型词场景下的信息源说明。
- `result_summary_blocks`：topic_explore 不使用，固定为空数组。
- `answer_blocks`：LLM 生成，是主题整理正文主体。
- `answer_blocks.title`：主题点标题，由 LLM 生成。
- `answer_blocks.content`：主题点正文，由 LLM 生成。
- `answer_blocks.source_content_ids`：该主题点使用的来源内容对象 ID，必须来自 `normalized_results`。
- `answer_blocks.sources_collapsed_by_default`：来源卡片是否默认折叠，由系统按折叠规则确定。

UI 渲染顺序：
1. 如果 `response_intro` 不为空，先展示 `response_intro`。
2. 展示 `answer_blocks`。
3. 每个总结点绑定 1 到 5 个来源内容对象，来源内容对象必须来自 `normalized_results`。
4. 同一个来源内容对象在 MVP 阶段只绑定到一个最相关的总结点，不重复绑定到多个总结点。
5. 来源内容对象与总结点必须存在明确支撑关系，不能为了展示数量而强行绑定。
6. 来源折叠规则：
- 当 `answer_blocks.length = 1` 时，不需要展示分点后的折叠按钮，绑定的相关内容卡片直接放在答案末尾。并且不影响未被绑定到总结点的结果在答案最末尾的“查看更多”中展示。
- 当 `answer_blocks.length > 1` 时，每个分点后展示“展开来源”按钮，来源内容卡片默认折叠。并且不影响未被绑定到总结点的结果在答案最末尾的“查看更多”中展示。
- 用户点击折叠按钮，展开后，以结果卡片的形式，展示绑定的来源内容对象。
7. `normalized_results` 中，未被绑定到总结点的结果，作为后续扩展展示：
   - 默认折叠。
   - 用户点击答案最末尾的“查看更多”后，继续以结果卡片的形式，展示未被绑定到总结点的所有结果。

### 5.3 response_intro 生成规则
topic_explore 的 `response_intro` 可为空。

`response_intro` 由两类内容组成，它们彼此独立：
- 多分点总结：当 `answer_blocks.length >= 2` 时触发，用于概括后续主题整理将从哪些方向展开。
- 信息源说明：只有当用户 `query` 出现显式内容类型词时才触发，用于说明当前主题总结基于哪些类型内容，或说明未命中的目标内容类型、使用了哪些补充类型。

因此 topic_explore 的 `response_intro` 可能有四种情况：
- 有多分点总结 + 有信息源说明。
- 只有多分点总结。
- 只有信息源说明。
- `response_intro = null`。

#### 5.3.1 信息源说明触发规则/针对显式内容类型词的弱规则
输出阶段根据用户原始 `query` 判断是否出现明确内容类型词。

明确内容类型词包括：
- article：文章、推文、那篇文章、那篇推文、每日好文、往期推文。
- highlight：划线、摘录、标注、原文、某句话、某段内容。
- note：笔记、想法、观点、思考、记录。

topic_explore 与 content_locate 不同。
content_locate 是查找任务，即使用户没有显式内容类型词，也可以说明找到了哪些类型的内容。
topic_explore 是主题整理任务。只有当用户 `query` 出现显式内容类型词时，`response_intro` 才加入“信息源说明”。

规则：
- 如果用户 `query` 没有显式内容类型词，不输出“信息源说明”。
- 如果用户 `query` 出现显式内容类型词，`response_intro` 才加入“信息源说明”内容，“信息源说明”需要说明当前找到了哪些实际命中的内容类型。并且：
  - 如果 `missing_target_content_types` 不为空，“信息源说明”需要说明该 `missing_target_content_types` 中的类型未找到。
  - 如果 `supplemental_content_types` 不为空，“信息源说明”需要说明找到了哪些补充类型，即 `supplemental_content_types` 的内容。
- 当前实际使用的内容类型由 `result_type_counts` 判断。
- “信息源说明”中只使用文章、划线、笔记三种内容类型称呼。`article` 在输出中写作“文章”、`highlight` 在输出中写作“划线”、`note` 在输出中写作“笔记”。

#### 5.3.2 多分点总结生成规则
条件：
- `answer_blocks.length >= 2`

生成规则：
- 生成一句对所有主题点的总括说明。
- 总结后续将从哪些方向整理该主题。
- 如果相关内容较少，应使用保守表达。
- 不使用“完整”“全面”“系统覆盖”等夸大表述。

### 5.4 topic_explore 输出示例
#### 5.4.1 response_intro 形态：信息源说明 + 多分点总结
条件：
- 用户 query 出现显式内容类型词
- answer_blocks.length >= 2
输出结构：
```json
{
  "response_intro": "以下整理基于你保存的职业倦怠相关文章和笔记，相关内容主要集中在长期压力、恢复不足和意义感下降三个方向。",
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "长期压力累积",
      "content": "多条内容都提到，职业倦怠往往不是单次事件造成的，而是长期压力持续累积后的结果。工作负荷、情绪消耗和缺少缓冲空间共同加重了这种状态。",
      "source_content_ids": ["article_011", "asset_101"],
      "sources_collapsed_by_default": true
    },
    {
      "title": "恢复不足",
      "content": "相关笔记中反复出现的一个线索是，休息时间并不等于真正恢复。如果人在休息时仍持续处理工作压力，疲惫感就会不断延续。",
      "source_content_ids": ["asset_102"],
      "sources_collapsed_by_default": true
    },
    {
      "title": "意义感下降",
      "content": "部分内容指出，职业倦怠还和意义感下降有关。当个体长期感到自己的投入缺少反馈或价值确认时，更容易产生疏离和耗竭。",
      "source_content_ids": ["article_018", "asset_117"],
      "sources_collapsed_by_default": true
    }
  ]
}
```

#### 5.4.2 response_intro 形态：仅多分点总结
条件：
- 用户 query 未出现显式内容类型词
- answer_blocks.length >= 2
输出结构：
```json
{
  "response_intro": "知识库中与“职业倦怠”相关的内容主要集中在长期压力、恢复不足和意义感下降三个方向。",
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "长期压力累积",
      "content": "相关内容显示，职业倦怠通常与持续性的工作压力有关。它不是短期疲惫，而是压力长期得不到释放后的累积状态。",
      "source_content_ids": ["asset_101"],
      "sources_collapsed_by_default": true
    },
    {
      "title": "恢复不足",
      "content": "多条内容都提到，恢复不足会让疲惫不断延续。即使形式上离开了工作，如果注意力仍被工作占据，恢复效果也会被削弱。",
      "source_content_ids": ["asset_102"],
      "sources_collapsed_by_default": true
    },
    {
      "title": "意义感下降",
      "content": "知识库中的部分内容将职业倦怠与意义感下降联系在一起，认为缺少价值确认会加重个体的消耗感和疏离感。",
      "source_content_ids": ["article_018"],
      "sources_collapsed_by_default": true
    }
  ]
}
```

#### 5.4.3 response_intro 形态：仅信息源说明
条件：
- 用户 query 出现显式内容类型词
- answer_blocks.length = 1
输出结构：
```json
{
  "response_intro": "以下整理基于你保存的职业倦怠相关笔记。",
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "长期压力累积",
      "content": "当前知识库中的相关笔记主要把职业倦怠指向长期压力累积。它强调，倦怠不是简单的忙碌或一时疲惫，而是持续消耗、恢复不足和情绪负担叠加后的结果。",
      "source_content_ids": ["asset_101", "asset_102"],
      "sources_collapsed_by_default": false
    }
  ]
}
```

#### 5.4.4 response_intro 形态：response_intro 为空
条件：
- 用户 query 没有显式内容类型词
- answer_blocks.length = 1
输出结构：
```json
{
  "response_intro": null,
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "长期压力累积",
      "content": "知识库中与职业倦怠相关的内容主要集中在长期压力累积这一点上。它更像是一种持续消耗后的状态，而不是单次高强度工作带来的短暂疲惫。",
      "source_content_ids": ["asset_101"],
      "sources_collapsed_by_default": false
    }
  ]
}
```

## 6. 不同检索结果场景下各个知识与内容任务类型的输出形态
### 6.1 目标类型全部命中
条件：
- `task_type = content_locate`
- `kb_content_usable_for_answer = true`
- `missing_target_content_types = []`
- `normalized_results` 不为空

该场景表示：
- 当前不存在用户指定目标类型未命中的情况。
- `normalized_results` 中展示的是正常命中的结果。
- 当前结果实际包含哪些内容类型，由 `result_type_counts` 判断。

#### 6.1.1 content_locate 输出形态
`response_intro` 输出形态：
- 说明找到了与 `query_rewrite` 相关的内容。
- 根据`result_type_counts`说明命中的内容类型。
- 文案应保持简短，不展开解释。

示例 1：
用户 query：“有没有关于消费主义的笔记？”
```json
{
  "query_rewrite": "消费主义 笔记",
  "normalized_results": [
    {
      "result_type": "reading_asset",
      "asset_type": "linked_note"
    },
    {
      "result_type": "reading_asset",
      "asset_type": "standalone_note"
    }
  ]
}
```
response_intro："为你找到了消费主义相关的笔记："

示例 2：
用户 query：“消费主义相关内容”
```json
{
  "query_rewrite": "消费主义",
  "normalized_results": [
    {
      "result_type": "article"
    },
    {
      "result_type": "reading_asset",
      "asset_type": "highlight_only"
    },
    {
      "result_type": "reading_asset",
      "asset_type": "linked_note"
    }
  ]
}
```
response_intro："与消费主义相关的文章、划线和笔记如下："

除 `response_intro` 外的输出形态：遵循「3.2 输出结构与字段生成规则」

#### 6.1.2 explain 输出形态
`response_intro` 输出形态：
- 遵循 `4.3 response_intro 生成规则` 与 `4.4 explain 输出示例` 中定义的四种形态。
- 本场景为“目标类型全部命中”，因此如果触发“信息源说明”，只需要说明解释基于已命中的目标内容类型，不需要说明缺失类型或补充类型。

示例 1：
用户 query：“用我的笔记解释一下消费主义”
```json
{
  "target_content_types": ["note"],
  "missing_target_content_types": [],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 0,
    "note": 3
  }
}
```
answer_blocks.length >= 2
response_intro：“以下解释基于你保存的消费主义相关笔记，我会从身份表达、欲望制造和情绪补偿三个方面说明。”

示例 2：
```json
用户 query：“用我的笔记解释一下消费主义”
{
  "target_content_types": ["note"],
  "missing_target_content_types": [],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 0,
    "note": 1
  }
}
```
answer_blocks_length = 1
response_intro：“以下解释基于你保存的消费主义相关笔记。”

除 response_intro 外的输出形态：遵循「4.2 输出结构与字段生成规则」

#### 6.1.3 topic_explore 输出形态
`response_intro` 输出形态：
- 遵循 `5.3 response_intro 生成规则` 与 `5.4 topic_explore 输出示例` 中定义的四种形态。
- 本场景为“目标类型全部命中”，因此如果触发“信息源说明”，只需要说明主题整理基于已命中的目标内容类型，不需要说明缺失类型或补充类型。

示例 1：
用户 query：“整理一下我关于消费主义的笔记”
```json
{
  "target_content_types": ["note"],
  "missing_target_content_types": [],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 0,
    "note": 3
  }
}
```
answer_blocks.length >= 2
response_intro：“以下整理基于你保存的消费主义相关笔记，相关内容主要集中在身份表达、欲望制造和情绪补偿三个方向。”

示例 2：
用户 query：“整理一下我关于消费主义的笔记”
```json
{
  "target_content_types": ["note"],
  "missing_target_content_types": [],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 0,
    "note": 1
  }
}
```
answer_blocks.length = 1
response_intro：“以下整理基于你保存的消费主义相关笔记。”

除 response_intro 外的输出形态：遵循「5.2 输出结构与字段生成规则」

### 6.2 部分目标类型未命中
条件：
- `task_type = content_locate`
- `kb_content_usable_for_answer = true`
- `missing_target_content_types` 不为空
- `supplemental_content_types = []`
- `normalized_results` 不为空

该场景表示：
- `missing_target_content_types` 中的类型，是用户指定但未命中的目标类型。
- `target_content_types` 中不属于 `missing_target_content_types` 的类型，是已命中的目标类型。
- 当前 `normalized_results` 展示的是已命中的目标类型结果。
- `supplemental_content_types = []`，当前结果不包含补充类型结果。

#### 6.2.1 content_locate 输出形态
`response_intro` 输出形态：
- 如果用户 `query` 显式提到内容类型，则说明未命中类型`missing_target_content_types`未找到，根据`result_type_counts`说明已找到的目标类型。
- 如果用户 `query` 未显式提到内容类型，则不说明未命中类型`missing_target_content_types`，根据`result_type_counts`说明已找到的目标类型。
- 文案应保持简短，不展开解释。

示例 1：
用户 query：“有没有关于消费主义的划线和笔记”
```json
{
  "target_content_types": ["highlight", "note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 4,
    "note": 0
  }
}
```
response_intro：“为你找到了与消费主义相关的划线，但没有找到相关笔记：”

示例 2：
用户 query：“有没有关于消费主义的内容？”
```json
{
  "target_content_types": ["article", "highlight", "note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 2,
    "highlight": 4,
    "note": 0
  }
}
```
response_intro：“与消费主义相关的文章和划线如下：”

除 `response_intro` 外的输出形态：遵循「3.2 输出结构与字段生成规则」

#### 6.2.2 explain 输出形态
`response_intro` 输出形态：
- 遵循 `4.3 response_intro 生成规则` 与 `4.4 explain 输出示例` 中定义的四种形态。
- 本场景为“部分目标类型未命中”，因此如果触发“信息源说明”，需要说明用户指定但未命中的目标类型，并说明当前解释基于已命中的目标类型。

示例 1：
用户 query：“用我的划线和笔记解释一下消费主义”
```json
{
  "target_content_types": ["highlight", "note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 4,
    "note": 0
  }
}
```
answer_blocks.length >= 2
response_intro：“没有找到消费主义相关笔记，以下解释基于你保存的相关划线，我会从身份表达、欲望制造和情绪补偿三个方面说明。”

示例 2：
用户 query：“用我的划线和笔记解释一下消费主义”
```json
{
  "target_content_types": ["highlight", "note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 1,
    "note": 0
  }
}
```
answer_blocks.length = 1
response_intro：“没有找到消费主义相关笔记，以下解释基于你保存的相关划线。”

除 response_intro 外的输出形态：遵循「4.2 输出结构与字段生成规则」

#### 6.2.3 topic_explore 输出形态
`response_intro` 输出形态：
- 遵循 `5.3 response_intro 生成规则` 与 `5.4 topic_explore 输出示例` 中定义的四种形态。
- 本场景为“部分目标类型未命中”，因此如果触发“信息源说明”，需要说明用户指定但未命中的目标类型，并说明当前整理基于已命中的目标类型。

示例 1：
用户 query：“整理一下我关于消费主义的划线和笔记”
```json
{
  "target_content_types": ["highlight", "note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 4,
    "note": 0
  }
}
```
answer_blocks.length >= 2
response_intro：“没有找到消费主义相关笔记，以下整理基于你保存的相关划线，内容主要集中在身份表达、欲望制造和情绪补偿三个方向。”

示例 2：
用户 query：“整理一下我关于消费主义的划线和笔记”
```json
{
  "target_content_types": ["highlight", "note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": [],
  "result_type_counts": {
    "article": 0,
    "highlight": 1,
    "note": 0
  }
}
```
answer_blocks.length = 1
response_intro：“没有找到消费主义相关笔记，以下整理基于你保存的相关划线。”

除 response_intro 外的输出形态：遵循「5.2 输出结构与字段生成规则」


### 6.3 目标类型无结果，但补充类型有结果
条件：
- `task_type = content_locate`
- `kb_content_usable_for_answer = true`
- `missing_target_content_types` 不为空
- `supplemental_content_types` 不为空
- `normalized_results` 不为空

该场景表示：
- 该场景通常发生在用户 `query` 显式指定了某类内容类型，但该类型没有命中，而其他非目标类型有同主题相关内容。
- `supplemental_content_types` 中的类型，是系统找到的同主题补充内容类型。
- 当前 `normalized_results` 展示的是补充类型结果。
- 当前实际返回了哪些补充内容类型，由 `result_type_counts` 判断。

#### 6.3.1 content_locate 输出形态
`response_intro` 输出形态：
- 说明用户指定的未命中的目标类型 `missing_target_content_types` 未找到。
- 说明找到了哪些补充类型 `supplemental_content_types` 内容。

示例 1：
用户 query：“有没有关于消费主义的笔记？”
```json
{
  "target_content_types": ["note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": ["article", "highlight"],
  "result_type_counts": {
    "article": 2,
    "highlight": 5,
    "note": 0
  }
}
```
response_intro：“没有找到消费主义相关笔记，但为你找到了相关文章和划线：”

示例 2：
用户 query：“帮我找一下身份认同相关划线”
```json
{
  "target_content_types": ["highlight"],
  "missing_target_content_types": ["highlight"],
  "supplemental_content_types": ["article", "note"],
  "result_type_counts": {
    "article": 1,
    "highlight": 0,
    "note": 3
  }
}
```
response_intro：“知识库中没有身份认同相关划线，相关文章和笔记如下：”

除 `response_intro` 外的输出形态：遵循「3.2 输出结构与字段生成规则」

#### 6.3.2 explain 输出形态
`response_intro` 输出形态：
- 遵循 `4.3 response_intro 生成规则` 与 `4.4 explain 输出示例` 中定义的四种形态。
- 本场景为“目标类型无结果，但补充类型有结果”，因此如果触发“信息源说明”，需要说明用户指定的目标类型未找到，并说明当前解释基于同主题下命中的补充类型内容。

示例 1：
用户 query：“用我的笔记解释一下消费主义”
```json
{
  "target_content_types": ["note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": ["article", "highlight"],
  "result_type_counts": {
    "article": 2,
    "highlight": 5,
    "note": 0
  }
}
```
answer_blocks.length >= 2
response_intro：“没有找到消费主义相关笔记，以下解释基于知识库中找到的相关文章和划线，我会从身份表达、欲望制造和情绪补偿三个方面说明。”

示例 2：
用户 query：“用我的笔记解释一下消费主义”
```json
{
  "target_content_types": ["note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": ["article", "highlight"],
  "result_type_counts": {
    "article": 1,
    "highlight": 1,
    "note": 0
  }
}
```
answer_blocks.length = 1
response_intro：“没有找到消费主义相关笔记，以下解释基于知识库中找到的相关文章和划线。”

除 response_intro 外的输出形态：遵循「4.2 输出结构与字段生成规则」

#### 6.3.3 topic_explore 输出形态
`response_intro` 输出形态：
- 遵循 `5.3 response_intro 生成规则` 与 `5.4 topic_explore 输出示例` 中定义的四种形态。
- 本场景为“目标类型无结果，但补充类型有结果”，因此如果触发“信息源说明”，需要说明用户指定的目标类型未找到，并说明当前整理基于同主题下命中的补充类型内容。

示例 1：
用户 query：“整理一下我关于消费主义的笔记”
```json
{
  "target_content_types": ["note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": ["article", "highlight"],
  "result_type_counts": {
    "article": 2,
    "highlight": 5,
    "note": 0
  }
}
```
answer_blocks.length >= 2
response_intro：“没有找到消费主义相关笔记，以下整理基于知识库中找到的相关文章和划线，内容主要集中在身份表达、欲望制造和情绪补偿三个方向。”

示例 2：
用户 query：“整理一下我关于消费主义的笔记”
```json
{
  "target_content_types": ["note"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": ["article", "highlight"],
  "result_type_counts": {
    "article": 1,
    "highlight": 1,
    "note": 0
  }
}
```
answer_blocks.length = 1
response_intro：“没有找到消费主义相关笔记，以下整理基于知识库中找到的相关文章和划线。”

除 response_intro 外的输出形态：遵循「5.2 输出结构与字段生成规则」

### 6.4 所有类型均无结果
正常触发条件：
- `task_type = content_locate`
- `kb_content_usable_for_answer = false`

该场景表示：
- 轻量检索未发现与用户 query 相关的可用知识库内容线索。
- 系统未进入完整检索。

异常兜底条件：
- `task_type = content_locate`
- `kb_content_usable_for_answer = ture`
- `normalized_results` 为空

该场景表示：
- 轻量检索曾判断知识库中存在可用内容线索。
- 系统进入了完整检索，但完整检索、权限过滤、删除同步、结果归一化或聚合后，没有形成可展示的业务对象结果。

#### 6.4.1 content_locate 输出形态
`response_intro` 输出形态：
- 说明知识库内没有与用户 query 相关的内容。
- 本场景只生成 `response_intro`，其余输出字段皆为空。

示例 1：
用户 query：“有没有关于消费主义的笔记？”
```json
{
  "task_type": "content_locate",
  "kb_content_usable_for_answer": false
}
```
`response_intro`：“知识库中没有与消费主义相关的内容。”

示例 2：
用户 query：“有没有关于消费主义的笔记？”
```json
{
  "task_type": "content_locate",
  "kb_content_usable_for_answer": true,
  "normalized_results": []
}
```
`response_intro`：“知识库中没有与消费主义相关的内容。”

#### 6.4.2 explain 输出形态
`response_intro` 输出形态：
- 生成通用解释，并且通用解释只生成一个解释点，即 `answer_blocks.length = 1`，所以 `response_intro` 不生成多分点总结。
- `response_intro` 说明知识库中没有找到与用户 query 相关的内容，并且以下解释不来自用户知识库。
- 本场景下不生成知识库来源说明，不绑定来源卡片。
- 本场景下的 `answer_blocks` 承载通用解释正文，同时 `source_content_ids` 为空数组。

示例 1：
用户 query：“消费主义是什么？”
```json
{
  "task_type": "explain",
  "kb_content_usable_for_answer": false
}
输出结构：
{
  "response_intro": "知识库中没有找到与消费主义相关的内容，以下为通用解释，不来自你的知识库。",
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "核心含义",
      "content": "消费主义通常指一种将消费置于生活中心的价值取向。它不只是鼓励购买商品，也会把身份表达、生活方式和自我价值感与消费行为绑定在一起。",
      "source_content_ids": [],
      "sources_collapsed_by_default": false
    }
  ]
}
```

示例 2：
用户 query：“消费主义是什么？”
```json
{
  "task_type": "explain",
  "kb_content_usable_for_answer": true,
  "normalized_results": []
}
输出结构：
{
  "response_intro": "知识库中没有找到与消费主义相关的内容，以下为通用解释，不来自你的知识库。",
  "result_summary_blocks": [],
  "answer_blocks": [
    {
      "title": "核心含义",
      "content": "消费主义通常指一种以消费来组织欲望、身份和社会认同的观念。它会让购买行为超出满足基本需求的范围，转而承担表达自我、获得认同或缓解情绪的功能。",
      "source_content_ids": [],
      "sources_collapsed_by_default": false
    }
  ]
}
```

#### 6.4.3 topic_explore 输出形态
`response_intro` 输出形态：
- 说明知识库内没有与用户 query 相关的内容。
- 本场景只生成 `response_intro`，其余输出字段皆为空，不生成主题整理正文，不生成知识库来源说明，不绑定来源卡片。
- `response_intro` 用于说明知识库中没有找到与用户 query 相关的内容。

示例 1：
用户 query：“整理一下消费主义相关内容”
```json
{
  "task_type": "topic_explore",
  "kb_content_usable_for_answer": false
}
```
response_intro：“知识库中没有找到与消费主义相关的内容，暂时无法基于你的知识库进行整理。”

示例 2：
用户 query：“整理一下消费主义相关内容”
```json
{
  "task_type": "topic_explore",
  "kb_content_usable_for_answer": true,
  "normalized_results": []
}
response_intro：“知识库中没有找到与消费主义相关的内容，暂时无法基于你的知识库进行整理。”
```

## 7 非知识与内容任务输出策略
### 7.1 输出结构与字段生成规则
```json
{
  "response_intro": "",
  "result_summary_blocks": [],
  "answer_blocks": []
}
```

字段规则：
- `response_intro`：LLM 生成，用于承载非知识库检索任务的完整回复内容。
- `result_summary_blocks`：非知识库检索任务不使用，固定为空数组。
- `answer_blocks`：非知识库检索任务不使用，固定为空数组。

UI 渲染规则：
1. 前端只展示 response_intro。

### 7.1 product_help
`product_help` 用于回答用户关于当前 AI 搜索入口的能力、范围、使用方式、限制条件或结果含义的问题。
该类型只面向 AI 搜索入口本身，不回答整个 App 的通用操作说明，也不执行实际知识库检索。

条件：
- `task_type = product_help`

`response_intro` 输出形态： 
- 基于用户 query 说明当前 AI 搜索入口能做什么、不能做什么，或解释相关规则。

示例1:
用户 query：“这里可以搜索什么？”
输出结构：
```json
{
  "response_intro": "你可以在这里搜索自己知识库里的文章、划线和笔记，也可以围绕某个概念进行解释，或让系统整理某个主题下的相关内容。",
  "result_summary_blocks": [],
  "answer_blocks": []
}
```

示例2：
用户 query：“你能搜索互联网吗？”
输出结构：
```json
{
  "response_intro": "当前 AI 搜索入口只面向你的个人知识库，不搜索互联网内容。",
  "result_summary_blocks": [],
  "answer_blocks": []
}
```

### 7.2 out_of_scope
`out_of_scope` 用于处理闲聊、情绪表达、外部信息请求、外部服务请求，以及不属于当前 AI 搜索入口职责范围的输入。
这类输入没有知识库搜索目标，也不是在询问 AI 搜索入口的能力或使用方式。

条件：
- `task_type = out_of_scope`

`response_intro` 形态：
- 基于用户 query 说明说明当前请求不属于 AI 搜索模块能力范围，可以在必要时提示用户改为搜索知识库中的文章、划线、笔记或主题。

示例1：
用户 query：“东京天气怎么样？”
输出结构：
```json
{
  "response_intro": "当前 AI 搜索入口不查询实时天气。你可以在这里搜索自己知识库里的文章、划线和笔记。",
  "result_summary_blocks": [],
  "answer_blocks": []
}
```

示例2：
```json
用户 query：“帮我订一张机票。”
{
  "response_intro": "当前 AI 搜索入口不能处理订票等外部服务请求。你可以用它查找、解释或整理个人知识库中的内容。",
  "result_summary_blocks": [],
  "answer_blocks": []
}
```

### 7.3 unknown
unknown 用于处理无法稳定识别任务意图的输入。
这类输入通常没有明确对象、没有明确动作，也无法通过合理补全判断用户想查找、解释还是整理什么内容。

条件：
- `task_type = unknown`

`response_intro` 形态：
- 基于用户 query 提示未能识别明确的搜索对象或任务，提示用户补充更明确的对象或问题。

示例1：
用户 query：“这个”
输出结构：
```json
{
  "response_intro": "我还不能确定你想查找、解释还是整理什么内容。你可以补充一个具体主题、文章线索、划线或笔记关键词。",
  "result_summary_blocks": [],
  "answer_blocks": []
}
```

示例2：
用户 query：“有吗？”
输出结构：
```json
{
  "response_intro": "这个问题缺少明确对象，暂时无法判断要搜索什么。你可以直接输入想找的主题、文章、划线或笔记。",
  "result_summary_blocks": [],
  "answer_blocks": []
}
```