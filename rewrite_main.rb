path = "macos/LettersApp/Sources/LettersApp/MainEditorView.swift"
content = File.read(path)

# 1. Top Navigation Bar Replacement
old_top_bar = /HStack\(spacing: 12\) \{\s+\/\/ Left Island Sidebar Toggle Button.*?\.help\("Open Command Center \(⌘K\)"\)\s+\}\s+\}/m

new_top_bar = <<-SWIFT
HStack(spacing: 16) {
                // Left Island Sidebar Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showIslandSidebar.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(showIslandSidebar ? .accentColor : .primary.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(showIslandSidebar ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                        .symbolEffect(.bounce, value: showIslandSidebar)
                }
                .buttonStyle(.plain)
                .help("Toggle Instruments Toolbar (⌥⌘1)")

                // Document Title
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))

                    TextField("Document Title", text: $documentTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(minWidth: 140, maxWidth: 220)
                }
                
                Divider().frame(height: 20)

                // Word-Style Font Formatting Controls
                HStack(spacing: 8) {
                    // Font Family
                    Menu {
                        ForEach(["System", "Georgia", "Helvetica Neue", "Times New Roman", "Menlo", "Courier New", "Avenir Next", "Baskerville", "Palatino", "Charter"], id: \\.self) { fam in
                            Button(fam) { setFontFamilyAction(fam) }
                        }
                    } label: {
                        HStack {
                            Text(selectionAttributes?.fontFamily ?? fontFamily)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 100, alignment: .leading)
                            Image(systemName: "chevron.down").font(.system(size: 10))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06)).cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Font Size
                    HStack(spacing: 2) {
                        Button(action: { setFontSizeAction((selectionAttributes?.fontSize ?? fontSize) - 1) }) {
                            Image(systemName: "minus")
                        }.frame(width: 24, height: 26).background(Color.primary.opacity(0.06)).cornerRadius(4)
                        
                        Text("\\(Int(selectionAttributes?.fontSize ?? fontSize))")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, alignment: .center)
                            
                        Button(action: { setFontSizeAction((selectionAttributes?.fontSize ?? fontSize) + 1) }) {
                            Image(systemName: "plus")
                        }.frame(width: 24, height: 26).background(Color.primary.opacity(0.06)).cornerRadius(4)
                    }.buttonStyle(.plain)
                    
                    Divider().frame(height: 16)
                    
                    // Bold, Italic, Underline
                    Button(action: { toggleBoldAction() }) {
                        Image(systemName: "b.square")
                            .font(.system(size: 15, weight: (selectionAttributes?.isBold ?? isBold) ? .bold : .regular))
                            .foregroundColor((selectionAttributes?.isBold ?? isBold) ? .accentColor : .primary)
                    }.buttonStyle(.plain)
                    Button(action: { toggleItalicAction() }) {
                        Image(systemName: "i.square")
                            .font(.system(size: 15, weight: (selectionAttributes?.isItalic ?? isItalic) ? .bold : .regular))
                            .foregroundColor((selectionAttributes?.isItalic ?? isItalic) ? .accentColor : .primary)
                    }.buttonStyle(.plain)
                    Button(action: { toggleUnderlineAction() }) {
                        Image(systemName: "u.square")
                            .font(.system(size: 15, weight: (selectionAttributes?.isUnderline ?? isUnderline) ? .bold : .regular))
                            .foregroundColor((selectionAttributes?.isUnderline ?? isUnderline) ? .accentColor : .primary)
                    }.buttonStyle(.plain)
                    
                    Divider().frame(height: 16)
                    
                    // Alignment
                    Menu {
                        Button("Left") { setAlignmentAction(.left) }
                        Button("Center") { setAlignmentAction(.center) }
                        Button("Right") { setAlignmentAction(.right) }
                        Button("Justified") { setAlignmentAction(.justified) }
                    } label: {
                        let align = selectionAttributes?.alignment ?? textAlignment
                        let alignIcon = align == .left ? "text.alignleft" : (align == .center ? "text.aligncenter" : (align == .right ? "text.alignright" : "text.justify"))
                        Image(systemName: alignIcon)
                            .font(.system(size: 15))
                            .padding(6)
                            .background(Color.primary.opacity(0.06)).cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Quick Action Center (AI, Timeline, Command)
                HStack(spacing: 12) {
                    // Timeline
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showDocumentTimeline.toggle()
                        }
                    }) {
                        Image(systemName: showDocumentTimeline ? "chart.bar.doc.horizontal.fill" : "chart.bar.doc.horizontal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(showDocumentTimeline ? StudioTheme.luminousCyan : .primary)
                            .padding(8)
                            .background(showDocumentTimeline ? StudioTheme.luminousCyan.opacity(0.18) : Color.primary.opacity(0.06))
                            .cornerRadius(8)
                            .symbolEffect(.bounce, value: showDocumentTimeline)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Reading Flow Timeline (⌥⌘T)")
                    
                    // AI Copilot Toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAIDrawer.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Copilot")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(showAIDrawer ? StudioTheme.luminousPurple.opacity(0.2) : Color.primary.opacity(0.06))
                        .foregroundColor(showAIDrawer ? StudioTheme.luminousPurple : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    // Command Center Button
                    Button(action: { showCommandPalette.toggle() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .padding(8)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
SWIFT

content.sub!(old_top_bar, new_top_bar)

# 2. Remove StudioCoverBannerView
cover_banner = /\/\/ Optional Editorial Hero Cover Banner\s+if coverBannerConfig\.isEnabled \{.*?\}\n/m
content.sub!(cover_banner, "")

# 3. Remove StudioPageDesignView
page_design = /\/\/ Floating Right Page Design & Style Inspector\s+if showPageDesignInspector \{.*?\.zIndex\(16\)\n\s+\}\n/m
content.sub!(page_design, "")

# 4. Cleanup Floating Text Selection Action Menu
# The user wants to remove the floating text styling menu because it's now in the top bar.
floating_hud = /\/\/ 4\. Floating Text Selection Quick Format HUD & Inline AI Canvas Editor.*?if !selectedText.*?\.trimmingCharacters\(in: \.whitespacesAndNewlines\)\.isEmpty && !isEditingHeaderFooter \{.*?\/\/ 5\. Floating Find & Replace Bar Overlay/m

new_floating_hud = <<-SWIFT
// 4. Inline AI Canvas Editor (shows when text selected, no format buttons since they are in top bar)
                        if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isEditingHeaderFooter {
                            VStack {
                                Spacer()
                                if showInlineAI {
                                    InlineAICanvasEditorView(
                                        selectedText: selectedText,
                                        fullDocumentContext: rawText,
                                        onAccept: { newText in
                                            replaceSelection(with: newText)
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showInlineAI = false
                                            }
                                        },
                                        onInsertBelow: { newText in
                                            insertBelowSelection(newText: newText)
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showInlineAI = false
                                            }
                                        },
                                        onDismiss: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showInlineAI = false
                                            }
                                        }
                                    )
                                    .padding(.bottom, 74)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.94).combined(with: .opacity).combined(with: .offset(y: 12)),
                                        removal: .opacity.combined(with: .scale(scale: 0.96))
                                    ))
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .zIndex(20)
                        }

                        // 5. Floating Find & Replace Bar Overlay
SWIFT

content.sub!(floating_hud, new_floating_hud)

File.write(path, content)
