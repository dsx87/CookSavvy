# Manual QA Checklist

These scenarios remain manual-only after the `CookSavvyUITests` automation pass.

## Cook Mode

### 5.2 Timer Functionality
- Enter cook mode on a step with a timer.
- Verify the timer UI appears.
- Start the timer and verify the countdown progresses in real time.

## Camera & Ingredient Detection

### 9.1 Camera Launch — Free Tier
- Open camera ingredient detection as a free user on a physical device.
- Verify the live camera viewfinder appears and capture controls are usable.

### 9.3 Camera — Premium Unlimited
- As a premium user, verify scan-limit messaging is absent.
- Capture multiple photos and verify premium access remains available.

### 9.4 AI Ingredient Detection Results
- Capture a real ingredient photo.
- Verify detected ingredients are reasonable and can be added to selection.

## Subscription & Upgrade

### 10.2 Purchase Flow
- Run a StoreKit sandbox purchase for `com.cooksavvy.subscription.premium`.
- Verify the plan upgrades to CookSavvy+ and premium features unlock.

### 10.3 Restore Purchase
- Reinstall or clear app data after a sandbox purchase.
- Tap Restore Purchases and verify premium access is restored.

## Settings

### 11.2 Theme Preference
- Switch theme preference between light, dark, and system.
- Verify the app appearance changes correctly across screens.

## Offline Behavior

### 12.1 Offline Recipe Search
- Put the device in airplane mode.
- Verify offline recipes still search correctly without crashes or hangs.

### 12.2 Online Source Graceful Failure
- With premium enabled and the device offline, verify offline results still load.
- Confirm online and AI sources fail gracefully without crashing.

## App Lifecycle

### 13.3 Background / Foreground
- Start a cooking session.
- Background the app for at least 30 seconds.
- Return and verify cook mode state is preserved.
