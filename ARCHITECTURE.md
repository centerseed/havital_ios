# Havital iOS App Architecture

This document describes the high-level architecture and directory structure of the Havital iOS application.

## Project Structure

```
Havital/                  # Main workspace
├── Havital.xcodeproj     # Xcode project file
├── HavitalApp.swift      # App entry point (SwiftUI)
├── Info.plist            # App configuration
├── GoogleService-Info.plist
├── Havital.entitlements
├── Assets.xcassets        # App assets (images, colors)
├── Extensions/           # Swift extensions for core types
├── Managers/             # Singleton managers (e.g., UserManager)
├── Models/               # Data models and domain objects
├── Services/             # API, networking, external services
├── Storage/              # Local persistence (e.g., CoreData, UserDefaults)
├── ViewModels/           # MVVM view models
├── Views/                # SwiftUI views and subcomponents
├── Utils/                # Utility helpers and shared code
├── Theme/                # UI theming, color palettes, fonts
├── Resources/            # Static resources (JSON, fonts, icons)
└── Preview Content/      # SwiftUI previews mocks

HavitalTests/             # Unit tests target
HavitalUITests/           # UI tests target
```

## Architectural Pattern

The app follows the **MVVM** (Model-View-ViewModel) pattern:

- **Models**: Define the domain data structures (`Models/`).
- **ViewModels**: Handle business logic and state (`ViewModels/`).
- **Views**: Present UI and bind to view models (`Views/`).

Additional layers:

- **Services**: Encapsulate networking and external API calls.
- **Managers**: Handle app-wide singletons and coordination (e.g., user session).
- **Storage**: Abstract local persistence mechanisms.
- **Utils**: General-purpose helpers.
- **Theme**: Centralize design tokens (colors, typography).

## Key Directories

### Extensions
- Swift extensions that augment Foundation, SwiftUI, or custom types.

### Managers
- Singleton classes managing global state or processes (e.g., authentication, notifications).
- HealthKitManager: handles HealthKit authorization, permissions, and data queries (workouts, heart rate, sleep metrics). Core entry point for any HealthKit-related feature.
- WorkoutBackgroundManager: configures and manages background delivery of workout samples from HealthKit, schedules sync events.
- HeartRateZonesManager & Bridge: processes raw heart rate samples to compute training zones and interval thresholds.

### Models
- Plain data objects, often conforming to `Codable` for JSON mapping.

### Services
- HTTP clients, API request definitions, response parsing.
- WorkoutService: CRUD operations for workout records, communicates with backend endpoints to fetch/post workout data.
- WorkoutBackgroundUploader: batches and uploads offline-collected workout data when connectivity is available.
- ProfileService: manages user profile endpoints (fetch/update user data).
- MetricsService: aggregates and posts user performance metrics (e.g., weekly plans, achievements).

### Storage
- Persistence layer (Core Data stacks, caching, UserDefaults wrappers).

### ViewModels
- Combine-based publishers, form validation, data transformations.

### Views
- SwiftUI screens and reusable components organized by feature (e.g., `UserProfileView`, `TrainingPlanView`).

### Utils
- Helper functions, date formatters, logging, miscellaneous tools.

### Theme
- Color scheme, font styles, layout constants.

### Resources
- App icons, JSON fixtures, custom fonts, asset catalogs.

## Conclusion

This modular structure promotes separation of concerns, testability, and scalability. Each layer has a clear responsibility.
