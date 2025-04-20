# The Flying Dutchman - Your AI Mental Health Assistant

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Gemini AI](https://img.shields.io/badge/Gemini_AI-000000?style=for-the-badge&logo=google-gemini&logoColor=white)](https://ai.google.dev/)
[![Speech-to-Text](https://img.shields.io/badge/Speech_to_Text-grey?style=for-the-badge&logo=microphone&logoColor=white)](https://pub.dev/packages/speech_to_text)
[![Text-to-Speech](https://img.shields.io/badge/Text_to_Speech-grey?style=for-the-badge&logo=speaker&logoColor=white)](https://pub.dev/packages/flutter_tts)
[![Local Notifications](https://img.shields.io/badge/Local_Notifications-grey?style=for-the-badge&logo=bell&logoColor=white)](https://pub.dev/packages/flutter_local_notifications)
[![Shared Preferences](https://img.shields.io/badge/Shared_Preferences-grey?style=for-the-badge&logo=data-saver&logoColor=white)](https://pub.dev/packages/shared_preferences)
[![Flutter SVG](https://img.shields.io/badge/Flutter_SVG-FF9900?style=for-the-badge&logo=flutter&logoColor=white)](https://pub.dev/packages/flutter_svg)
[![Permission Handler](https://img.shields.io/badge/Permission_Handler-grey?style=for-the-badge&logo=lock&logoColor=white)](https://pub.dev/packages/permission_handler)

## Project Overview

**The Flying Dutchman** is a Flutter-based mobile application designed to be your personal AI mental health assistant. Leveraging the power of Google's Gemini AI model, it offers empathetic and supportive conversations, suggests healthy coping strategies, and helps users manage their medication through timely reminders.

This project was created by **Chater Marzougui** as part of the **AI Anatomy Project** at **Sup'Com** on **April 20, 2025**. Its primary purpose is to assist users in understanding how to use their medications and to provide helpful reminders.

## Features

* **Interactive Chat Interface:** Engage in natural language conversations with the AI assistant.
* **Empathetic and Supportive Responses:** Receive caring and understanding feedback for your mental well-being.
* **Healthy Coping Strategies:** Get suggestions for managing stress and improving mental health.
* **Medication Reminders:** Schedule and receive timely notifications to take your medications.
* **Medication Information:** Ask about your medications to get their names and descriptions.
* **Time Input Processing:** Provide medication times in a natural format, and the app will recognize and schedule reminders accordingly.
* **Speech-to-Text:** Use your voice to send messages to the AI.
* **Text-to-Speech:** Hear the AI's responses read aloud.
* **Theme Switching:** Toggle between light and dark mode for comfortable use in any environment.
* **Language Support:** The chatbot attempts to respond in the same language as your last message (initially supports English, French, and Arabic for TTS).
* **Persistent Data:** Medication reminders are saved locally using `shared_preferences`.

## Technologies Used

* **Flutter:** A UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase.
* **Google Generative AI (Gemini):** A powerful language model used for conversational AI.
* **`speech_to_text`:** A Flutter plugin for converting speech to text.
* **`flutter_tts`:** A Flutter plugin for text-to-speech functionality.
* **`flutter_local_notifications`:** A Flutter plugin for displaying local notifications.
* **`shared_preferences`:** A Flutter plugin for reading and writing simple data to local storage.
* **`flutter_svg`:** A Flutter plugin for rendering Scalable Vector Graphics (SVG) in Flutter.
* **`permission_handler`:** A Flutter plugin for requesting and checking permissions on Android and iOS.
* **`timezone`:** A Flutter plugin for working with time zones.

## Getting Started

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/chater-marzougui/AI-Anatomy.git](https://github.com/chater-marzougui/AI-Anatomy.git)
    cd the-flying-dutchman
    ```

2.  **Ensure Flutter is installed:**
    If you don't have Flutter installed, follow the instructions on the official Flutter website: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)

3.  **Get Flutter dependencies:**
    ```bash
    flutter pub get
    ```

4.  **Obtain a Gemini API Key:**
    You will need an API key from Google AI Studio to use the Gemini model. Follow the instructions here: [https://ai.google.dev/tutorials/setup](https://ai.google.dev/tutorials/setup)

5.  **Replace the API Key:**
    Open the `main.dart` file and replace the placeholder API key with your own key:
    ```dart
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: 'YOUR_API_KEY');
    ```

6.  **Run the application:**
    Connect a physical device or start an emulator/simulator and run the app:
    ```bash
    flutter run
    ```

## Project Structure