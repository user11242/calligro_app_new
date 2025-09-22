import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// Assuming these are custom widgets you have defined elsewhere
import 'package:calligro_app/features/teacher/pages/add_course/courseFirebaseServices.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/auth/widgets/auth_text_field.dart';

class GoogleMeetService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  GoogleSignInAccount? _currentUser;
  auth.AccessCredentials? _credentials;

  // Method to handle Google Sign-In and return success status
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser == null) {
        _currentUser = await _googleSignIn.signIn();
      }
      
      if (_currentUser != null) {
        print('Signed in as: ${_currentUser?.displayName}');
        final GoogleSignInAuthentication authentication =
            await _currentUser!.authentication;
        
        // Ensure access token is available before creating credentials
        if (authentication.accessToken != null) {
          _credentials = auth.AccessCredentials(
            auth.AccessToken(
              'Bearer',
              authentication.accessToken!,
              DateTime.now().toUtc().add(Duration(hours: 1)), // Token expiration
            ),
            null, // No refresh token needed
            ['https://www.googleapis.com/auth/calendar.events'],
          );
          return true; // Sign-in and credentials obtained successfully
        }
      }
    } catch (e) {
      print("Sign-in failed: $e");
    }
    return false; // Sign-in failed or credentials could not be obtained
  }

  // Method to create Google Meet event
  Future<String?> createGoogleMeetEvent(
    String courseName, DateTime startDate, DateTime endDate) async {
    if (_credentials == null) {
      print("No credentials available. Please sign in first.");
      return "No credentials available.";
    }

    var client = auth.authenticatedClient(
      http.Client(),
      _credentials!,
    );

    var calendarApi = calendar.CalendarApi(client);

    var event = calendar.Event()
      ..summary = 'Course Event: $courseName'
      ..start = calendar.EventDateTime(
        dateTime: startDate.toUtc(),
        timeZone: 'UTC',
      )
      ..end = calendar.EventDateTime(
        dateTime: endDate.toUtc(),
        timeZone: 'UTC',
      )
      ..conferenceData = calendar.ConferenceData(
        createRequest: calendar.CreateConferenceRequest(
          requestId: 'sample${DateTime.now().microsecondsSinceEpoch}',
          conferenceSolutionKey:
              calendar.ConferenceSolutionKey(type: 'hangoutsMeet'),
        ),
      );

    try {
      var createdEvent = await calendarApi.events.insert(
        event,
        'primary',
        conferenceDataVersion: 1,
      );
      return createdEvent.hangoutLink;
    } catch (e) {
      print("Error creating Google Meet event: $e");
      if (e is calendar.DetailedApiRequestError) {
          return "API Error: ${e.message}";
      }
      return "Failed to create Google Meet link.";
    }
  }

  // Sign out method
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _credentials = null;
    print("Signed out successfully.");
  }
}

class GoogleMeetPage extends StatefulWidget {
  final String courseName;
  final String teacherId;
  final String teacherName;
  final String courseType;
  final int maxStudents;
  final String courseDescription;
  final DateTime startDate;
  final DateTime endDate;
  final String selectedTimeFormatted;
  final List<String> selectedDays;
  final double price;
  final Function onFinish;
  final Function onBack;

  const GoogleMeetPage({
    Key? key,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
    required this.courseType,
    required this.maxStudents,
    required this.courseDescription,
    required this.startDate,
    required this.endDate,
    required this.selectedTimeFormatted,
    required this.selectedDays,
    required this.price,
    required this.onFinish,
    required this.onBack,
  }) : super(key: key);

  @override
  _GoogleMeetPageState createState() => _GoogleMeetPageState();
}

class _GoogleMeetPageState extends State<GoogleMeetPage> {
  final CourseFirebaseService _firebaseService = CourseFirebaseService();
  final GoogleMeetService _googleMeetService = GoogleMeetService();

  String? googleMeetLink;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authenticateAndCreateMeetLink();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _authenticateAndCreateMeetLink() async {
    try {
      // Await the sign-in process and check for success
      final bool isSignedIn = await _googleMeetService.signIn();

      if (!isSignedIn) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showMessage("Sign-in failed. Please check your Google account permissions.");
          return;
        }
      }

      final link = await _googleMeetService.createGoogleMeetEvent(
        widget.courseName,
        widget.startDate,
        widget.endDate,
      );

      if (mounted) {
        setState(() {
          googleMeetLink = link;
          _isLoading = false;
        });

        if (link == null || !link.startsWith('http')) {
          _showMessage(link!);
          setState(() {
            googleMeetLink = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          googleMeetLink = null;
          _isLoading = false;
        });
        _showMessage("An unexpected error occurred: $e");
        print("Failed to create Google Meet link: $e");
      }
    }
  }

  Future<void> _saveCourse(String? googleMeetLink) async {
    Map<String, dynamic> courseData = {
      'courseName': widget.courseName,
      'courseDescription': widget.courseDescription,
      'googleMeetLink': googleMeetLink,
      'teacherId': widget.teacherId,
      'teacherName': widget.teacherName,
      'courseType': widget.courseType,
      'maxStudents': widget.maxStudents,
      'startDate': widget.startDate,
      'endDate': widget.endDate,
      'selectedTime': widget.selectedTimeFormatted,
      'selectedDays': widget.selectedDays,
      'enrolledStudents': 0,
      'price': widget.price,
      'createdAt': Timestamp.now(),
    };

    try {
      await _firebaseService.saveCourse(courseData);
      _showMessage("Course saved successfully.");
      print("Course saved successfully.");
    } on FirebaseException catch (e) {
      _showMessage("Error saving course: ${e.message}");
      print("Firebase Error saving course: $e");
    } catch (e) {
      _showMessage("An unexpected error occurred while saving the course.");
      print("Unexpected error saving course: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canFinish = !_isLoading && googleMeetLink != null;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Congrats! We\'re Done',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Course Name:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              AuthTextField(
                controller: TextEditingController(text: widget.courseName),
                hint: 'Course Name',
                icon: Icons.label_outline,
                readOnly: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Teacher Name:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              AuthTextField(
                controller: TextEditingController(text: widget.teacherName),
                hint: 'Teacher Name',
                icon: Icons.person_outline,
                readOnly: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Price (USD):',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              AuthTextField(
                controller: TextEditingController(text: widget.price.toString()),
                hint: 'Price (USD)',
                icon: Icons.attach_money,
                readOnly: true,
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Your Google Meet Link:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : SelectableText(
                              googleMeetLink ?? 'Failed to generate link.',
                              style: const TextStyle(fontSize: 18, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onBack(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text("Back"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canFinish
                          ? () async {
                              await _saveCourse(googleMeetLink);
                              widget.onFinish();
                            }
                          : null,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text("Finish"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canFinish ? AppColors.textColor : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
