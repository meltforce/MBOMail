# Custom CSS Reference

> **Status:** Basic injection works. Selector accuracy varies — OX App Suite v8 DOM structure may change between updates. To be refined in future versions.

## How to Use

Settings → Advanced → Custom CSS. Changes apply immediately (no restart needed).

## OX v8 DOM Structure

| Area | Selector | Notes |
|---|---|---|
| Top bar | `#io-ox-appcontrol` | Height 72px, contains logo + search + right controls |
| Logo area | `#io-ox-top-logo` | Inside top bar |
| Search bar | `#io-ox-topsearch` | Inside top bar |
| Folder sidebar | `.leftside` | Left panel with folder buttons |
| Folder tree | `.tree-container` | Nested folder list with counters |
| Folder counter (unread) | `.folder-counter` | Inside `.folder-node.show-counter` |
| Mail list | `.list-view` | Scrollable mail item list |
| Mail list item | `.list-item` | Each mail row |
| Item avatar | `.list-item .avatar` | Sender initials circle |
| Item sender | `.list-item .from` | Sender name |
| Item date | `.list-item .date` | Timestamp |
| Item subject | `.list-item .subject` | Subject line |
| Item preview | `.list-item .text-preview` | Body preview text |
| Mail detail pane | `.window-sidepanel` | Right-side reading pane |
| Compose button | `.leftside button` (first) | "Neue E-Mail" |

## Example: Compact Layout

```css
#io-ox-appcontrol { height: 52px !important; min-height: 52px !important; }
.list-item { padding: 6px 16px 6px 0 !important; }
.list-item .avatar { width: 32px !important; height: 32px !important; font-size: 13px !important; }
.leftside { max-width: 220px !important; }
.list-item .text-preview { display: none !important; }
.list-item .date { opacity: 0.6; }
```

## Future Work

- Verify selectors against OX v8 updates
- Add predefined theme presets (compact, dark accents, minimal)
- Add a CSS reset/clear button in settings
- Consider bundling popular customizations as toggles instead of raw CSS
