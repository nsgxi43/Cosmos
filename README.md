# Cosmos Wellness

**Live Demo:** [https://cosmos-wellness.vercel.app](https://cosmos-wellness.vercel.app)

---

## Objective

The objective of this project is to address the challenge of "Generative AI for Youth Mental Wellness". Cosmos is a universe-themed wellness companion designed to be a safe, accessible, and non-judgmental outlet for young people to face mental health challenges. It specifically targets Indian youth, aiming to solve the unique stigma around mental health in India where existing applications can feel impersonal or are too expensive.

---

## Features

- **Polaris AI**: A multimodal AI that detects emotions from speech tone, facial cues, and text sentiment. It includes a "Mirror Therapy" feature inspired by Self-Confrontation Therapy. **(Implemented)**
- **AI-Guided Journal**: The application provides AI-guided journaling with gentle prompts suggested based on past conversations and feelings. Users can keep reflections private or share them anonymously on a community blog wall. **(Implemented)**
- **AI Moderation**: All shared posts pass through AI moderation to filter negativity, self-harm, or harmful content. **(Implemented)**
- **Anonymous Community**: Users join with nicknames only, ensuring no stigma. Themed circles connect youth facing similar pressures like exams or career stress. Users who complete healing tasks can become community mentors. **(Under Progress)**
- **Personalized Healing Tasks**: Healing tasks are personalized for each user based on their initial 'What do you feel?' response. **(Under Progress)**
- **Safety Net**: A built-in safety layer detects extreme distress, reassures the user, and can instantly connect them to a trusted loved one chosen during login. **(Under Progress)**

---

## Note on Current Progress

For the current demo, the Journal and Polaris AI features are configured for a single-user experience to effectively showcase the core concept. Multi-user session management and a proper database schema are currently under active development.

---

## Deployment

- **Frontend**: Hosted on Vercel.
- **Backend**: Hosted using DuckDNS on a cloud server.

---

## Tech Stack

-   **Frontend**
    -   Flutter Web (Future expansion to app)
-   **Backend API**
    -   Python + FastAPI
    -   REST + WebSocket APIs
-   **Intelligence Layer**
    -   Google STT and TSS
    -   FunASR
    -   FER Model
    -   Gemini 1.5 (Flash & Pro)
-   **Safety & Trust**
    -   Perspective AI
    -   DialogFlow Agent
-   **Data & Community**
    -   Firebase (Firestore + Auth)
-   **Cloud Infrastructure**
    -   Google Cloud Compute Engine

---

## Frontend File Structure

The Flutter application is organized into several key files, each managing a distinct part of the user experience.

- `main.dart` - Home dashboard with an animated starry background and task management. **(Task Management Under Progress)**
- `ai_page.dart` - Voice/video chat interface with the Polaris AI companion.
- `ai_client.dart` - WebSocket client handling real-time AI communication.
- `journal_page.dart` - Journaling interface with a glassmorphism design.
- `login.dart` - Multi-step onboarding flow with session management. **(Only UI Implemented)**

---

## Backend API Endpoints

The backend exposes the following endpoints for the frontend to consume.

### WebSocket
- `WS /process` - Real-time AI conversation with multimodal input processing.

### REST API

**Journal Management**
- `GET /suggestion/{user_id}` - Get personalized journal writing prompt.
- `POST /journal` - Save journal entry with automatic toxicity filtering.
- `GET /journals/{user_id}` - Retrieve user's personal journal entries.

**Community Features**
- `GET /public_journals` - Fetch all public journal entries from the community.

**Utility**
- `OPTIONS /{full_path:path}` - Handle CORS preflight requests.

*Note: The server runs on port 8000 with full CORS support.*
