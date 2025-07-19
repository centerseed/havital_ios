# Havital iOS App

## Project Overview
This is the Havital iOS app, a fitness tracking application that integrates with various data sources including Garmin Connect.

## Development Setup
- iOS project built with Xcode
- Swift-based application
- Integration with Garmin SDK for workout tracking

## Project Structure
- `Havital/` - Main app directory
- `Havital/Managers/` - Core managers (GarminManager, UnifiedWorkoutManager, etc.)
- `Havital/Views/` - SwiftUI views organized by feature
- `Havital.xcodeproj/` - Xcode project file

## Key Features
- Garmin Connect integration
- Workout tracking and management
- User profile management
- Data synchronization
- Onboarding flow

## Recent Development
- Added Garmin workout support (v2)
- Enhanced data sync capabilities
- Updated UI for training intensity statistics
- Added push notification support
- Implemented comprehensive health data API integration with TaskManagement and CacheEventBus


### Best Practices

#### Task Management
- Always use `executeTask` for API calls
- Use descriptive task IDs
- Handle cancellation gracefully
- Don't forget to call `cancelAllTasks()` in `deinit`
- Details: `Docs/ARCHITECTURE.md`

#### Cache Management
- Implement proper TTL (Time To Live) logic
- Register all cache managers with CacheEventBus
- Use consistent cache key naming
- Handle cache invalidation scenarios
- Details: `Docs/ARCHITECTURE.md`

#### Performance
- Avoid unnecessary UI updates
- Use `@MainActor` for UI property updates
- Implement proper loading states
- Cache frequently accessed data

### Testing Commands
```bash
# Clean build to test changes
cd "/Users/wubaizong/havital/apps/ios/Havital"
xcodebuild clean build -project Havital.xcodeproj -scheme Havital

# Check for Swift concurrency issues
xcodebuild build -project Havital.xcodeproj -scheme Havital -destination 'platform=iOS Simulator,name=iPhone 15' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```
