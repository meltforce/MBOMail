# Notification Stacking Issue

## Problem
When multiple emails arrive, the same sender/subject is displayed repeatedly as separate stacked notifications. The JS (`unreadObserverJS`) always extracts the first `.list-item.unread` in DOM order, so all notifications show the same mail.

## Desired Behavior
- Show sender and subject of the latest mail
- If multiple new mails: append "(and N others)"
- Don't stack identical notifications

## Solution (Implemented)

Two-layer fix:

### Layer 1: JS-Side Debounce (primary)
The MutationObserver in `unreadObserverJS` now calls `debouncedGetUnreadInfo()` instead of `getUnreadInfo()` directly. The debounced wrapper uses `setTimeout` with a 1.5s settle time — rapid DOM mutations reset the timer, so only one `postMessage` fires per batch after the DOM has settled. This keeps the Swift-side `UNUserNotificationCenter.add()` call synchronous within the `WKScriptMessageHandler` callback chain.

The initial 2s `setTimeout` and 30s `setInterval` poll still call `getUnreadInfo()` directly (no debounce needed for those paths).

### Layer 2: Rotating Notification Identifier (defense-in-depth)
`NotificationManager.postNotification()` alternates between two fixed identifiers (`"mbomail-newMail-0"` and `"mbomail-newMail-1"`) instead of generating a random UUID per notification. Before posting, it removes both identifiers from delivered notifications. This prevents duplicate stacking if the debounce ever leaks two messages, while ensuring fresh banners (a single fixed identifier won't re-show after user dismissal).

### Files Changed
- `WebViewContainer.swift`: `unreadObserverJS` — added `debouncedGetUnreadInfo()`, cleanup of `_mboDebounceTimer`
- `NotificationManager.swift`: `postNotification()` — rotating identifier, `removeDeliveredNotifications` before `add()`

## What Was Tried and Failed

### 1. Debounce with `Timer.scheduledTimer` + `MainActor.assumeIsolated`
- Accumulated rapid count changes into `pendingDelta`, fired after 2s via `Timer`
- **Result**: Timer callback never fired. Likely interaction between `@Observable`, `@MainActor`, and `Timer.scheduledTimer` in the `@Sendable` closure context.

### 2. Debounce with `Task.sleep`
- Replaced `Timer` with `Task { try? await Task.sleep(for: .seconds(2)); fireNotification() }`
- **Result**: `fireNotification()` was called, `postNotification()` ran, `UNUserNotificationCenter.add()` was called — but **no banner appeared**. The `add()` completion handler reported no error. Authorization status was `.authorized`. Unknown why macOS silently dropped the notification.

### 3. Stable notification identifier (`"mbomail-newMail"`)
- Used a fixed identifier so macOS replaces the previous notification instead of stacking.
- **Result**: macOS does not re-show a banner when updating a notification with the same identifier after the previous one was dismissed. The notification silently updates in Notification Center (swipe-left list) but no banner is shown.

### 4. `removeAllDeliveredNotifications()` before `add()`
- Called `removeAllDeliveredNotifications()` immediately before posting a new notification with a fresh UUID.
- **Result**: No banner appeared. Likely a timing issue where macOS suppresses notifications posted immediately after removing all delivered ones.

### 5. Re-injection guard on `unreadObserverJS`
- Added `if (window._mboUnreadObserverInstalled) return;` to prevent duplicate MutationObservers from stacking on re-injection.
- **Result**: Broke inbox updates entirely. The `WKUserScript` injects at `atDocumentEnd` before OX renders the folder tree, so the MutationObserver isn't set up. The `didFinish` re-injection (which runs after OX renders) was blocked by the guard.
- **Fix applied**: Replaced guard with cleanup — disconnects previous observer and clears previous interval before creating new ones. This change is still in place.

## Key Constraint
Any async indirection (Timer, Task.sleep, DispatchQueue.main.asyncAfter) between the `WKScriptMessageHandler` callback and `UNUserNotificationCenter.add()` causes macOS to silently drop the notification — `add()` succeeds with no error but no banner appears. The solution must keep the `add()` call synchronous within the handler callback chain, which is why debouncing happens on the JS side.
