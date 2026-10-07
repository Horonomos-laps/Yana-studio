// SPDX-FileCopyrightText: 2026 Vũ Văn Tâm
// SPDX-License-Identifier: Apache-2.0

use std::time::{SystemTime, UNIX_EPOCH};

use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

use crate::{
    domain::{Activity, ActivityState, Message, PlanStep, Role, RuntimeInfo, ScopedFile},
    engines::{
        approval::ApprovalMode, command::UiCommand, notification::NoticeLevel,
        workflow::WorkflowState, UiEngines,
    },
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Overlay {
    Scope,
    Plan,
    Approval,
    Memory,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SidebarTab {
    Activity,
    Workflow,
    Memory,
    Compose,
    Provider,
    Approval,
}

impl SidebarTab {
    pub const ALL: [SidebarTab; 6] = [
        SidebarTab::Activity,
        SidebarTab::Workflow,
        SidebarTab::Memory,
        SidebarTab::Compose,
        SidebarTab::Provider,
        SidebarTab::Approval,
    ];

    pub fn next(self) -> Self {
        match self {
            SidebarTab::Activity => SidebarTab::Workflow,
            SidebarTab::Workflow => SidebarTab::Memory,
            SidebarTab::Memory => SidebarTab::Compose,
            SidebarTab::Compose => SidebarTab::Provider,
            SidebarTab::Provider => SidebarTab::Approval,
            SidebarTab::Approval => SidebarTab::Activity,
        }
    }

    pub fn prev(self) -> Self {
        match self {
            SidebarTab::Activity => SidebarTab::Approval,
            SidebarTab::Workflow => SidebarTab::Activity,
            SidebarTab::Memory => SidebarTab::Workflow,
            SidebarTab::Compose => SidebarTab::Memory,
            SidebarTab::Provider => SidebarTab::Compose,
            SidebarTab::Approval => SidebarTab::Provider,
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            SidebarTab::Activity => "Activity",
            SidebarTab::Workflow => "Workflow",
            SidebarTab::Memory => "Memory",
            SidebarTab::Compose => "Compose",
            SidebarTab::Provider => "Provider",
            SidebarTab::Approval => "Approval",
        }
    }

    pub fn index(self) -> usize {
        match self {
            SidebarTab::Activity => 0,
            SidebarTab::Workflow => 1,
            SidebarTab::Memory => 2,
            SidebarTab::Compose => 3,
            SidebarTab::Provider => 4,
            SidebarTab::Approval => 5,
        }
    }
}

pub struct App {
    pub messages: Vec<Message>,
    pub activities: Vec<Activity>,
    pub plan: Vec<PlanStep>,
    pub scope: Vec<ScopedFile>,
    pub runtime: RuntimeInfo,
    pub input: String,
    pub status: String,
    pub sidebar_tab: SidebarTab,
    pub overlay: Option<Overlay>,
    pub should_quit: bool,
    pub engines: UiEngines,
}

impl App {
    pub fn demo() -> Self {
        let mut engines = UiEngines::default();
        engines.context_view.sync(4, true, 1_200);
        engines.layout.set_sidebar(true);
        let provider_model = engines.provider.current().model.clone();
        Self {
            messages: vec![
                Message {
                    role: Role::System,
                    content: format!(
                        "Yana Terminal AI v0.1.0 · {} UI engines ready · Mock Bridge connected. Type /help to inspect commands.",
                        UiEngines::COUNT
                    ),
                    timestamp: timestamp(),
                },
                Message {
                    role: Role::User,
                    content: "Thiết kế lại toàn bộ Terminal UI theo phong cách Antigravity / Claude Code / Warp, hỗ trợ 6 tab Sidebar và auto-grow Composer.".into(),
                    timestamp: timestamp(),
                },
                Message {
                    role: Role::Assistant,
                    content: "Tôi đã tái thiết kế toàn diện giao diện dòng lệnh cho Yana AI theo UI_REWRITE_SPEC:\n\n[Thinking]\n• Phân tách rõ rệt giữa Terminal Client và Yana Core theo kiến trúc Bridge.\n• Xây dựng 6 tab Sidebar chuyển đổi mượt mà bằng phím Tab.\n• Transcript hiển thị tách biệt SYSTEM, YOU, YANA kèm khối Thinking và Tool Diff.\n• Composer co giãn tự động, hiển thị đầy đủ pills trạng thái.\n\n[Tool: patch_workspace src/ui/mod.rs]\n--- a/src/ui/mod.rs\n+++ b/src/ui/mod.rs\n@@ -1,40 +1,80 @@\n+ pub fn render_modern_transcript(frame: &mut Frame, area: Rect, app: &App)\n+ pub fn render_sidebar_tabs(frame: &mut Frame, area: Rect, app: &App)\n+ pub fn render_composer_box(frame: &mut Frame, area: Rect, app: &App)\n+ pub fn render_overlays(frame: &mut Frame, area: Rect, app: &App)\n\nTất cả thành phần đã hoàn tất. Bạn có thể gõ lệnh hoặc bấm phím tắt để trải nghiệm!".into(),
                    timestamp: timestamp(),
                },
            ],
            activities: vec![
                Activity {
                    label: "UI engines registered".into(),
                    detail: format!("{} engines active", UiEngines::COUNT),
                    state: ActivityState::Done,
                },
                Activity {
                    label: "Context view".into(),
                    detail: engines.context_view.summary(),
                    state: ActivityState::Done,
                },
                Activity {
                    label: "Runtime boundary".into(),
                    detail: "mock bridge only · client clean".into(),
                    state: ActivityState::Done,
                },
            ],
            plan: vec![
                PlanStep {
                    title: "Chat + Composer surface (auto-grow)".into(),
                    done: true,
                    active: false,
                },
                PlanStep {
                    title: "6 Tabbed Sidebar navigation".into(),
                    done: true,
                    active: false,
                },
                PlanStep {
                    title: "High-contrast Antigravity aesthetic".into(),
                    done: true,
                    active: true,
                },
                PlanStep {
                    title: "Bridge contract to Yana Core".into(),
                    done: false,
                    active: false,
                },
            ],
            scope: vec![
                ScopedFile {
                    path: "src/app/mod.rs".into(),
                    confidence: 98,
                    lines: 280,
                    selected: true,
                },
                ScopedFile {
                    path: "src/engines/".into(),
                    confidence: 96,
                    lines: 600,
                    selected: true,
                },
                ScopedFile {
                    path: "src/ui/mod.rs".into(),
                    confidence: 95,
                    lines: 480,
                    selected: true,
                },
                ScopedFile {
                    path: "docs/UI_REWRITE_SPEC.md".into(),
                    confidence: 99,
                    lines: 190,
                    selected: true,
                },
            ],
            runtime: RuntimeInfo {
                model: provider_model,
            },
            input: String::new(),
            status: format!("{} UI engines online · Ready", UiEngines::COUNT),
            sidebar_tab: SidebarTab::Activity,
            overlay: None,
            should_quit: false,
            engines,
        }
    }

    pub fn handle_key(&mut self, key: KeyEvent) {
        if key.modifiers.contains(KeyModifiers::CONTROL) {
            match key.code {
                KeyCode::Char('c') => self.should_quit = true,
                KeyCode::Char('s') => self.toggle_overlay(Overlay::Scope),
                KeyCode::Char('p') => self.toggle_overlay(Overlay::Plan),
                KeyCode::Char('e') => {
                    self.sidebar_tab = SidebarTab::Memory;
                    self.toggle_overlay(Overlay::Memory);
                }
                KeyCode::Char('a') => {
                    self.sidebar_tab = SidebarTab::Approval;
                    self.toggle_overlay(Overlay::Approval);
                }
                _ => {}
            }
            return;
        }

        match key.code {
            KeyCode::Esc => {
                if self.overlay.is_some() {
                    self.overlay = None;
                } else {
                    self.should_quit = true;
                }
            }
            KeyCode::Tab => {
                if self.overlay == Some(Overlay::Approval) {
                    self.engines.approval.cycle();
                    self.status = format!("Approval: {}", self.engines.approval.current().label());
                } else {
                    self.sidebar_tab = self.sidebar_tab.next();
                    self.status = format!("Tab: {}", self.sidebar_tab.label());
                }
            }
            KeyCode::BackTab => {
                self.sidebar_tab = self.sidebar_tab.prev();
                self.status = format!("Tab: {}", self.sidebar_tab.label());
            }
            KeyCode::Enter => {
                if self.overlay.is_some() {
                    self.overlay = None;
                } else {
                    self.submit_input();
                }
            }
            KeyCode::Backspace => {
                self.input.pop();
                self.engines.composer.sync(&self.input);
            }
            KeyCode::Char(character) if self.overlay.is_none() => {
                self.input.push(character);
                self.engines.composer.sync(&self.input);
            }
            _ => {}
        }
    }

    pub fn toggle_overlay(&mut self, overlay: Overlay) {
        self.overlay = if self.overlay == Some(overlay) {
            None
        } else {
            Some(overlay)
        };
    }

    fn submit_input(&mut self) {
        let prompt = self.input.trim().to_owned();
        if prompt.is_empty() {
            return;
        }

        self.input.clear();
        self.engines.composer.clear();

        if let Some(command) = self.engines.command.parse(&prompt) {
            self.execute_command(command);
            return;
        }

        self.engines.workflow.transition(WorkflowState::Planning);
        self.messages.push(Message {
            role: Role::User,
            content: prompt.clone(),
            timestamp: timestamp(),
        });
        self.engines.chat.record_submission();
        self.engines.storage.mark_dirty();

        self.engines.workflow.transition(WorkflowState::Running);
        self.engines.compose_stage.advance();
        self.engines.workflow.transition(WorkflowState::Review);
        self.engines.compose_stage.advance();
        self.engines.workflow.transition(WorkflowState::Testing);
        self.engines.compose_stage.advance();

        let assistant_reply = format!(
            "Tôi đã tiếp nhận chỉ thị và xử lý qua Mock Bridge:\n\n[Thinking]\n• Phân tích yêu cầu: {}\n• Trạng thái Giám Thị: [{}]\n• Chuyển trạng thái Workflow: Planning -> Running -> Review -> Testing -> Done\n\n[Tool: execute_step]\n+ apply_intent(prompt: {})\n+ status: completed without error\n\nQuá trình xử lý giao diện hoàn tất. Yana Core sẽ tiếp quản logic qua API/Bridge.",
            prompt,
            self.engines.approval.current().label(),
            prompt
        );

        self.messages.push(Message {
            role: Role::Assistant,
            content: assistant_reply,
            timestamp: timestamp(),
        });
        self.engines.workflow.transition(WorkflowState::Done);
        self.engines.compose_stage.advance();
        self.engines.notification.push(
            NoticeLevel::Success,
            format!("Prompt #{} rendered", self.engines.chat.submitted()),
        );
        self.activities.push(Activity {
            label: "Prompt completed".into(),
            detail: format!("prompt #{} · mock bridge", self.engines.chat.submitted()),
            state: ActivityState::Done,
        });
        self.status = "Ready · Prompt completed".into();
    }

    fn execute_command(&mut self, command: UiCommand) {
        match command {
            UiCommand::Help => self.system_message(
                "/help  /engines  /clear  /new  /provider <name>  /approval <auto|ask|never>  /search <text>  /attach <path>  /theme  /render  /save",
            ),
            UiCommand::Engines => self.system_message(&format!(
                "{} UI engines: {}",
                UiEngines::COUNT,
                UiEngines::names().join(", ")
            )),
            UiCommand::Clear => {
                self.messages.clear();
                self.status = "Transcript cleared".into();
            }
            UiCommand::NewSession => {
                self.engines.session.new_session();
                self.messages.clear();
                let message = format!(
                    "Started {} (id {}).",
                    self.engines.session.title(),
                    self.engines.session.id()
                );
                self.system_message(&message);
                self.status = "New session".into();
            }
            UiCommand::Provider(name) => {
                if name.is_empty() {
                    let labels = self.engines.provider.labels().collect::<Vec<_>>().join(", ");
                    self.system_message(&format!("Providers: {labels}"));
                } else {
                    match self.engines.provider.select(&name) {
                        Ok(profile) => {
                            self.runtime.model = profile.model.clone();
                            self.status = format!("Provider: {}", profile.name);
                        }
                        Err(error) => self.warn(error),
                    }
                }
            }
            UiCommand::Approval(name) => {
                if name.is_empty() {
                    let labels = ApprovalMode::ALL
                        .iter()
                        .map(|mode| mode.label())
                        .collect::<Vec<_>>()
                        .join(", ");
                    self.system_message(&format!("Approval modes: {labels}"));
                } else {
                    match self.engines.approval.select(&name) {
                        Ok(mode) => self.status = format!("Approval: {}", mode.label()),
                        Err(error) => self.warn(error),
                    }
                }
            }
            UiCommand::Search(query) => {
                let count = self.engines.search.search(&self.messages, &query);
                self.system_message(&format!("Search \"{}\": {} match(es).", query, count));
                self.status = format!("Search: {count} matches");
            }
            UiCommand::Attach(path) => match self.engines.attachment.attach(&path) {
                Ok(()) => {
                    self.system_message(&format!("Attached workspace path: {path}"));
                    self.status = format!(
                        "{} attachment(s)",
                        self.engines.attachment.pending().len()
                    );
                }
                Err(error) => self.warn(error),
            },
            UiCommand::Theme => {
                self.engines.theme.toggle();
                let message = format!(
                    "Theme switched to {:?}. UI palette wiring remains intentionally local.",
                    self.engines.theme.current()
                );
                self.system_message(&message);
            }
            UiCommand::Render => {
                self.engines.render.toggle();
                let message = format!("Render mode: {:?}.", self.engines.render.mode());
                self.system_message(&message);
            }
            UiCommand::Save => {
                self.engines.storage.checkpoint(self.messages.len());
                let message = format!(
                    "UI checkpoint recorded for {} messages (in-memory MVP).",
                    self.engines.storage.saved_messages()
                );
                self.system_message(&message);
                self.status = "Checkpoint clean".into();
            }
            UiCommand::Unknown(name) => self.warn(format!("Unknown command /{name}. Type /help.")),
        }
    }

    fn system_message(&mut self, content: &str) {
        self.messages.push(Message {
            role: Role::System,
            content: content.into(),
            timestamp: timestamp(),
        });
        self.engines
            .notification
            .push(NoticeLevel::Info, content.to_owned());
    }

    fn warn(&mut self, content: impl Into<String>) {
        let content = content.into();
        self.messages.push(Message {
            role: Role::System,
            content: format!("Warning: {content}"),
            timestamp: timestamp(),
        });
        self.engines
            .notification
            .push(NoticeLevel::Warning, content.clone());
        self.status = content;
    }
}

fn timestamp() -> String {
    let seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
        % 86_400;
    let hours = seconds / 3_600;
    let minutes = (seconds % 3_600) / 60;
    let seconds = seconds % 60;
    format!("{hours:02}:{minutes:02}:{seconds:02}")
}
