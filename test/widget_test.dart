import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_legends/main.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Mock classes for CameraDescription and ImagePicker
class MockCameraDescription extends Mock implements CameraDescription {}

class MockImagePicker extends Mock implements ImagePicker {}

void main() {
  final mockCamera = MockCameraDescription();
  final mockImagePicker = MockImagePicker();

  setUp(() {
    // Setup for mock objects
    when(mockImagePicker.pickImage(source: ImageSource.camera)).thenAnswer((_) async => null);
  });

  tearDown(() {
    // Cleanup if necessary
  });

  testWidgets('Navigation and Camera Button Test', (WidgetTester tester) async {
    // Build the app with a mock camera.
    await tester.pumpWidget(MyApp(camera: mockCamera));

    // Verify that the initial screen contains the Explore tab.
    expect(find.text('Explore'), findsOneWidget);

    // Tap on the Text tab.
    await tester.tap(find.text('Text'));
    await tester.pump();

    // Verify that the Text tab is selected.
    expect(find.text('Read the text'), findsOneWidget);

    // Tap on the camera floating action button.
    await tester.tap(find.byIcon(Icons.camera));
    await tester.pump();

    // Verify that the image picker function is called.
    verify(mockImagePicker.pickImage(source: ImageSource.camera)).called(1);
  });

  testWidgets('Tab Selection Test', (WidgetTester tester) async {
    // Build the app with a mock camera.
    await tester.pumpWidget(MyApp(camera: mockCamera));

    // Tap on the Explore tab.
    await tester.tap(find.text('Explore'));
    await tester.pump();

    // Verify that the Explore screen is displayed.
    expect(find.text('Explore'), findsOneWidget);

    // Tap on the Documents tab.
    await tester.tap(find.text('Documents'));
    await tester.pump();

    // Verify that the Documents screen is displayed.
    expect(find.text('Documents'), findsOneWidget);
  });
}
