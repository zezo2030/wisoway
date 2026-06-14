# App Improvement Execution Plan

## Overview

This plan covers three main improvement areas for the application:

1. Enable Firebase Push Notifications
2. Improve all user-facing error and exception messages
3. Display the real trip route for passengers using directions instead of a straight line

The goal is to improve the overall user experience, app reliability, and booking clarity.

---

## 1. Firebase Push Notifications

### Objective

Enable push notifications for the following events:

- When a passenger books a trip
- When a driver posts a nearby trip
- When a booking is confirmed
- Later enhancements may include:
  - Booking cancellation
  - Trip updates
  - Trip reminders

### Required Work

#### A. Firebase Setup in the App

- Connect the Flutter app to Firebase
- Add `firebase_core`
- Add `firebase_messaging`
- Initialize Firebase in `main()`
- Request notification permissions
- Get the FCM token and save it to the backend for each user

#### B. Backend Notification Logic

Create a dedicated notification service in the backend to handle:

- Sending a notification to a specific passenger
- Sending a notification to nearby drivers
- Sending a notification when a booking is accepted or rejected
- Sending both `notification payload` and `data payload`

Example payload:

```json
{
  "type": "booking_confirmed",
  "trip_id": "123",
  "booking_id": "456",
  "screen": "booking_details"
}
```

This will allow the app to open the correct screen when the user taps the notification.

#### C. Notification Scenarios

1. **Passenger books a trip**
   - Notify the driver or admin, depending on the business flow

2. **Driver posts a new trip**
   - Notify interested passengers or users in the same city/route

3. **Booking is confirmed**
   - Notify the passenger

4. **Booking is rejected or canceled**
   - Notify the relevant party

5. **Trip reminder**
   - Optional future enhancement

### Suggested Implementation Phases

#### Phase 1
- Receive notifications inside the app
- Display them correctly
- Open the correct screen when tapped

#### Phase 2
- Save FCM tokens in the backend
- Send real push notifications from the backend

#### Phase 3
- Improve targeting
  - By city
  - By route
  - By trip proximity
  - By user type

### Expected Output

- `notification_service.dart`
- Backend endpoint such as:
  - `POST /notifications/send`
- A field or table to store:
  - `fcm_token`
- Navigation handling when opening notifications

---

## 2. Improve All Error and Exception Messages

### Objective

Replace raw technical exceptions with clean, user-friendly messages across the entire application.

### Problem

The app should not display messages like:

- `Exception occurred`
- `SocketException`
- `Unhandled error`
- `type 'Null' is not a subtype of ...`

These messages are useful for developers, but not for end users.

### Required Work

Create a centralized error handling layer instead of handling errors differently in every screen.

### Suggested Structure

#### A. Unified Error Types

Create clear categories such as:

- `NetworkError`
- `ServerError`
- `ValidationError`
- `AuthError`
- `PermissionError`
- `UnknownError`

#### B. Error Mapper

Any exception coming from:

- HTTP/Dio
- Firebase
- JSON parsing
- Backend responses
- Permissions
- Location services

should be mapped into a user-friendly message.

### Good User-Facing Message Examples

Instead of:

- `SocketException`

Show:

- **Unable to connect to the internet. Please check your connection and try again.**

Instead of:

- `500 Internal Server Error`

Show:

- **A server error occurred. Please try again later.**

Instead of:

- `Unauthorized`

Show:

- **Your session has expired. Please log in again.**

Instead of:

- `Exception: booking already exists`

Show:

- **This booking already exists or the selected time has already been reserved.**

### Technical Deliverables

Create:

- `AppException` base class
- `Failure` model
- `ErrorHandler` or `ExceptionMapper`
- Unified `Snackbar/Toast/Dialog` helper
- Logging system for developers

### Important Rule

Separate:

- **User message**
- **Developer message**

This means:

- The user sees a clean, understandable message
- The developer still has access to the original error and stack trace in logs

### Suggested Implementation Phases

#### Phase 1
Audit all current error sources in the app:

- API requests
- Firebase
- Location permissions
- Map loading
- Authentication
- Booking flow

#### Phase 2
Create a centralized error layer:

- `exceptions.dart`
- `failures.dart`
- `error_mapper.dart`

#### Phase 3
Replace all random `try/catch` blocks with the unified approach

#### Phase 4
Review all Arabic and English messages for:
- Clarity
- Brevity
- Professional tone
- Better UX

---

## 3. Display the Real Trip Route Instead of a Straight Line

### Objective

Show the actual road route for the passenger using directions, instead of drawing a straight line between two points.

### Problem

A straight line between origin and destination is visually incorrect and gives a poor user experience.

### Correct Approach

Use a routing or directions API to fetch the real route polyline, then render it on the map.

### Required Work

#### A. Route Input

Use:
- Origin coordinates
- Destination coordinates
- Optional waypoints in the future

#### B. Fetch Route Data

When the passenger opens trip details:

- Send the origin and destination to a routing service
- Receive the encoded polyline
- Decode the polyline
- Draw the real route on the map

#### C. Map Rendering

Display:

- Start marker
- End marker
- Real route polyline
- Camera fit to show the full route

### Suggested Architecture

Create dedicated services such as:

- `route_service.dart`
- `map_polyline_helper.dart`

### Suggested Implementation Phases

#### Phase 1
- Prepare the map provider and routing service
- Add API integration for route calculation

#### Phase 2
- Decode the polyline
- Render the route on the map

#### Phase 3
- Fit camera bounds
- Test with real trip data
- Add support for stop points if needed later

---

## Recommended Execution Order

### Priority 1: Error Handling Layer

Start here because it affects the entire app immediately.

#### Tasks
- Create centralized exception handling
- Standardize user-facing messages
- Audit and refactor critical screens

### Priority 2: Firebase Push Notifications

This depends on both frontend and backend setup.

#### Tasks
- Configure Firebase
- Receive and display notifications
- Store FCM token
- Send notifications from backend
- Navigate to the proper screen when tapped

### Priority 3: Real Route Directions on Map

This is a visually important feature and should be implemented after the first two are stable.

#### Tasks
- Configure routing API
- Build `RouteService`
- Decode and display route polyline
- Fit the route on the map
- Test on real trips

---

## Project Breakdown by Epic

## Epic 1: Notifications

- Setup Firebase in Flutter
- Request notification permissions
- Save FCM token to backend
- Create backend notification sender
- Handle foreground/background notifications
- Deep link to booking/trip screen
- Test Android notifications end-to-end

## Epic 2: Error Handling

- Audit current exceptions in app
- Create centralized exception/failure layer
- Map backend and network errors to user-friendly messages
- Replace raw exception UI messages
- Add developer logging

## Epic 3: Route Directions

- Enable routing service
- Create route API client
- Decode route polyline
- Render route on map
- Fit map bounds to route
- Test with real trip data

---

## Expected Final Result

After implementing this plan, the application should:

- Send useful and reliable push notifications
- Show clean and professional error messages
- Display realistic road routes instead of straight lines

This will improve:

- User experience
- User trust
- Booking clarity
- Overall product quality
