# ConfigForge UI Style Guide

## Button Design System

### Core Principles
- **Simplicity First**: Clean, readable buttons without excessive styling
- **Consistency**: Same button types have identical appearance across the app
- **Accessibility**: Clear visual hierarchy and appropriate sizing
- **Native Feel**: Leverage SwiftUI's built-in button styles for macOS integration

---

## Button Types & Specifications

### 1. Primary Action Buttons
**Usage**: Main actions like Save, Edit, Add, Create New  
**Style**: `BorderedButtonStyle()` + `controlSize(.large)`  
**Example**: Edit/Save buttons in editor headers, sidebar save button, create new config button

```swift
Button("Save") { action() }
    .buttonStyle(BorderedButtonStyle())
    .controlSize(.large)
```

### 2. Secondary Action Buttons  
**Usage**: Supporting actions, context menu triggers  
**Style**: `BorderedButtonStyle()` + `controlSize(.regular)`  
**Example**: Terminal launch buttons, add identity file/directive buttons

```swift
Button("Launch Terminal") { action() }
    .buttonStyle(BorderedButtonStyle())
    .controlSize(.regular)
```

### 3. Utility Buttons
**Usage**: Icons, file selectors, inline actions  
**Style**: `PlainButtonStyle()`  
**Example**: Search clear, folder picker, remove items

```swift
Button(action: action) {
    Image(systemName: "xmark.circle.fill")
}
.buttonStyle(PlainButtonStyle())
```

### 4. Prominent Actions
**Usage**: Main call-to-action buttons  
**Style**: `BorderedProminentButtonStyle()` + `controlSize(.large)`  
**Example**: Add new host/config at bottom of sidebar

```swift
Button("Add Host") { action() }
    .buttonStyle(BorderedProminentButtonStyle())
    .controlSize(.large)
```

### 5. Destructive Actions
**Usage**: Delete, remove operations  
**Style**: `BorderedButtonStyle()` with role  
**Example**: Delete confirmations, remove items

```swift
Button("Delete", role: .destructive) { action() }
    .buttonStyle(BorderedButtonStyle())
    .controlSize(.regular)
```

---

## Layout Standards

### Button Sizing
- **Large**: `controlSize(.large)` - Primary actions in headers
- **Regular**: `controlSize(.regular)` - Secondary actions, dialogs  
- **Small**: `controlSize(.small)` - Compact spaces only when necessary

### Spacing & Padding
- **Button Groups**: 8pt spacing between buttons
- **Header Buttons**: 12pt padding from edges
- **Inline Buttons**: 4pt vertical padding minimum

### Minimum Dimensions
- **Text Buttons**: `minWidth: 80pt`
- **Icon Buttons**: `minWidth: 32pt, minHeight: 32pt`
- **Header Buttons**: `minHeight: 40pt`

---

## Special Cases

### Terminal Launch Buttons
**Current**: Custom blue styling  
**New Standard**: Use `BorderedButtonStyle()` with accent color

```swift
// Replace custom styling with:
Button("Terminal") { action() }
    .buttonStyle(BorderedButtonStyle())
    .controlSize(.regular)
    .tint(.blue)  // Use tint for color instead of custom background
```

### Menu Items & Context Actions
**Standard**: System default styling - no custom styling required

### Message Banner Close Buttons  
**Standard**: `PlainButtonStyle()` with appropriate opacity

---

## Keyboard Shortcuts

### Standard Shortcuts
- **Save**: `Cmd+S`
- **Edit**: `Cmd+Return` 
- **New**: `Cmd+N`
- **Delete**: `Delete` key (when focused)

### Implementation
```swift
.keyboardShortcut("s", modifiers: .command)  // Save
.keyboardShortcut(.return, modifiers: .command)  // Edit
```

---

## Color & State Management

### Button States
- **Default**: System provided states via ButtonStyle
- **Disabled**: Use `.disabled()` modifier, avoid custom opacity
- **Destructive**: Use `role: .destructive` parameter

### Color Usage
- **Accent Colors**: Use `.tint()` modifier, not custom backgrounds
- **System Colors**: Prefer system colors over custom hex values
- **Semantic Colors**: Use role-based colors (.destructive, .cancel)

---

## Migration Notes

### Components Updated ✅
1. **TerminalLauncherButton**: Removed custom blue background, now uses standard styling
2. **ConfigListView**: Create button now uses primary action style (.large)  
3. **SidebarView**: Save button updated to primary style (.large), add button uses prominent style
4. **ModernEntryEditorView**: Add buttons updated to secondary style (.regular)
5. **MessageBanner**: Close button uses utility style (PlainButtonStyle)

### Deprecated Patterns
- ❌ Custom `.background()` and `.foregroundColor()` combinations
- ❌ Manual `.cornerRadius()` on buttons  
- ❌ Custom button heights via `.frame(height:)`
- ❌ Inconsistent `.controlSize()` usage

### Approved Patterns  
- ✅ SwiftUI built-in `ButtonStyle` variants
- ✅ `.controlSize()` for consistent sizing
- ✅ `.tint()` for accent colors
- ✅ `role:` parameter for semantic actions