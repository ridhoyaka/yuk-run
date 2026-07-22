# RunNotPace (YukRun) — AI Context Transfer

## Project Overview
Flutter mobile app for running route planning and tracking. Dark theme with neon green accent (`#00FF66`).

## Tech Stack
- Flutter (Dart)
- Packages: `http`, `flutter_secure_storage`, `google_maps_flutter`
- State: `setState` (no state management library)

## Project Structure
```
lib/
  models/          # Data models
  screens/         # All UI screens
  services/        # API services
  widgets/         # Reusable widgets (HoverButton, StartRunButton)
```

## Navigation Flow
```
SplashScreen → OnboardingScreen → LoginScreen → MainScreen (DashboardScreen)
                    ↑                  ↓
               (is_onboarded)    RegisterScreen
```

- `is_onboarded` flag stored in `flutter_secure_storage`
- Splash checks flag → skip to Login or show Onboarding
- Onboarding writes flag on "MULAI SEKARANG"

## Screens Implemented
| Screen | File | Key Details |
|--------|------|-------------|
| SplashScreen | `splash_screen.dart` | Animated logo + loading indicator, checks `is_onboarded` |
| OnboardingScreen | `onboarding_screen.dart` | PageView slides, "MULAI SEKARANG" button, smooth transitions |
| LoginScreen | `login_screen.dart` | Email/password fields, "MASUK" btn, "Daftar Sekarang" link |
| RegisterScreen | `register_screen.dart` | Name/email/password fields, "DAFTAR" btn, slide transition |
| DashboardScreen | `dashboard_screen.dart` | Welcome msg, stats cards, route planning card, favorites |
| MapScreen | `map_screen.dart` | Google Maps, search, route navigation button |
| EventScreen | `event_screen.dart` | Event cards with register button |
| ProfileScreen | `profile_screen.dart` | User info, stats, settings menu, logout |
| TransitionLoadingScreen | `transition_loading_screen.dart` | Animated loading between screens |

## HoverButton Widget (`lib/widgets/hover_button.dart`)
Reusable stateful widget for desktop hover effects.

### Mechanism
- `MouseRegion` detects enter/exit
- `AnimationController` (400ms) + `CurvedAnimation(Curves.easeInOutCubic)`
- Builder function receives `progress` (double 0.0→1.0)
- Each usage uses `Color.lerp(start, end, progress)` for smooth transitions

### Final Hover Behavior
- **Background**: `Colors.white.withOpacity(0.2)` — translucent glass effect
- **Text black → green** on ElevatedButton master buttons
- **Text green → white** on TextButton links
- **Text grey → white** on icon buttons
- **Text red → green** on logout buttons
- **"CARI RUTE SEKARANG"**: text black → white, bg glass
- **No borders** on hover
- **No elevation** on hover (elevation removed during hover)
- **No position/size changes** (pure color transitions via lerp)

### Buttons Using HoverButton (8 files, 18 buttons total)
| File | Buttons |
|------|---------|
| `start_run_button.dart` | "MULAI BERLARI" (borderRadius: 30) |
| `dashboard_screen.dart` | "CARI RUTE SEKARANG" (12), "Lihat Semua" (8) |
| `map_screen.dart` | IconButton close (20), "MULAI NAVIGASI RUTE" (14) |
| `event_screen.dart` | "DAFTAR SEKARANG" (12) |
| `login_screen.dart` | IconButton visibility (20), "Lupa Password?" (8), "MASUK" (16), "Daftar Sekarang" (8) |
| `register_screen.dart` | IconButton back (20), "DAFTAR" (15), "Login" (8), IconButton visibility (20) |
| `profile_screen.dart` | "Batal" dialog (8), "Keluar" dialog (8), "KELUAR AKUN" OutlinedButton (16) |
| `onboarding_screen.dart` | "MULAI SEKARANG" (22) |

## Color System
- **Background**: `#121212` (main), `#1E1E1E` (cards)
- **Accent**: `#00FF66` (green neon)
- **Text primary**: `Colors.white`
- **Text secondary**: `Colors.white54`
- **Glass hover**: `Colors.white.withOpacity(0.2)`

## Design Conventions
- Dark theme throughout
- Rounded corners (varies 8–30px)
- No neon/glow effects on buttons
- Gradient cards (dark → green tint)
- Animations: `Curves.easeInOutCubic` for UI transitions
- Page transitions: SlideTransition + FadeTransition, 400ms

## Known Issues (Pre-existing, non-blocking)
- `translate`/`scale` deprecated in `onboarding_screen.dart` (use Vector3/Vector4 variants)
- `use_build_context_synchronously` warnings in `splash_screen.dart`

## Commands
- `flutter analyze` — lint/type check
- `flutter build apk` / `flutter build ios` — build
