# Project Constraints

## Cross-Session Collaboration

1. Project files are the shared synchronization layer; do not rely on chat history being available in another session. The formal cross-session handoff log is always `C:\Deep_Reading\docs\HANDOFF.md` in the main project checkout; a `docs\HANDOFF.md` file inside a Git worktree is only that worktree's branch copy, not the formal handoff channel.

2. At the start of any session, read this file, `docs/PROJECT_STATE.md`, `C:\Deep_Reading\docs\HANDOFF.md`, and the canonical documents relevant to the assigned workstream. Before ending a session, update its status or handoff entry when there is a material change.

3. `PROJECT_STATE.md` is a status index and cross-domain decision log. It does not replace domain documents. `PRD.md` is the source of truth for product rules; the UX design document and approved Figma source file are the source of truth for UX and visual delivery; technical design documents are the source of truth for technical constraints.

4. The 项目集成与决策 (Main / Integration) session owns cross-domain integration and is the only session allowed to mark a cross-domain decision as confirmed. Prototype / Design and Tech sessions record proposals, risks, and open questions rather than silently changing confirmed decisions.

5. Parallel exploration is allowed, but a canonical document may have only one active editing session at a time. Within confirmed product rules and the assigned design scope, the Prototype / Design session may directly and frequently update the UX design document, Figma pages, and prototype links. Only changes that alter a confirmed business rule, data lifecycle, cross-module behavior, technical constraint, or the approved design scope must be recorded in `docs/HANDOFF.md` and reviewed by the 项目集成与决策 session.

6. `C:\Deep_Reading\docs\HANDOFF.md` is the default channel for cross-session handoff and pending decisions. Sessions working from a Git worktree must append formal handoff records to that exact root path, not to their worktree copy. Do not send a thread message for every pending item. Use `send_message_to_thread` only when an item blocks the current core path, materially changes a confirmed business rule, data lifecycle, or technical interface, requires a decision before design freeze, or when the 项目集成与决策 session explicitly requests real-time notification. When several non-blocking items exist, batch them in one handoff entry and send at most one notification for that batch.

7. A completed or frozen design scope does not imply that the entire application is designed. `PROJECT_STATE.md` must state the exact covered scope of each design freeze. After an approved post-freeze design change, repeat the required Figma version history, local copy, and Ready for dev sequence.

8. File ownership:
   - 项目集成与决策 owns `AGENTS.md`, `docs/PROJECT_STATE.md`, `PRD.md`, the AI search rule documents, and other cross-domain rule documents. It also maintains the structure and resolution status of `docs/HANDOFF.md`.
   - Prototype / Design owns the UX design document, the Figma source file, and prototype links.
   - Tech owns technical design documents and technical supporting documents.
   - All sub-sessions may directly modify only their owned files and may append to the root formal log at `C:\Deep_Reading\docs\HANDOFF.md` according to the handoff rules. A worktree copy of `docs/HANDOFF.md` must not be treated as authoritative.
   - Sub-sessions must not directly modify `PRD.md`, `docs/PROJECT_STATE.md`, or another workstream's canonical documents unless 项目集成与决策 explicitly authorizes the change.
   - To request a change to a file outside the session's ownership, record the reason, impact, and recommended change in `docs/HANDOFF.md` for the file owner or 项目集成与决策 to handle.

## Subagent 等待与关闭规则

所有新建的 subagent 必须显式使用 `gpt-5.6-luna`，并将推理强度设为高。恢复既有 subagent 时，必须确认其原始模型与推理强度同样为 `gpt-5.6-luna` 和高；否则关闭后以该配置新建。

时间从 subagent 的“上一次有效进展”开始计算，而不是从创建时开始计算。

有效进展包括：
- subagent 状态回复；
- 新增或修改代码、文件或测试；
- 测试、编译、静态分析产生结果；
- 产生新的提交；
- 明确说明正在修复某个问题。

处理规则：
- **仍在运行且有持续进展、有代码、文件或测试变化**：继续等待，即使暂时没有提交。编译、测试或修复失败都可能需要较长时间。
- **20 分钟内没有验证结果、提交、状态更新或文件进展**：主 agent 先暂停并询问用户，由用户决定是否继续等待、关闭或替换 subagent。
- **明确卡在错误、循环或环境问题上**：可以提前暂停并询问用户；经用户确认后，关闭当前 subagent，并交给新的 `gpt-5.6-luna` 高推理强度 subagent 继续。

核心原则是：不因未提交代码而关闭，只在持续无进展时考虑暂停、关闭或替换。

1. Before discussing any UX decision, first: locate the relevant PRD section; read its business rules, interaction description, and exceptions; inspect the referenced flow/prototype; check cross-module entries and cited documents; extract established rules and direct implications; ask the user only about a genuine gap, conflict, or experience trade-off.

2. During the UX/design phase, preserve confirmed PRD rules and do not generate implementation code until the design is approved.

3. Design freeze and Figma delivery: perform design freeze in the existing Figma source file, not in a duplicate file. For every approved named design version: (a) create or update the named version through **Save to Version History**; (b) immediately use **Save local copy** and save it to `C:\Deep_Reading\Figma UX Version Local Copy`; (c) keep the development-delivery Frames organized in a named Section; (d) mark that Section **Ready for dev** after the version and local copy are saved; and (e) record the version name, date, Figma link, and local-copy filename in the UX design document. After any post-freeze change, repeat the same version → local copy → Ready for dev sequence.
