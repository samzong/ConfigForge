# ConfigForge UI Style Guide (Apple HIG 2025 Compliant)

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

## Typography System (Apple HIG 2025 Compliant)

### Semantic Text Styles
Use SwiftUI semantic text styles for optimal Dynamic Type support and accessibility:

- **Large Title**: `.largeTitle` - Main app headers (34pt default)
- **Title**: `.title` - Section headers (28pt default)  
- **Title 2**: `.title2` - Subsection headers (22pt default)
- **Title 3**: `.title3` - Minor headers (20pt default)
- **Headline**: `.headline` - Emphasized body text (17pt semibold)
- **Body**: `.body` - Primary content text (17pt regular) 
- **Callout**: `.callout` - Secondary content (16pt regular)
- **Subheadline**: `.subheadline` - Supporting text (15pt regular)
- **Footnote**: `.footnote` - Fine print (13pt regular)
- **Caption**: `.caption` - Labels and captions (12pt regular)
- **Caption 2**: `.caption2` - Smallest text (11pt regular)

### SF Pro Font Usage Rules (2025)
- **SF Pro Text**: Automatically used for text ≤19pt
- **SF Pro Display**: Automatically used for text ≥20pt  
- **Dynamic Optical Sizing**: Enabled by default in macOS 26+
- **Never specify font manually**: Use semantic styles only

### Text Colors & Accessibility
- **Primary**: `.primary` - Main content text (adapts to light/dark mode)
- **Secondary**: `.secondary` - Supporting text, placeholders
- **Tertiary**: `.tertiary` - De-emphasized text
- **Quaternary**: `.quaternary` - Minimal prominence text
- **White**: `.white` - Text on colored backgrounds (use sparingly)

---

## Color System (Apple HIG 2025)

### Semantic Color Hierarchy
- **`.primary`**: Main content text, primary UI elements
- **`.secondary`**: Secondary content, subtle UI elements  
- **`.tertiary`**: Placeholder text, disabled content
- **`.quaternary`**: Borders, dividers, very subtle backgrounds
- **`.quinary`**: Ultra-light backgrounds, container fills

### Background Colors
- **Window**: `Color(.windowBackgroundColor)` - Main backgrounds
- **Input**: `Color(.textBackgroundColor)` - Text fields, input areas
- **Section**: `Color.quinary` - Section backgrounds (replaces manual opacity)

### Status Colors
- **Success**: `.green` - Positive states, active indicators
- **Error**: `.red` - Error states, destructive actions
- **Info**: `.blue` - Information, links, accents
- **Warning**: `.orange` - Warning states

### Material Backgrounds
- **`.regularMaterial`**: Standard glass effect
- **`.thickMaterial`**: Stronger glass effect for important overlays

### Usage Guidelines
- Prioritize semantic colors over custom opacity values
- Use `.quaternary` instead of `.gray.opacity(0.3)`
- Use `.tertiary` instead of `.gray.opacity(0.5)` 
- Use `.primary.opacity()` instead of `.black.opacity()` for shadows
- Preserve system colors (`.red`, `.green`) for status indication

---

## Spacing System (8pt Grid - Apple HIG 2025)

### Standard Spacing Scale
Apple's 8-point grid system ensures consistency across all platforms:

- **4pt**: Tight spacing, icon-text gaps
- **8pt**: Base unit - component spacing, small padding
- **16pt**: Standard component spacing, comfortable padding  
- **24pt**: Section spacing, moderate separation
- **32pt**: Block spacing between major sections
- **40pt**: Large section separation
- **48pt**: Major layout breaks

### Padding Standards
- **Tight**: `padding(4)` - Icon spacing, minimal areas
- **Standard**: `padding(8)` - Default component padding
- **Comfortable**: `padding(16)` - Headers, form elements
- **Spacious**: `padding(24)` - Section containers
- **Large**: `padding(32)` - Major layout areas

### Dynamic Type Spacing
- Spacing automatically adjusts with user's text size preferences
- Use semantic spacing modifiers when available
- Test with largest Dynamic Type sizes (AX sizes)

---

## Layout Standards (macOS 26 / 2025)

### Corner Radius (Liquid Glass Design)
Following Apple's 2025 Liquid Glass design language:

- **Small**: `6pt` - Status badges, small components
- **Standard**: `12pt` - Cards, sections, input fields  
- **Large**: `16pt` - Major containers, modal dialogs
- **Button**: Use system defaults via `ButtonStyle` (auto-adaptive)
- **Capsule**: `Capsule()` - Pills, banners, tags

### TextField Styling
- **Plain**: `PlainTextFieldStyle()` - Search bars, inline editing
- **Bordered**: `RoundedBorderTextFieldStyle()` - Form inputs
- **Automatic**: Let SwiftUI choose based on context (recommended)

### Glass Material Effects (New in 2025)
```swift
.background(.regularMaterial)     // Standard glass effect
.background(.thickMaterial)       // Prominent glass effect  
.background(.thinMaterial)        // Subtle glass effect
.background(.ultraThinMaterial)   // Minimal glass effect
```

### Shadow Effects (Refined for Liquid Glass)
- **Soft**: `shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)` - Cards, elevated content
- **Standard**: `shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)` - Floating elements
- **Prominent**: `shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 8)` - Modal dialogs
- **Usage**: Combine with material backgrounds for glass effect

---

## Migration Notes

### Components Updated ✅
1. **TerminalLauncherButton**: Removed custom blue background, now uses standard styling
2. **ConfigListView**: Create button now uses primary action style (.large)  
3. **SidebarView**: Save button updated to primary style (.large), add button uses prominent style
4. **ModernEntryEditorView**: Add buttons updated to secondary style (.regular)
5. **MessageBanner**: Close button uses utility style (PlainButtonStyle)

### Deprecated Patterns (2025 Update)
- ❌ Manual font sizes: `.system(size: 13)` → Use `.body`, `.caption` etc.
- ❌ Custom `.background()` and `.foregroundColor()` combinations
- ❌ Manual `.cornerRadius()` on buttons  
- ❌ Custom button heights via `.frame(height:)`
- ❌ Inconsistent `.controlSize()` usage
- ❌ Fixed spacing values without 8pt grid alignment
- ❌ Ignoring Dynamic Type accessibility

### Approved Patterns (2025 Standards)
- ✅ Semantic text styles: `.body`, `.headline`, `.caption`
- ✅ SF Pro automatic optical sizing (system handled)
- ✅ SwiftUI built-in `ButtonStyle` variants
- ✅ `.controlSize()` for consistent sizing
- ✅ `.tint()` for accent colors
- ✅ `role:` parameter for semantic actions
- ✅ 8pt grid-based spacing: `8, 16, 24, 32, 40, 48`
- ✅ Material backgrounds: `.regularMaterial`, `.thickMaterial`
- ✅ Liquid Glass corner radius: `6pt, 12pt, 16pt`
- ✅ Semantic color hierarchy: `.primary`, `.secondary`, `.tertiary`, `.quaternary`
- ✅ Dynamic Type support and testing