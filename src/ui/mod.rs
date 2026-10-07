// SPDX-FileCopyrightText: 2026 Vũ Văn Tâm
// SPDX-License-Identifier: Apache-2.0

use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Clear, List, ListItem, Paragraph, Wrap},
    Frame,
};

use crate::{
    app::{App, Overlay, SidebarTab},
    domain::{ActivityState, Role},
    engines::{
        agent::AgentRole, approval::ApprovalMode, compose_stage::ComposeStage,
        workflow::WorkflowState,
    },
};

const CYAN: Color = Color::Rgb(76, 201, 240);
const PURPLE: Color = Color::Rgb(183, 130, 255);
const GREEN: Color = Color::Rgb(107, 203, 119);
const YELLOW: Color = Color::Rgb(244, 196, 91);
const RED: Color = Color::Rgb(255, 107, 107);
const MUTED: Color = Color::Rgb(150, 165, 180);
const PANEL: Color = Color::Rgb(38, 46, 58);
const CARD_BG: Color = Color::Rgb(24, 30, 42);

pub fn draw(frame: &mut Frame, app: &App) {
    let area = frame.area();
    let composer_height = estimate_composer_height(app, area.width);
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(8),
            Constraint::Length(composer_height),
            Constraint::Length(1),
        ])
        .split(area);

    render_header(frame, rows[0], app);
    render_body(frame, rows[1], app);
    render_composer(frame, rows[2], app);
    render_status(frame, rows[3], app);

    if let Some(overlay) = app.overlay {
        render_overlay(frame, area, app, overlay);
    }
}

fn render_header(frame: &mut Frame, area: Rect, app: &App) {
    let workspace = env!("CARGO_PKG_NAME");
    let provider_name = app.engines.provider.current().name.clone();
    let model = app.runtime.model.clone();
    let session_id = app.engines.session.id();
    let msg_count = app.messages.len();

    let header_lines = vec![
        Line::from(vec![
            Span::styled(
                " YANA AI ",
                Style::default()
                    .fg(Color::Black)
                    .bg(CYAN)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                "  Terminal Workspace",
                Style::default()
                    .fg(Color::White)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::styled("  ·  ", Style::default().fg(PANEL)),
            Span::styled("● ONLINE", Style::default().fg(GREEN)),
            Span::styled("  ·  Mock Bridge (", Style::default().fg(MUTED)),
            Span::styled(
                if app.engines.provider.current().local {
                    "LOCAL"
                } else {
                    "REMOTE"
                },
                Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
            ),
            Span::styled(")  ·  v0.1.0", Style::default().fg(MUTED)),
            Span::styled(
                format!("                    Session #{session_id} · {msg_count} msgs"),
                Style::default().fg(MUTED),
            ),
        ]),
        Line::from(vec![
            Span::styled(format!(" [ {workspace} ] "), Style::default().fg(PURPLE)),
            Span::styled("· Provider: ", Style::default().fg(MUTED)),
            Span::styled(
                format!("{provider_name} ({model})"),
                Style::default().fg(Color::White),
            ),
            Span::styled("  · Context: ", Style::default().fg(MUTED)),
            Span::styled(
                app.engines.context_view.summary(),
                Style::default().fg(YELLOW),
            ),
            Span::styled("  · Approval: ", Style::default().fg(MUTED)),
            Span::styled(
                format!("[{}]", app.engines.approval.current().label()),
                Style::default().fg(GREEN),
            ),
            Span::styled("  · State: ", Style::default().fg(MUTED)),
            Span::styled(
                app.engines.workflow.state().label(),
                Style::default().fg(CYAN),
            ),
        ]),
    ];

    let header = Paragraph::new(header_lines).block(
        Block::default()
            .borders(Borders::BOTTOM)
            .border_style(Style::default().fg(PANEL)),
    );

    frame.render_widget(header, area);
}

fn render_body(frame: &mut Frame, area: Rect, app: &App) {
    let show_sidebar = area.width >= 100;
    let columns = if show_sidebar {
        Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Min(58), Constraint::Length(44)])
            .split(area)
    } else {
        Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(100)])
            .split(area)
    };

    render_transcript(frame, columns[0], app);
    if show_sidebar {
        render_sidebar(frame, columns[1], app);
    }
}

fn render_transcript(frame: &mut Frame, area: Rect, app: &App) {
    let mut items = Vec::new();

    for message in &app.messages {
        let (role_label, role_color, prefix_icon) = match message.role {
            Role::User => ("YOU", GREEN, "❯"),
            Role::Assistant => ("YANA", CYAN, "◈"),
            Role::System => ("SYSTEM", YELLOW, "ℹ"),
        };

        // Header line
        let header_line = Line::from(vec![
            Span::styled(
                format!("╭── {prefix_icon} {role_label} "),
                Style::default().fg(role_color).add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("────────────────────────────── [{}] ──╮", message.timestamp),
                Style::default().fg(PANEL),
            ),
        ]);

        let mut lines = vec![header_line];

        // Format message lines with rich syntax
        for line in message.content.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("[Thinking]") {
                lines.push(Line::from(vec![
                    Span::styled("│ ", Style::default().fg(PANEL)),
                    Span::styled(
                        "💭 THINKING PROCESS:",
                        Style::default()
                            .fg(PURPLE)
                            .add_modifier(Modifier::BOLD | Modifier::ITALIC),
                    ),
                ]));
            } else if trimmed.starts_with("[Tool")
                || trimmed.starts_with("---")
                || trimmed.starts_with("+++")
            {
                lines.push(Line::from(vec![
                    Span::styled("│ ", Style::default().fg(PANEL)),
                    Span::styled(
                        format!("⚙ {line}"),
                        Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
                    ),
                ]));
            } else if trimmed.starts_with('+') && !trimmed.starts_with("+++") {
                lines.push(Line::from(vec![
                    Span::styled("│ ", Style::default().fg(PANEL)),
                    Span::styled(
                        "+ ",
                        Style::default().fg(GREEN).add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(&trimmed[1..], Style::default().fg(GREEN)),
                ]));
            } else if trimmed.starts_with('-') && !trimmed.starts_with("---") {
                lines.push(Line::from(vec![
                    Span::styled("│ ", Style::default().fg(PANEL)),
                    Span::styled("- ", Style::default().fg(RED).add_modifier(Modifier::BOLD)),
                    Span::styled(&trimmed[1..], Style::default().fg(RED)),
                ]));
            } else if trimmed.starts_with("@@") {
                lines.push(Line::from(vec![
                    Span::styled("│ ", Style::default().fg(PANEL)),
                    Span::styled(line, Style::default().fg(PURPLE)),
                ]));
            } else if trimmed.starts_with('•') || trimmed.starts_with('*') {
                lines.push(Line::from(vec![
                    Span::styled("│   ", Style::default().fg(PANEL)),
                    Span::styled("• ", Style::default().fg(CYAN)),
                    Span::styled(
                        &trimmed[trimmed.find(' ').map(|i| i + 1).unwrap_or(1)..],
                        Style::default().fg(Color::White),
                    ),
                ]));
            } else {
                lines.push(Line::from(vec![
                    Span::styled("│ ", Style::default().fg(PANEL)),
                    Span::styled(line, Style::default().fg(Color::White)),
                ]));
            }
        }

        // Footer line
        lines.push(Line::from(Span::styled(
            "╰─────────────────────────────────────────────────────────────────╯",
            Style::default().fg(PANEL),
        )));
        lines.push(Line::from(""));

        items.push(ListItem::new(lines));
    }

    let transcript = List::new(items).block(
        Block::default()
            .title(" 💬 Conversation Transcript ")
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(PANEL)),
    );
    frame.render_widget(transcript, area);
}

fn render_sidebar(frame: &mut Frame, area: Rect, app: &App) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(6)])
        .split(area);

    render_sidebar_tab_bar(frame, rows[0], app);
    render_sidebar_content(frame, rows[1], app);
}

fn render_sidebar_tab_bar(frame: &mut Frame, area: Rect, app: &App) {
    let mut spans = vec![
        Span::styled(
            " Tab ⇆ ",
            Style::default().fg(PURPLE).add_modifier(Modifier::BOLD),
        ),
        Span::raw(" "),
    ];

    for tab in SidebarTab::ALL {
        let is_active = tab == app.sidebar_tab;
        let num = tab.index() + 1;
        let label = tab.label();

        if is_active {
            spans.push(Span::styled(
                format!("[{num}.{label}] "),
                Style::default()
                    .fg(Color::Black)
                    .bg(CYAN)
                    .add_modifier(Modifier::BOLD),
            ));
        } else {
            spans.push(Span::styled(
                format!("{num}.{label} "),
                Style::default().fg(MUTED),
            ));
        }
    }

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(PANEL));

    let p = Paragraph::new(Line::from(spans)).block(block);
    frame.render_widget(p, area);
}

fn render_sidebar_content(frame: &mut Frame, area: Rect, app: &App) {
    match app.sidebar_tab {
        SidebarTab::Activity => render_activity(frame, area, app),
        SidebarTab::Workflow => render_workflow_panel(frame, area, app),
        SidebarTab::Memory => render_memory_panel(frame, area, app),
        SidebarTab::Compose => render_compose_panel(frame, area, app),
        SidebarTab::Provider => render_provider_panel(frame, area, app),
        SidebarTab::Approval => render_approval_panel(frame, area, app),
    }
}

fn render_activity(frame: &mut Frame, area: Rect, app: &App) {
    let items = app
        .activities
        .iter()
        .rev()
        .take(area.height.saturating_sub(2) as usize)
        .map(|activity| {
            let (symbol, color) = match activity.state {
                ActivityState::Running => ("◇ Running", CYAN),
                ActivityState::Done => ("✓ Done", GREEN),
                ActivityState::Warning => ("⚠ Warn", YELLOW),
            };
            ListItem::new(vec![
                Line::from(vec![
                    Span::styled(
                        format!("[{symbol}] "),
                        Style::default().fg(color).add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        &activity.label,
                        Style::default()
                            .fg(Color::White)
                            .add_modifier(Modifier::BOLD),
                    ),
                ]),
                Line::from(vec![
                    Span::styled("    detail: ", Style::default().fg(MUTED)),
                    Span::styled(&activity.detail, Style::default().fg(Color::White)),
                ]),
            ])
        })
        .collect::<Vec<_>>();

    frame.render_widget(
        List::new(items).block(
            Block::default()
                .title(" 📋 Activity Log · Tab ")
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(PANEL)),
        ),
        area,
    );
}

fn render_workflow_panel(frame: &mut Frame, area: Rect, app: &App) {
    let current = app.engines.workflow.state();
    let current_index = WorkflowState::ALL
        .iter()
        .position(|state| *state == current)
        .unwrap_or(0);

    let mut items = vec![ListItem::new(Line::from(Span::styled(
        "── Pipeline Stages ──",
        Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
    )))];

    for (index, state) in WorkflowState::ALL.iter().enumerate() {
        let (symbol, color, status_text) = if index < current_index {
            ("✓", GREEN, "[Completed]")
        } else if index == current_index {
            ("●", CYAN, "[ACTIVE]")
        } else {
            ("·", MUTED, "[Pending]")
        };

        items.push(ListItem::new(Line::from(vec![
            Span::styled(
                format!("  {symbol} "),
                Style::default().fg(color).add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("{:<12}", state.label()),
                Style::default().fg(if index == current_index {
                    Color::White
                } else {
                    MUTED
                }),
            ),
            Span::styled(status_text, Style::default().fg(color)),
        ])));
    }

    items.push(ListItem::new(Line::from("")));
    items.push(ListItem::new(Line::from(Span::styled(
        "── Multi-Agent Team ──",
        Style::default().fg(PURPLE).add_modifier(Modifier::BOLD),
    ))));

    let active_role = app.engines.agent.active_agent(current);
    for role in AgentRole::ALL {
        let active = role == active_role;
        let (marker, color, status_text) = if active {
            ("●", GREEN, "[Leading]")
        } else {
            ("·", MUTED, "[Standby]")
        };
        items.push(ListItem::new(Line::from(vec![
            Span::styled(format!("  {marker} "), Style::default().fg(color)),
            Span::styled(
                format!("{:<12}", role.label()),
                Style::default().fg(if active { Color::White } else { MUTED }),
            ),
            Span::styled(status_text, Style::default().fg(color)),
        ])));
    }

    frame.render_widget(
        List::new(items).block(
            Block::default()
                .title(" ⚡ Workflow & Agents · Tab ")
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(PANEL)),
        ),
        area,
    );
}

fn render_compose_panel(frame: &mut Frame, area: Rect, app: &App) {
    let current = app.engines.compose_stage.current();
    let current_index = ComposeStage::ALL
        .iter()
        .position(|stage| *stage == current)
        .unwrap_or(0);

    let stage_descriptions = [
        "Analyze intent & construct task plan",
        "Produce code edits & patch files",
        "Inspect diffs, syntax & security invariants",
        "Run unit tests & compiler check",
        "Update session state in working memory",
    ];

    let mut items = vec![ListItem::new(Line::from(Span::styled(
        format!("── Compose Pipeline ({}/5) ──", current_index + 1),
        Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
    )))];

    for (index, stage) in ComposeStage::ALL.iter().enumerate() {
        let (symbol, color) = if index < current_index {
            ("✓", GREEN)
        } else if index == current_index {
            ("›", CYAN)
        } else {
            ("·", MUTED)
        };

        items.push(ListItem::new(vec![
            Line::from(vec![
                Span::styled(
                    format!("  {symbol} "),
                    Style::default().fg(color).add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    stage.label(),
                    Style::default()
                        .fg(if index == current_index {
                            Color::White
                        } else {
                            MUTED
                        })
                        .add_modifier(Modifier::BOLD),
                ),
            ]),
            Line::from(vec![
                Span::styled("    ", Style::default()),
                Span::styled(stage_descriptions[index], Style::default().fg(MUTED)),
            ]),
        ]));
    }

    frame.render_widget(
        List::new(items).block(
            Block::default()
                .title(" ✍ Compose Stages · Tab ")
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(PANEL)),
        ),
        area,
    );
}

fn render_memory_panel(frame: &mut Frame, area: Rect, app: &App) {
    let memory = &app.engines.memory;
    let sections: [(&str, &[&str]); 5] = [
        ("◈ Recent Evidence", memory.recent_evidence()),
        ("◈ Timeline", memory.timeline()),
        ("◈ Known Entities", memory.entities()),
        ("◈ Related Artifacts", memory.related()),
        ("◈ Retrieved Context", memory.retrieved()),
    ];

    let mut lines = Vec::new();
    lines.push(Line::from(Span::styled(
        "── Zero-Memory Architecture ──",
        Style::default().fg(PURPLE).add_modifier(Modifier::BOLD),
    )));

    for (title, items) in sections {
        lines.push(Line::from(Span::styled(
            title,
            Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
        )));
        for item in items {
            lines.push(Line::from(vec![
                Span::styled("  · ", Style::default().fg(MUTED)),
                Span::styled(*item, Style::default().fg(Color::White)),
            ]));
        }
    }

    frame.render_widget(
        Paragraph::new(lines).wrap(Wrap { trim: false }).block(
            Block::default()
                .title(" 🧠 Zero Memory · Ctrl+E ")
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(PANEL)),
        ),
        area,
    );
}

fn render_provider_panel(frame: &mut Frame, area: Rect, app: &App) {
    let current_name = app.engines.provider.current().name.clone();
    let mut items = vec![ListItem::new(Line::from(Span::styled(
        "── LLM Provider Registry ──",
        Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
    )))];

    for profile in app.engines.provider.profiles() {
        let is_active = profile.name == current_name;
        let (marker, color, badge) = if is_active {
            ("●", GREEN, "[ACTIVE]")
        } else {
            ("·", MUTED, "[Ready]")
        };

        items.push(ListItem::new(vec![
            Line::from(vec![
                Span::styled(
                    format!("  {marker} "),
                    Style::default().fg(color).add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    &profile.name,
                    Style::default()
                        .fg(if is_active { Color::White } else { MUTED })
                        .add_modifier(Modifier::BOLD),
                ),
                Span::raw("  "),
                Span::styled(badge, Style::default().fg(color)),
            ]),
            Line::from(vec![
                Span::styled("    Model: ", Style::default().fg(MUTED)),
                Span::styled(&profile.model, Style::default().fg(Color::White)),
                Span::styled(
                    if profile.local {
                        " · Local host"
                    } else {
                        " · Cloud API"
                    },
                    Style::default().fg(MUTED),
                ),
            ]),
        ]));
    }

    items.push(ListItem::new(Line::from("")));
    items.push(ListItem::new(Line::from(Span::styled(
        "Tip: /provider <name> switches active backend",
        Style::default().fg(MUTED),
    ))));

    frame.render_widget(
        List::new(items).block(
            Block::default()
                .title(" 🔌 Providers · Tab ")
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(PANEL)),
        ),
        area,
    );
}

fn render_approval_panel(frame: &mut Frame, area: Rect, app: &App) {
    let current = app.engines.approval.current();
    let mut items = vec![ListItem::new(Line::from(Span::styled(
        "── Giám Thị Guard Modes ──",
        Style::default().fg(YELLOW).add_modifier(Modifier::BOLD),
    )))];

    for mode in ApprovalMode::ALL {
        let active = mode == current;
        let (marker, color, badge) = if active {
            ("●", GREEN, "[ACTIVE]")
        } else {
            ("·", MUTED, "[Standby]")
        };

        items.push(ListItem::new(vec![
            Line::from(vec![
                Span::styled(
                    format!("  {marker} "),
                    Style::default().fg(color).add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    mode.label(),
                    Style::default()
                        .fg(if active { Color::White } else { MUTED })
                        .add_modifier(Modifier::BOLD),
                ),
                Span::raw("  "),
                Span::styled(badge, Style::default().fg(color)),
            ]),
            Line::from(vec![
                Span::styled("    ", Style::default()),
                Span::styled(mode.description(), Style::default().fg(MUTED)),
            ]),
        ]));
    }

    items.push(ListItem::new(Line::from("")));
    items.push(ListItem::new(Line::from(Span::styled(
        "── Invariant Policy ──",
        Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
    ))));
    items.push(ListItem::new(Line::from(vec![
        Span::styled("  • Workspace Reads:  ", Style::default().fg(MUTED)),
        Span::styled("ALLOWED", Style::default().fg(GREEN)),
    ])));
    items.push(ListItem::new(Line::from(vec![
        Span::styled("  • Workspace Writes: ", Style::default().fg(MUTED)),
        Span::styled("REQUIRES APPROVAL", Style::default().fg(YELLOW)),
    ])));
    items.push(ListItem::new(Line::from(vec![
        Span::styled("  • Shell Commands:   ", Style::default().fg(MUTED)),
        Span::styled("REQUIRES APPROVAL", Style::default().fg(YELLOW)),
    ])));
    items.push(ListItem::new(Line::from("")));
    items.push(ListItem::new(Line::from(Span::styled(
        "Tip: Press Ctrl+A or /approval <mode> to cycle",
        Style::default().fg(MUTED),
    ))));

    frame.render_widget(
        List::new(items).block(
            Block::default()
                .title(" 🛡 Approval Guard · Ctrl+A ")
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(PANEL)),
        ),
        area,
    );
}

fn stream_label(app: &App) -> &'static str {
    if !app.input.is_empty() {
        return "Typing…";
    }
    match app.engines.workflow.state() {
        WorkflowState::Planning => "Waiting…",
        WorkflowState::Running | WorkflowState::Review | WorkflowState::Testing => "Streaming…",
        WorkflowState::Done => "Ready",
    }
}

fn estimate_composer_height(app: &App, width: u16) -> u16 {
    let input_len = app.input.chars().count();
    let inner_width = width.saturating_sub(4).max(20) as usize;
    let input_lines = (input_len + inner_width - 1) / inner_width;
    // 1 line pills + input lines + 1 line footer + 2 border rows
    (input_lines.max(1) as u16 + 4).clamp(5, 8)
}

fn render_composer(frame: &mut Frame, area: Rect, app: &App) {
    let provider_name = app.engines.provider.current().name.clone();
    let approval = app.engines.approval.current().label();
    let attachments = app.engines.attachment.pending().len();
    let scope_files = app.scope.len();

    // Line 1: Status pills
    let mut pill_spans = vec![
        Span::styled(
            format!(" [Provider: {provider_name}] "),
            Style::default()
                .fg(Color::Black)
                .bg(PURPLE)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(" "),
        Span::styled(
            format!(" [Approval: {approval}] "),
            Style::default()
                .fg(Color::Black)
                .bg(YELLOW)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(" "),
        Span::styled(" [Mode: Interactive] ", Style::default().fg(CYAN).bg(PANEL)),
        Span::raw(" "),
        Span::styled(
            " [Zero-Memory: Active] ",
            Style::default().fg(GREEN).bg(PANEL),
        ),
        Span::raw(" "),
        Span::styled(
            format!(" [{scope_files} files scoped] "),
            Style::default().fg(Color::White).bg(PANEL),
        ),
    ];
    if attachments > 0 {
        pill_spans.push(Span::raw(" "));
        pill_spans.push(Span::styled(
            format!(" [+{attachments} attachments] "),
            Style::default().fg(GREEN),
        ));
    }

    // Line 2: Prompt input
    let mut input_spans = vec![Span::styled(
        "› ",
        Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
    )];
    if app.input.is_empty() {
        input_spans.push(Span::styled(
            "Ask Yana anything or type /help, /provider, /approval, /clear...",
            Style::default().fg(MUTED),
        ));
    } else {
        input_spans.push(Span::styled(
            app.input.clone(),
            Style::default()
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        ));
        input_spans.push(Span::styled("█", Style::default().fg(CYAN)));
    }

    // Line 3: Info & tokens
    let info_line = Line::from(vec![
        Span::styled(
            format!(
                "  Status: {}  ·  Model: {}",
                stream_label(app),
                app.runtime.model
            ),
            Style::default().fg(MUTED),
        ),
        Span::styled(
            "                                  Context: 1,200 / 128,000 tokens ",
            Style::default().fg(MUTED),
        ),
    ]);

    let lines = vec![
        Line::from(pill_spans),
        Line::from(""),
        Line::from(input_spans),
        Line::from(""),
        info_line,
    ];

    let border_color = if !app.input.is_empty() { CYAN } else { PANEL };

    let composer = Paragraph::new(lines).block(
        Block::default()
            .title(" ⌨ Composer · Enter to send ")
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(border_color)),
    );

    frame.render_widget(composer, area);
}

fn render_status(frame: &mut Frame, area: Rect, app: &App) {
    let status_line = Line::from(vec![
        Span::styled(
            " Ctrl+P ",
            Style::default().fg(PURPLE).add_modifier(Modifier::BOLD),
        ),
        Span::styled("Plan  ", Style::default().fg(MUTED)),
        Span::styled(
            "Ctrl+S ",
            Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
        ),
        Span::styled("Scope  ", Style::default().fg(MUTED)),
        Span::styled(
            "Ctrl+E ",
            Style::default().fg(GREEN).add_modifier(Modifier::BOLD),
        ),
        Span::styled("Memory  ", Style::default().fg(MUTED)),
        Span::styled(
            "Ctrl+A ",
            Style::default().fg(YELLOW).add_modifier(Modifier::BOLD),
        ),
        Span::styled("Approval  ", Style::default().fg(MUTED)),
        Span::styled(
            "Tab ",
            Style::default()
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        ),
        Span::styled("Sidebar  ", Style::default().fg(MUTED)),
        Span::styled(
            "Esc ",
            Style::default().fg(RED).add_modifier(Modifier::BOLD),
        ),
        Span::styled("Quit", Style::default().fg(MUTED)),
        Span::styled("   │   ", Style::default().fg(PANEL)),
        Span::styled(
            &app.status,
            Style::default().fg(GREEN).add_modifier(Modifier::BOLD),
        ),
        Span::styled("   │   ", Style::default().fg(PANEL)),
        Span::styled(
            format!(
                "session #{} · {} · {}",
                app.engines.session.id(),
                app.sidebar_tab.label(),
                app.engines.workflow.state().label()
            ),
            Style::default().fg(MUTED),
        ),
    ]);

    frame.render_widget(Paragraph::new(status_line), area);
}

fn render_overlay(frame: &mut Frame, area: Rect, app: &App, overlay: Overlay) {
    let popup = centered_rect(72, 70, area);
    frame.render_widget(Clear, popup);

    match overlay {
        Overlay::Scope => {
            let mut lines = vec![
                Line::from(Span::styled(
                    "SMART SCOPE CONTEXT INSPECTOR",
                    Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
                )),
                Line::from(Span::styled(
                    "Context is locked to targeted files to prevent prompt bloating.",
                    Style::default().fg(MUTED),
                )),
                Line::from(""),
            ];
            for file in &app.scope {
                let marker = if file.selected { "✓" } else { "·" };
                lines.push(Line::from(vec![
                    Span::styled(
                        format!("  {marker} "),
                        Style::default().fg(GREEN).add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        &file.path,
                        Style::default()
                            .fg(Color::White)
                            .add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        format!(
                            "   ({}% confidence · {} lines)",
                            file.confidence, file.lines
                        ),
                        Style::default().fg(MUTED),
                    ),
                ]));
            }
            lines.push(Line::from(""));
            lines.push(Line::from(Span::styled(
                "Press Enter or Esc to close overlay",
                Style::default().fg(YELLOW),
            )));

            frame.render_widget(
                Paragraph::new(lines).block(
                    Block::default()
                        .title(" 🔍 Scope Inspector (Ctrl+S) ")
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .border_style(Style::default().fg(CYAN)),
                ),
                popup,
            );
        }
        Overlay::Plan => {
            let mut lines = vec![
                Line::from(Span::styled(
                    "PLAN TRACKER & EXECUTION ROADMAP",
                    Style::default().fg(PURPLE).add_modifier(Modifier::BOLD),
                )),
                Line::from(""),
            ];

            for (index, step) in app.plan.iter().enumerate() {
                let (symbol, color, label) = if step.done {
                    ("✓", GREEN, "[DONE]")
                } else if step.active {
                    ("●", CYAN, "[IN PROGRESS]")
                } else {
                    ("·", MUTED, "[PENDING]")
                };
                lines.push(Line::from(vec![
                    Span::styled(
                        format!("  {symbol} "),
                        Style::default().fg(color).add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        format!("{}. {:<36}", index + 1, step.title),
                        Style::default().fg(if step.active { Color::White } else { MUTED }),
                    ),
                    Span::styled(label, Style::default().fg(color)),
                ]));
            }

            lines.push(Line::from(""));
            lines.push(Line::from(Span::styled(
                "Press Enter or Esc to close overlay",
                Style::default().fg(YELLOW),
            )));

            frame.render_widget(
                Paragraph::new(lines).block(
                    Block::default()
                        .title(" 📋 Plan Tracker (Ctrl+P) ")
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .border_style(Style::default().fg(PURPLE)),
                ),
                popup,
            );
        }
        Overlay::Approval => {
            let current = app.engines.approval.current();
            let mut lines = vec![
                Line::from(Span::styled(
                    "GIÁM THỊ APPROVAL MODAL",
                    Style::default().fg(YELLOW).add_modifier(Modifier::BOLD),
                )),
                Line::from(Span::styled(
                    "Control tool execution safety and autonomy levels for Yana agents.",
                    Style::default().fg(MUTED),
                )),
                Line::from(""),
            ];

            for mode in ApprovalMode::ALL {
                let is_active = mode == current;
                let (marker, color, status) = if is_active {
                    ("●", GREEN, "[ACTIVE]")
                } else {
                    ("·", MUTED, "[Standby]")
                };
                lines.push(Line::from(vec![
                    Span::styled(
                        format!("  {marker} "),
                        Style::default().fg(color).add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(
                        format!("{:<8}", mode.label()),
                        Style::default()
                            .fg(if is_active { Color::White } else { MUTED })
                            .add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(status, Style::default().fg(color)),
                ]));
                lines.push(Line::from(vec![
                    Span::styled("      ", Style::default()),
                    Span::styled(mode.description(), Style::default().fg(MUTED)),
                ]));
                lines.push(Line::from(""));
            }

            lines.push(Line::from(Span::styled(
                "Press Tab to cycle mode · Enter or Esc to close overlay",
                Style::default().fg(YELLOW),
            )));

            frame.render_widget(
                Paragraph::new(lines).block(
                    Block::default()
                        .title(" 🛡 Giám Thị Approval Settings (Ctrl+A) ")
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .border_style(Style::default().fg(YELLOW)),
                ),
                popup,
            );
        }
        Overlay::Memory => {
            let memory = &app.engines.memory;
            let mut lines = vec![
                Line::from(Span::styled(
                    "ZERO-MEMORY WORKING CONTEXT INSPECTOR",
                    Style::default().fg(GREEN).add_modifier(Modifier::BOLD),
                )),
                Line::from(Span::styled(
                    "Grounded session memory without LLM halluncination or vector database overhead.",
                    Style::default().fg(MUTED),
                )),
                Line::from(""),
            ];

            lines.push(Line::from(Span::styled(
                "Recent Evidence:",
                Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
            )));
            for ev in memory.recent_evidence() {
                lines.push(Line::from(vec![
                    Span::styled("  • ", Style::default().fg(MUTED)),
                    Span::styled(*ev, Style::default().fg(Color::White)),
                ]));
            }
            lines.push(Line::from(""));

            lines.push(Line::from(Span::styled(
                "Timeline:",
                Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
            )));
            for tl in memory.timeline() {
                lines.push(Line::from(vec![
                    Span::styled("  • ", Style::default().fg(MUTED)),
                    Span::styled(*tl, Style::default().fg(Color::White)),
                ]));
            }
            lines.push(Line::from(""));

            lines.push(Line::from(Span::styled(
                "Entities & Artifacts:",
                Style::default().fg(CYAN).add_modifier(Modifier::BOLD),
            )));
            for en in memory.entities() {
                lines.push(Line::from(vec![
                    Span::styled("  • ", Style::default().fg(MUTED)),
                    Span::styled(*en, Style::default().fg(Color::White)),
                ]));
            }

            lines.push(Line::from(""));
            lines.push(Line::from(Span::styled(
                "Press Enter or Esc to close overlay",
                Style::default().fg(YELLOW),
            )));

            frame.render_widget(
                Paragraph::new(lines).block(
                    Block::default()
                        .title(" 🧠 Zero Memory Inspector (Ctrl+E) ")
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .border_style(Style::default().fg(GREEN)),
                ),
                popup,
            );
        }
    }
}

fn centered_rect(percent_x: u16, percent_y: u16, area: Rect) -> Rect {
    let vertical = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(area);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(vertical[1])[1]
}

#[cfg(test)]
mod tests {
    use super::*;
    use ratatui::backend::TestBackend;
    use ratatui::Terminal;

    #[test]
    fn test_ui_draw_all_tabs_and_overlays() {
        let backend = TestBackend::new(120, 36);
        let mut terminal = Terminal::new(backend).unwrap();
        let mut app = App::demo();

        for tab in SidebarTab::ALL {
            app.sidebar_tab = tab;
            terminal.draw(|f| draw(f, &app)).unwrap();
        }

        let overlays = [
            Overlay::Scope,
            Overlay::Plan,
            Overlay::Approval,
            Overlay::Memory,
        ];
        for overlay in overlays {
            app.overlay = Some(overlay);
            terminal.draw(|f| draw(f, &app)).unwrap();
        }
        app.overlay = None;

        // Narrow terminal
        let backend_narrow = TestBackend::new(80, 24);
        let mut terminal_narrow = Terminal::new(backend_narrow).unwrap();
        terminal_narrow.draw(|f| draw(f, &app)).unwrap();
    }
}
