// import 'package:flutter_appauth/flutter_appauth.dart';
// import 'package:googleapis_auth/auth_io.dart' as auth;
// import 'package:googleapis/calendar/v3.dart' as calendar;
// import 'package:http/http.dart' as http;

// class GoogleMeetService {
//   final FlutterAppAuth _appAuth = FlutterAppAuth();
//   final String clientId =
//       '500166558232-fgc36hhageuia4tpkujb8cd08laq1vvt.apps.googleusercontent.com';

//   // Use the web redirect URI as confirmed by your Google Cloud settings
//   final String redirectUrl = 'https://calligro-bcfb2.web.app';

//   TokenResponse? _tokenResponse;

//   Future<String?> authenticate(
//       String courseName, DateTime startDate, DateTime endDate) async {
//     // Check if the token exists and is still valid
//     if (_tokenResponse?.accessToken != null) {
//       final now = DateTime.now();
//       final expiry = _tokenResponse!.accessTokenExpirationDateTime;
//       if (expiry != null && now.isBefore(expiry)) {
//         return await _createGoogleMeetEvent(courseName, startDate, endDate);
//       } else {
//         await _refreshToken();
//         if (_tokenResponse?.accessToken != null) {
//           return await _createGoogleMeetEvent(courseName, startDate, endDate);
//         }
//       }
//     }

//     // If no valid token exists, initiate the full authorization flow
//     final AuthorizationTokenRequest request = AuthorizationTokenRequest(
//       clientId,
//       redirectUrl,
//       issuer: 'https://accounts.google.com',
//       scopes: [
//         'https://www.googleapis.com/auth/calendar.events',
//         'email',
//         'profile',
//       ],
//       // Use the 'promptValues' parameter as it is likely supported by your appauth version
//       promptValues: ['consent'],
//     );

//     try {
//       final AuthorizationTokenResponse? result =
//           await _appAuth.authorizeAndExchangeCode(request);

//       if (result != null) {
//         _tokenResponse = result;
//         print("Access Token: ${result.accessToken}");
//         return await _createGoogleMeetEvent(courseName, startDate, endDate);
//       } else {
//         print("Authentication failed.");
//         return null;
//       }
//     } catch (e) {
//       print("Error during authentication: $e");
//       return null;
//     }
//   }

//   Future<void> _refreshToken() async {
//     if (_tokenResponse?.refreshToken != null) {
//       try {
//         final TokenResponse? refreshResult = await _appAuth.token(TokenRequest(
//           clientId,
//           redirectUrl,
//           refreshToken: _tokenResponse!.refreshToken!,
//           issuer: 'https://accounts.google.com',
//           scopes: [
//             'https://www.googleapis.com/auth/calendar.events',
//             'email',
//             'profile'
//           ],
//         ));
//         _tokenResponse = refreshResult;
//         print("Token refreshed successfully.");
//       } catch (e) {
//         print("Error refreshing token: $e");
//       }
//     }
//   }

//   Future<String?> _createGoogleMeetEvent(
//       String courseName, DateTime startDate, DateTime endDate) async {
//     if (_tokenResponse == null || _tokenResponse!.accessToken == null) {
//       print("No valid access token available to create an event.");
//       return null;
//     }

//     final accessToken = _tokenResponse!.accessToken!;
//     final expiration = _tokenResponse!.accessTokenExpirationDateTime!;
//     final refreshToken = _tokenResponse!.refreshToken;

//     var credentials = auth.AccessCredentials(
//       auth.AccessToken('Bearer', accessToken, expiration),
//       refreshToken,
//       ['https://www.googleapis.com/auth/calendar.events'],
//     );

//     var client = auth.authenticatedClient(
//       http.Client(),
//       credentials,
//     );

//     var calendarApi = calendar.CalendarApi(client);

//     var event = calendar.Event()
//       ..summary = 'Course Event: $courseName'
//       ..start = calendar.EventDateTime(
//           dateTime: startDate.toUtc(), timeZone: 'UTC')
//       ..end =
//           calendar.EventDateTime(dateTime: endDate.toUtc(), timeZone: 'UTC')
//       ..conferenceData = calendar.ConferenceData(
//         createRequest: calendar.CreateConferenceRequest(
//           requestId: 'sample${DateTime.now().microsecondsSinceEpoch}',
//           conferenceSolutionKey:
//               calendar.ConferenceSolutionKey(type: 'hangoutsMeet'),
//         ),
//       );

//     try {
//       var createdEvent = await calendarApi.events.insert(
//         event,
//         'primary',
//         conferenceDataVersion: 1,
//       );
//       print('Google Meet link: ${createdEvent.hangoutLink}');
//       return createdEvent.hangoutLink;
//     } catch (e) {
//       print('Error creating event: $e');
//       return null;
//     }
//   }
// }