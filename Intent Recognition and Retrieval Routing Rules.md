# Step1 LLM-based Multi-dimensional Intent Recognition
## 任务类型 task_type
### 知识与内容任务
凡是用户输入包含可解析的知识对象、主题对象、概念对象或内容线索，均归入知识与内容任务，视为用户有知识库搜索意图。
#### 1. 内容定位 content_locate 
##### 1.0 意图描述
用户希望定位某个已存在于系统中的内容对象，包括文章、笔记、划线。
重点不是理解内容，而是回答：“它在哪里 / 有没有这个东西 / 我能不能找到它”
##### 1.1 典型提问示例
“我之前看过的消费主义那篇文章在哪？”
“帮我找一下关于泡泡玛特的笔记”
“有没有一条提到‘身份认同’的划线？”
“我保存过关于AI焦虑的内容吗？”
“消费主义”
##### 1.2 意图边界
- 属于该意图：
  - 用户记得部分线索（关键词 / 主题 / 模糊记忆）
  - 用户要找具体内容实体
  - 用户目标主要是“找出来”，不是“解释出来”
  - 用户未明确表达“查找动作”，但提供了明确或半明确的主题词/概念词/对象词，系统可推断为搜索知识库中相关内容，如：“消费主义”、“泡泡玛特”、“AI焦虑”、“好像有个消费主义”、“那个关于消费主义的东西”、“消费主义那个文章”等
- 不属于该意图：
  - “这篇文章讲了什么”
  - “消费主义是什么意思”
  - “帮我总结一下”
  - “我以前怎么理解这个问题”

#### 2. 解释 explain
##### 2.0 意图描述
用户明确要求理解、解释、定义、原因、机制、含义。
核心目标是：“它是什么 / 为什么 / 怎么理解”
##### 2.1 典型提问示例
“消费主义是什么？”
“什么是幸存者偏差？”
“这篇文章在说什么？”
“为什么消费会变成身份表达？”
“RAG 是什么原理？”
“我之前保存的消费主义是什么意思？”
##### 2.2 意图边界
- 属于该意图：
  - 要求解释“意义 / 原理 / 本质”
  - 对单一内容进行理解性提问
- 不属于该意图：
  - 多来源整合（主题探索）
  - 用户历史观点追溯（认知回顾）
  - 多内容对比（对比分析）
  - 找相似内容（相似发现）
关键区分：
explain = “理解一个点”
topic = “理解一个面”

#### 3. 主题探索 topic_explore
##### 3.0 意图描述
用户希望围绕一个主题，获得多内容整合后的结构化理解。
重点不是单点解释，而是：“这个主题在我知识库里整体是怎么被讨论的？”
##### 3.1 典型提问示例
“我关于消费主义都写了什么？”
“总结一下我知识库里的AI焦虑相关内容”
“我在品牌增长这个话题上有哪些不同观点？”
“帮我整理一下关于情绪价值的内容”
##### 3.2 意图边界
- 属于该意图：
  - 多篇文章/笔记共同参与
  - 需要归纳结构、分组、总结
  - 面向“主题全貌”
- 不属于该意图：
  - 单条内容解释（explain）
  - 用户自己观点变化（认知回顾）
  - 内容之间对比（对比分析）
关键区分：
topic = “这个主题整体是什么样的”
explain = “这个点是什么意思”

### 非知识与内容任务
凡是用户输入不包含可解析的知识/内容对象，或其目标是询问系统能力、闲聊、外部信息/服务请求、无法识别输入，则归入非知识与内容任务，视为用户没有知识库搜索意图。
#### 1. 闲聊与非职责范围请求 out_of_scope
##### 1.0 意图描述
用户输入不以查找、理解、整理、回顾、比较或分析内容为目标，而是发起日常互动、表达情绪，或提出当前 AI 搜索模块不承担的外部信息与泛服务请求。 
##### 1.1 典型提问示例
“你好。”
“你吃过饭了吗？”
“哈哈哈。”
“今天星期几？”
“东京天气怎么样？”
“最近有什么新闻？”
“帮我订一张机票。”
“给我讲个笑话。”
##### 1.2 意图边界
用户没有提出与文章、阅读资产、观点、主题或个人知识内容相关的明确任务。
用户的主要目的不是了解 AI 搜索入口本身的能力或使用方式；这类问题归入“产品使用或系统能力询问”。
用户虽然没有提到知识库，但提出了明确的概念、原理、现象或内容理解问题时，不属于本类型，例如“消费主义是什么”仍属于“解释”。
当前时间、天气、新闻等问题在语义上并非闲聊，但由于均不属于 MVP 中 AI 搜索的职责范围，可在本类型下统一处理。

#### 2. 产品使用或系统能力询问 product_help
##### 2.0 意图描述
用户希望了解当前 AI 搜索入口 的功能范围、可处理的问题、使用方式、限制条件或结果含义。该类型只覆盖 AI 搜索入口本身，不覆盖整个 App 的通用使用说明。
##### 2.1 典型提问示例
“这里可以搜索什么？”
“你能帮我找以前看过的文章吗？”
“你会搜索我的划线和笔记吗？”
“你能搜索互联网吗？”
“我可以在这里问概念问题吗？”
“为什么没有找到我想要的内容？”
“搜索结果里的文章和笔记有什么区别？”
“怎么让你只看我自己的笔记？”
##### 2.2 意图边界
用户关注的对象是AI 搜索入口的能力、范围、规则、限制或使用方法，而不是希望系统直接完成一次内容查询。
“你能不能找我以前关于消费主义的笔记？”若用户是在确认能力边界，属于本类型；“帮我找我以前关于消费主义的笔记”则属于“内容定位”。
“为什么这篇文章没有出现在搜索结果里？”属于本类型，因为重点是询问搜索机制或结果原因；“找那篇没有出现的文章”则属于内容定位。
整个产品的页面导航、阅读器操作、标签管理等使用问题不在本类型范围内；它仅面向 AI 搜索入口。

#### 3. 无法识别或无明确任务的输入 unknow
##### 3.0 意图描述
用户输入无法稳定识别为明确任务类型（内容定位 / 解释 / 主题探索等），且无法通过合理补全推断出具体操作对象或目标。
该类型仅包含：“没有明确对象 + 没有明确动作 + 无法补全语义结构”的输入，不包含任何可被识别为具体内容对象（即使未显式表达动作）的弱表达输入。
##### 3.1 典型提问示例
“这个”
“那个呢？”
“帮我看看”
“你觉得呢？”
“怎么样？”
“刚才那个”
“嗯？”
“有吗？”
“这个和那个呢？”
##### 3.2 意图边界
- 属于该意图：
  - 纯指代型输入（无对象），没有可解析对象：“这个”、“那个”、“刚才那个”、“这篇呢？”、“这个和那个还有刚才那个呢？”、“帮我看看这个那个哪个更好？”
  - 无动作 + 无对象（完全模糊），既没有“查/找/解释/对比”等动作，也没有对象：“怎么样？”、“你觉得呢？”、“有吗？”、“嗯？”、“好不好？”
- 不属于该意图：
  - 弱内容定位（必须识别为content_locate）：“消费主义”、“泡泡玛特”、“AI焦虑”、“好像有个消费主义”

## 目标内容类型 target_content_types
### 维度说明
target_content_types 用于判断用户 query 指向的检索目标内容类型。
该维度只依据用户 query 判断，不依赖轻量检索结果。它不判断知识库中是否存在相关内容，也不判断检索结果是否可用于回答；这些问题由其他维度或后续检索流程处理。
target_content_types 表达的是“搜索哪个内容字段/内容类型”，不等同于阅读资产的业务形态。
target_content_types 为数组结构，支持同时输出多个内容类型。

MVP 阶段支持的内容类型包括：
- article：搜索推文 / 文章实体
- highlight：搜索 ReadingAsset.highlight_text，即阅读资产中的划线文本 / 摘录 / 标注片段
- note：搜索 ReadingAsset.note_content，即阅读资产中的笔记内容 / 想法 / 观点沉淀

对应关系：
- 纯划线：可被 highlight 搜到；不会被 note 搜到
- 关联型笔记：可被 highlight 搜到它的划线部分；也可被 note 搜到它的笔记部分
- 独立型笔记：不会被 highlight 搜到；可被 note 搜到

核心原则：
阅读资产是统一实体；纯划线、关联型笔记、独立型笔记是它的三种形态。target_content_types 表达的是检索字段类型，不是阅读资产业务类型。

示例：
```json
{
  "target_content_types": ["article", "highlight", "note"]
}
```

### target_content_types = article
#### 意图描述
用户 query 明确指向文章、推文或完整阅读内容。
该类型关注的是系统推送或保存的完整文章实体，包括每日好文、往期推文、用户之前读过的文章、某篇文章、某篇推文等。

#### 典型提问示例
“我之前看过的消费主义那篇文章在哪？”
“帮我找一下泡泡玛特那篇文章”
“那篇关于身份认同的推文在哪？”
“我之前读过一篇关于长期主义的内容”
“有没有关于品牌增长的文章？”
“往期推文里有没有讲 AI 焦虑的？”
“那篇每日好文讲的是什么？”

#### 意图边界
- 属于该类型：
  - 用户明确提到文章、推文、那篇内容、每日好文、往期推文等完整内容对象。
  - 用户询问之前看过、读过、打开过或保存过的某篇完整内容。
  - 用户使用“那篇”“一篇”“文章”“推文”等表达，并且语义指向完整阅读对象。
- 不属于该类型：
  - 用户明确要找笔记、想法、观点或思考，应归入 note。
  - 用户明确要找划线、摘录、标注、某句话或某段原文，应归入 highlight。
  - 用户只输入主题词且未指定对象类型，应使用默认全部类型。

### target_content_types = highlight
#### 意图描述
用户 query 明确指向划线、摘录、标注片段、原文句子或原文段落。
该类型关注的是 ReadingAsset.highlight_text 字段，即用户从文章中保存下来的原文片段。它可以命中纯划线，也可以命中关联型笔记中绑定的划线内容。

#### 典型提问示例
“有没有一条提到身份认同的划线？”
“帮我找一下关于消费主义的摘录”
“我之前标注过长期主义这句话吗？”
“有没有关于情绪价值的原文片段？”
“找一下我划过的关于品牌增长的内容”
“有没有哪段原文提到 AI 焦虑？”
“帮我找那句关于消费和身份表达的话”

#### 意图边界
- 属于该类型：
  - 用户明确提到划线、摘录、标注、原文片段、某句话、某段内容。
  - 用户想找的是文章里的原文内容，而不是自己的笔记表达。
  - 用户描述“我划过的”“我摘录的”“我标注过的”等行为。
- 不属于该类型：
  - 用户明确要找自己的笔记、想法、观点或思考，应归入 note。
  - 用户明确要找完整文章或推文，应归入 article。
  - 用户只输入主题词且未指定对象类型，应使用默认全部类型。

### target_content_types = note
#### 意图描述
用户 query 明确指向笔记、想法、观点、思考、评论或个人表达。
该类型关注的是 ReadingAsset.note_content 字段，即用户在阅读过程中产生的主观认知沉淀。它可以命中关联型笔记中的笔记内容，也可以命中独立型笔记的笔记内容。

#### 典型提问示例
“帮我找一下关于泡泡玛特的笔记”
“我关于消费主义写过什么？”
“我在品牌增长这个话题上有什么观点？”
“有没有关于 AI 焦虑的想法？”
“找一下我写过的长期主义思考”
“我保存过关于情绪价值的笔记吗？”
“我之前怎么理解身份认同这个问题？”

#### 意图边界
- 属于该类型：
  - 用户明确提到笔记、想法、观点、思考、评论、记录等个人表达。
  - 用户询问“我写过什么”“我怎么看”“我有什么观点”等历史认知内容。
  - 用户要找的是自己的表达或总结，而不是原文片段或完整文章。
- 不属于该类型：
  - 用户明确要找完整文章或推文，应归入 article。
  - 用户明确要找原文划线、摘录或标注，应归入 highlight。
  - 用户只输入主题词且未指定对象类型，应使用默认全部类型。

### 多类型与默认规则
#### 意图描述
当用户 query 同时指向多个内容对象，或未明确指定目标内容类型时，target_content_types 应输出多个类型。
多类型输出用于表达用户希望搜索多个检索目标内容类型，或系统无法从 query 中收窄目标内容类型。该维度只负责检索目标内容类型判断，不负责判断这些内容是否真实存在。

#### 典型提问示例
“帮我找一下关于消费主义的文章和笔记”
target_content_types = ["article", "note"]
 
“有没有关于身份认同的划线和笔记？”
target_content_types = ["highlight", "note"]

“我关于品牌增长都保存过什么？”
target_content_types = ["article", "highlight", "note"]

“消费主义”
target_content_types = ["article", "highlight", "note"]

“AI 焦虑相关内容”
target_content_types = ["article", "highlight", "note"]

“这里可以搜索什么？”
target_content_types = []

“你好”
target_content_types = []

“这个”
target_content_types = []

#### 意图边界
- 属于多类型输出：
  - 用户同时提到多个对象类型，例如文章和笔记、划线和笔记。
  - 用户使用“内容”“资料”“保存过什么”“相关内容”等宽泛表达。
  - 用户只输入主题、概念或模糊线索，未指定文章、划线或笔记。
- 默认输出全部内容类型：
  - query 为明确主题词或内容线索，但没有指定对象类型。
  - 例如：“消费主义”“泡泡玛特”“AI 焦虑”“品牌增长相关内容”。
- 默认输出空数组：
  - task_type 为 product_help、out_of_scope 或 unknown。
  - 用户没有提出明确知识库内容对象检索目标。
- 不属于多类型输出：
  - 用户明确限定单一对象类型，例如“文章”“划线”“笔记”。
  - 用户虽然表达宽泛，但语义明显只指向某一类对象。




## 查询改写 query_rewrite
### 维度说明
query_rewrite 用于将用户原始 query 改写为适合知识库检索的规范化查询文本。
该字段只服务于检索，不直接展示给用户，也不作为最终回答内容。

query_rewrite 应结合以下信息生成：
- 用户原始 query
- task_type
- target_content_types

query_rewrite 不依赖轻量检索结果。

### 改写目标
query_rewrite 的目标是：
- 保留用户真正想找的核心对象、主题、概念或内容线索
- 去除不影响检索的口语化表达
- 在必要时补充内容类型词，帮助检索系统命中对应字段

### 改写规则
#### 1. 保留核心对象
保留用户 query 中的主题、概念、实体、文章线索或内容线索。

示例：
“我之前看过的消费主义那篇文章在哪？”
→ “消费主义 文章”

“有没有一条提到身份认同的划线？”
→ “身份认同 划线”

“我关于品牌增长有什么观点？”
→ “品牌增长 观点”

#### 2. 去除口语化表达
去除“帮我”“找一下”“有没有”“在哪”“是什么”“能不能”等对检索贡献较低的表达。

示例：
“帮我找一下关于泡泡玛特的笔记”
→ “泡泡玛特 笔记”

“能不能看看我有没有写过消费主义？”
→ “消费主义”

#### 3. 按 target_content_types 补充检索词
当用户明确指定目标内容类型时，可以在 query_rewrite 中保留或补充对应词：
- article：文章 / 推文
- highlight：划线 / 摘录 / 原文
- note：笔记 / 观点 / 想法 / 思考

示例：
target_content_types = ["note"]
“有没有关于消费主义的笔记”
→ “消费主义 笔记”

target_content_types = ["highlight"]
“找一下我划过的品牌增长”
→ “品牌增长 划线”

target_content_types = ["article", "highlight", "note"]
“消费主义”
→ “消费主义”

### 按 task_type 的默认处理
- content_locate：保留主题 + 内容类型线索
- explain：保留待解释的概念或内容对象
- topic_explore：保留主题，可保留“观点”“想法”等方向词
- product_help / out_of_scope / unknown：默认输出空字符串

### 输出格式
query_rewrite 输出字符串。

示例：
```json
{
  "query_rewrite": "消费主义 笔记"
}
```

无有效检索对象时：
```json
{
  "query_rewrite": ""
}
```

### 常见错误
- 原样复制用户 query，没有去除口语噪声
- 添加用户没有表达的新主题
- 写成完整回答句
- 对 product_help、out_of_scope、unknown 仍输出知识库检索词

# Step2 Availability Judgment of LLM Knowledge Base Content
## 知识库内容可用性 kb_content_usable_for_answer
### 维度说明
kb_content_usable_for_answer 用于判断轻量检索结果是否表明：知识库中存在可用于回答本次请求的相关内容。
该字段不在第一阶段意图识别中输出。第一阶段 LLM 只根据用户 query 输出 task_type、target_content_types 和 query_rewrite。

kb_content_usable_for_answer 在轻量检索完成后判断，判断时需要结合：
- 用户原始 query
- task_type
- target_content_types
- query_rewrite
- light_retrieval_type_distribution
- light_retrieval_candidates_summary

字段说明：
- light_retrieval_type_distribution：各内容类型下主题相关命中的数量分布。
- light_retrieval_candidates_summary：轻量检索候选结果摘要，用于辅助判断命中内容是否真的相关、是否存在噪声、是否足以支持回答。

本章节只说明这两个字段如何参与 kb_content_usable_for_answer 判断，不说明它们的生成方式。

该字段不判断用户是否具有搜索意图，也不等同于 target_content_types。它回答的是：当前轻量检索结果是否足以证明知识库内容可以用于后续完整检索和回答生成。

### kb_content_usable_for_answer = true
#### 意图描述
轻量检索结果中存在与用户请求相关的内容线索，且这些线索可以作为后续完整检索和回答生成的依据。
true 不代表轻量检索已经完整回答了问题，也不代表用户指定的目标类型一定有命中。它只表示：知识库中存在足够相关的内容，值得继续使用知识库内容。

#### 判断依据
- light_retrieval_type_distribution 显示至少一个内容类型存在主题相关命中。
- light_retrieval_candidates_summary 显示命中内容与 query 的核心对象、主题或概念相关。
- 命中内容不是偶然词面重合，而是能提供有效语义线索。
- 对 content_locate，命中结果中存在可展示、可定位或可补充说明的内容线索。
- 对 explain，命中结果中存在可支持解释的文章、划线或笔记内容。
- 对 topic_explore，至少存在一条明确相关内容，即可进入后续整理流程。
- 当用户指定的目标类型未命中，但其他内容类型存在同主题相关命中时，也可以判定为 true；后续输出必须说明目标类型未找到。

#### 典型判断示例
用户 query：“消费主义是什么？”
task_type：explain
target_content_types：["article", "highlight", "note"]
query_rewrite：“消费主义”
light_retrieval_type_distribution：{"article": 1, "highlight": 2, "note": 1}
light_retrieval_candidates_summary：
- article：一篇讨论消费主义与身份表达关系的文章
- highlight：一条提到消费主义如何影响身份认同的划线
- note：一条关于消费主义缓解身份焦虑的笔记
判断结果：kb_content_usable_for_answer = true
原因：知识库中存在可支持解释消费主义的相关文章、划线和笔记。

用户 query：“有没有关于消费主义的笔记？”
task_type：content_locate
target_content_types：["note"]
query_rewrite：“消费主义 笔记”
light_retrieval_type_distribution：{"article": 2, "highlight": 5, "note": 0}
light_retrieval_candidates_summary：
- article：两篇讨论消费主义与身份表达关系的文章
- highlight：多条提到消费主义和身份认同的划线
判断结果：kb_content_usable_for_answer = true
原因：虽然目标类型 note 未命中，但知识库中存在同主题相关内容，可用于后续补充返回。

用户 query：“我关于品牌增长有什么观点？”
task_type：topic_explore
target_content_types：["note"]
query_rewrite：“品牌增长 观点”
light_retrieval_type_distribution：{"article": 0, "highlight": 3, "note": 1}
light_retrieval_candidates_summary：
- note：一条品牌增长相关笔记
- highlight：三条品牌增长相关划线
判断结果：kb_content_usable_for_answer = true
原因：知识库中存在可用于整理品牌增长观点的相关内容。

#### 意图边界
- 属于 true：
  - light_retrieval_type_distribution 至少有一个内容类型存在有效命中。
  - light_retrieval_candidates_summary 显示命中内容与用户 query 的核心对象、主题或概念明确相关。
  - 轻量检索结果可以为回答提供事实依据、内容线索或完整检索入口。
  - 目标类型没有命中，但其他类型存在同主题相关内容。
  - 命中数量少但相关性明确。
- 不属于 true：
  - 各内容类型均无相关命中。
  - light_retrieval_candidates_summary 显示命中结果与 query 核心对象无关。
  - 命中结果只是孤立词语重合。
  - 命中结果明显是噪声。

### kb_content_usable_for_answer = false
#### 意图描述
轻量检索结果没有发现足够相关、足够可用的内容线索，不能支持本次请求基于知识库内容继续处理。
false 表示系统不应假装知识库中存在相关内容，也不应基于弱相关或噪声结果生成知识库答案。

#### 判断依据
- light_retrieval_type_distribution 显示所有内容类型均无相关命中。
- 或 light_retrieval_candidates_summary 显示命中内容与 query 的核心对象、主题或概念无关。
- 命中内容只是弱词面重合，无法提供有效语义线索。
- 命中内容过于边缘，不能支撑本次任务。
- 命中结果明显属于噪声，不应作为知识库回答依据。

#### 典型判断示例
用户 query：“有没有关于消费主义的笔记？”
task_type：content_locate
target_content_types：["note"]
query_rewrite：“消费主义 笔记”
light_retrieval_type_distribution：{"article": 0, "highlight": 0, "note": 0}
light_retrieval_candidates_summary：[]
判断结果：kb_content_usable_for_answer = false
原因：知识库中没有发现可用于回答消费主义相关请求的内容线索。

用户 query：“量子纠缠是什么？”
task_type：explain
target_content_types：["article", "highlight", "note"]
query_rewrite：“量子纠缠”
light_retrieval_type_distribution：{"article": 0, "highlight": 0, "note": 0}
light_retrieval_candidates_summary：[]
判断结果：kb_content_usable_for_answer = false
原因：知识库中没有发现可支持解释量子纠缠的相关内容。

用户 query：“我关于职业倦怠有什么观点？”
task_type：topic_explore
target_content_types：["note"]
query_rewrite：“职业倦怠 观点”
light_retrieval_type_distribution：{"article": 1, "highlight": 0, "note": 0}
light_retrieval_candidates_summary：
- article：一篇讨论职业教育的文章，仅包含“职业”一词
判断结果：kb_content_usable_for_answer = false
原因：命中结果只是弱词面重合，与职业倦怠主题无关。

#### 意图边界
- 属于 false：
  - light_retrieval_type_distribution 所有类型均为 0。
  - light_retrieval_candidates_summary 为空。
  - light_retrieval_candidates_summary 显示命中结果无法为本次回答提供有效上下文。
  - 轻量检索结果主要由噪声、误召回或弱词面重合构成。
- 不属于 false：
  - 命中结果较少但高度相关。
  - 用户指定类型未命中，但其他类型存在同主题相关内容。
  - 轻量检索只提供内容线索而非完整答案。

### 输出格式
kb_content_usable_for_answer 输出布尔值。

示例：
```json
{
  "kb_content_usable_for_answer": true
}
```

```json
{
  "kb_content_usable_for_answer": false
}
```

# Full Retrieval Strategy
## 维度定位
完整检索策略用于决定在知识库内容可用时，系统实际进入哪些内容类型中进行完整检索，并为后续输出生成提供必要上下文。
本章节不负责判断用户意图，也不负责判断知识库内容是否可用。

## 5.1 是否进入完整检索
是否进入完整检索只由 `kb_content_usable_for_answer` 控制。

```json
{
  "kb_content_usable_for_answer": true
}
```

表示轻量检索结果已经证明知识库中存在可用于回答本次请求的相关内容线索，系统应继续进入完整检索。

```json
{
  "kb_content_usable_for_answer": false
}
```

表示轻量检索结果不足以证明知识库中存在可用内容，系统不应继续执行完整检索。

## 5.2 内容类型派生规则
内容类型派生由系统规则层执行，不由 LLM 直接输出。

输入依据：
- `target_content_types`
- `light_retrieval_type_distribution`

输出结果：
- `full_retrieval_content_types`
- `missing_target_content_types`
- `supplemental_content_types`

其中：
- `full_retrieval_content_types`：完整检索实际要查的内容类型。
- `missing_target_content_types`：用户指定但轻量检索未命中的目标类型。
- `supplemental_content_types`：目标类型全部未命中时，用户未指定或非优先指定，但轻量检索证明同主题相关、可作为补充返回的内容类型。

### 5.2.1 目标类型有命中
如果 `target_content_types` 中至少有一个类型在 `light_retrieval_type_distribution` 中有命中，则完整检索只检索命中的目标类型。
MVP 阶段不额外补充其他和主题相关的内容类型。

示例：
```json
{
  "target_content_types": ["note"],
  "light_retrieval_type_distribution": {
    "article": 2,
    "highlight": 5,
    "note": 1
  }
}
```

派生结果：
```json
{
  "full_retrieval_content_types": ["note"],
  "missing_target_content_types": [],
  "supplemental_content_types": []
}
```

原因：
用户明确想找笔记，且轻量检索已经发现笔记命中，因此完整检索优先满足用户指定目标，不再补充检索文章或划线。

### 5.2.2 多个目标类型部分命中
如果用户指定多个目标类型，其中部分类型有命中，部分类型无命中，则完整检索只检索已命中的目标类型，并记录未命中的目标类型。

示例：
```json
{
  "target_content_types": ["article", "note"],
  "light_retrieval_type_distribution": {
    "article": 2,
    "highlight": 4,
    "note": 0
  }
}
```

派生结果：
```json
{
  "full_retrieval_content_types": ["article"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": []
}
```

原因：
用户指定的文章有命中，因此完整检索先满足已命中的目标类型；笔记未命中这一事实交给输出层说明。

### 5.2.3 目标类型无命中，但其他类型有命中
如果 `target_content_types` 中所有类型都没有命中，但其他内容类型存在同主题相关命中，则完整检索查询其他已命中的相关类型。

示例：
```json
{
  "target_content_types": ["note"],
  "light_retrieval_type_distribution": {
    "article": 2,
    "highlight": 5,
    "note": 0
  }
}
```

派生结果：
```json
{
  "full_retrieval_content_types": ["article", "highlight"],
  "missing_target_content_types": ["note"],
  "supplemental_content_types": ["article", "highlight"]
}
```

原因：
用户想找笔记，但知识库中没有同主题笔记命中；轻量检索证明文章和划线中存在同主题内容，因此可以完整检索文章和划线，并在输出时说明目标类型未找到。

补充说明：
在多个目标类型部分命中的情况下，即使其他非目标类型在轻量检索中也有主题相关命中，`supplemental_content_types` 仍为空数组。
示例：
```json
{
  "target_content_types": ["note", "article"],
  "light_retrieval_type_distribution": {
    "article": 0,
    "highlight": 5,
    "note": 2
  }
}
```

派生结果：
```json
{
  "full_retrieval_content_types": ["note"],
  "missing_target_content_types": ["article"],
  "supplemental_content_types": []
}
```
原因是：只要用户指定的目标类型中至少有一种已经命中，MVP 阶段完整检索优先满足已命中的目标类型，不额外引入用户未指定的内容类型。其他非目标类型命中只作为轻量检索事实存在，不进入完整检索，也不作为补充类型返回。
`supplemental_content_types` 不表示“轻量检索中所有非目标命中的类型”，而表示“目标类型全部未命中时，系统实际决定补充检索并返回的非目标内容类型”。

### 5.2.4 所有类型均无命中
如果 `light_retrieval_type_distribution` 中所有内容类型均无命中，则不应进入完整检索。

该情况通常应在上游第二阶段判断中得到：
```json
{
  "kb_content_usable_for_answer": false
}
```

因此本策略不再派生完整检索参数。

## 5.3 完整检索执行参数
完整检索真正使用的执行参数包括：
- `query_rewrite`
- `task_type`
- `full_retrieval_content_types`

示例：
```json
{
  "query_rewrite": "消费主义 笔记",
  "task_type": "content_locate",
  "full_retrieval_content_types": ["note"]
}
```

字段说明：
- `query_rewrite`：用于完整检索的查询文本。
- `task_type`：用于辅助完整检索结果组织和后续输出生成。
- `full_retrieval_content_types`：完整检索实际要查询的内容类型。

## 5.4 完整检索对象与范围
MVP 阶段完整检索范围为整个知识库。
完整检索对象包括：
- `article`：推文 / 文章实体。
- `highlight`：`ReadingAsset.highlight_text`。
- `note`：`ReadingAsset.note_content`。

阅读资产字段规则：
- 纯划线：可通过 `highlight` 命中。
- 关联型笔记：可通过 `highlight` 命中划线内容，也可通过 `note` 命中笔记内容。
- 独立型笔记：可通过 `note` 命中。

## 5.5 完整检索输出
完整检索输出正式搜索结果集合，供后续“排序与聚合”和“输出生成”使用。
完整检索输出不直接展示给用户。系统必须先对完整检索结果进行排序、去重和聚合，再进入最终输出生成。

### 5.5.1 输出结构
```json
{
  "retrieval_results": [
    {
      "content_type": "article",
      "content_id": "article_001",
      "title": "消费主义如何塑造身份认同",
      "matched_field": "title",
      "matched_text": "消费主义如何塑造身份认同",
      "relevance_score": 0.86,
      "source_article_id": null,
      "created_at": "2026-07-01",
      "updated_at": "2026-07-01"
    },
    {
      "content_type": "highlight",
      "content_id": "asset_023",
      "title": "消费主义如何塑造身份认同",
      "matched_field": "highlight_text",
      "matched_text": "消费主义不只是购买行为，也是一种身份表达方式。",
      "relevance_score": 0.81,
      "source_article_id": "article_001",
      "created_at": "2026-07-01",
      "updated_at": "2026-07-01"
    },
    {
      "content_type": "note",
      "content_id": "asset_024",
      "title": "消费主义如何塑造身份认同",
      "matched_field": "note_content",
      "matched_text": "我理解消费主义的核心，是用商品缓解身份焦虑。",
      "relevance_score": 0.78,
      "source_article_id": "article_001",
      "created_at": "2026-07-01",
      "updated_at": "2026-07-01"
    }
  ]
}
```

### 5.5.2 字段说明
- `retrieval_results`：完整检索返回的正式结果集合。
- `content_type`：结果类型，取值为 `article`、`highlight`、`note`。
- `content_id`：结果对应的业务实体 ID。`article` 对应推文 ID；`highlight` 和 `note` 对应 ReadingAsset ID。
- `title`：结果标题。`article` 使用推文标题；阅读资产结果可使用来源文章标题。
- `matched_field`：命中的字段。`article` 可为 `title` 或 `body`；`highlight` 为 `highlight_text`；`note` 为 `note_content`。
- `matched_text`：命中的文本片段或摘要。
- `relevance_score`：完整检索相关性分数，用于后续排序。
- `source_article_id`：阅读资产所属文章 ID。`article` 结果可为空。
- `created_at`：结果对象创建时间。
- `updated_at`：结果对象更新时间。

### 5.5.3 输出规则
- 完整检索只输出符合 `full_retrieval_content_types` 的结果。
- `article` 结果对应推文实体。
- `highlight` 和 `note` 结果对应 ReadingAsset 实体。
- 纯划线只可能以 `highlight` 类型返回。
- 关联型笔记可能以 `highlight` 类型命中划线内容，也可能以 `note` 类型命中笔记内容。
- 独立型笔记只可能以 `note` 类型返回。
- 同一个 ReadingAsset 如果同时命中 `highlight_text` 和 `note_content`，完整检索阶段可以先作为多条命中返回，后续由“排序与聚合”阶段合并为同一个阅读资产结果。
- 完整检索结果不负责生成最终文案，也不负责决定前端展示顺序；最终展示前必须经过后续排序、去重和聚合。

### 5.5.4 与后续步骤的关系
完整检索输出将传递给后续步骤：
- 排序与聚合：根据 `relevance_score`、`content_type`、时间和对象关系进行排序、去重与合并。
- 输出生成：根据 task_type、检索结果、`missing_target_content_types` 和 `supplemental_content_types` 生成 AI 总结、结果说明或兜底提示。

## 5.5 路由派生上下文的使用
`missing_target_content_types` 和 `supplemental_content_types` 主要供输出生成策略使用。

当 `missing_target_content_types` 不为空时，输出需要说明用户原本指定的内容类型没有找到。

当 `supplemental_content_types` 不为空时，输出需要说明当前返回的是同主题补充内容，而不是用户原本指定的目标类型。