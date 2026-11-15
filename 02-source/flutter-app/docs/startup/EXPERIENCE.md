# Mochii launch experience

## Intent and change radius

Show the supplied Mochii character reading, blinking and turning a page during real startup. Surfaces: Android launch icon, Flutter initialization state, Web engine bootstrap, and the project's presentation deck. Preserve existing learning data, routes, notifications and signer. No artificial minimum loading duration or invented percent-complete value.

## Design decisions

- Identity: owner-supplied purple robot and mint/cream book; separate eye layer, gentle body movement, vector page and shine details.
- Motion: one 2400ms loop; reduced motion/accessibility navigation uses a still pose. Failed startup stops decoration and offers Retry.
- Android 12+: short AnimatedVectorDrawable icon. Older Android versions briefly use a static native launch resource, then the animated Flutter screen.
- Flutter: runApp is called before notification/store initialization completes. A FutureBuilder renders actual waiting/error/ready states; startup readiness is independent of animation completion.
- Web: matching WebP/poster, removed only on flutter-first-frame. The old fixed 2.2/2.5 second dismissal and early removal before runApp have been removed.
- Startup does not rewrite or clear user data as part of the animation. Existing data initialization behavior is otherwise retained.
- About-version caption now reads the installed Android package. Web release builds receive explicit MOCHII_VERSION/MOCHII_BUILD defines.

## Assets

- assets/animations/mochii_reading_base.png
- assets/animations/mochii_reading_eyes.png
- assets/animations/mochii_reading_poster.png
- assets/animations/mochii_reading_preview.webp (portable preview)
- Native vector + animators under android/app/src/main/res.
- Regenerator: tool/generate_loading_assets.py. The PNG source is the user's supplied logo; no new generative identity/logo was substituted.

## Sources reviewed

- https://docs.flutter.dev/platform-integration/android/splash-screen
- https://developer.android.com/develop/ui/views/launch/splash-screen
- https://api.flutter.dev/flutter/widgets/Image-class.html

Android's animation duration does not require extending the launch delay. Native OS splash and Flutter application loading are separate lifecycle phases; this is not a claim that every OS version renders an identical animation.

## Verification

- Six startup-specific tests: portrait/landscape at 2x text scale, immediate first UI with pending initialization, reduced motion, error/retry, installed-package version metadata.
- Frozen release snapshot: 91 tests passed, two opt-in/external integration tests skipped.
- Browser test with main.dart.js deliberately held: animated frames change while waiting, reduced-motion frames remain still; loader remains after 2.7 seconds and leaves only after first frame. No browser runtime errors.
- Presentation: 12 slides at 1366x768, 1920x1080, 390x844; no clipped desktop content, no horizontal mobile overflow or missing images. Presenter controls/timer and reduced-motion source tested.
- Native APK build/signer and public download hashes are verified at release publication. Browser/widget tests are not measurements of Android frame time or cold-start performance.
