# 🩺 Wellness - System Architecture Plan

Welcome to the Wellness Architecture Plan. This document provides a comprehensive overview of the Wellness application's directory structure, technical architecture, and codebase organization as built.

---

## 🗺️ System Architecture Overview

Wellness is a smart, AI-powered health assistant featuring secure JWT authentication, health profile customization, conversational AI chat, heart risk assessment, and specialist directories. The system consists of two primary runtime stacks: the primary production stack (**Flutter + FastAPI**) and the alternative stack (**Next.js + Prisma**).

### 🚀 Primary Production Stack (Flutter + FastAPI)

```mermaid
graph TD
    subgraph Client [Frontend Layer (Flutter + Riverpod)]
        UI[Screens: Auth, Chat, Profile, Risk, Specialist, Contact]
        State[State Management: Riverpod Providers]
        Net[Network: Dio + JWT SecureStorage Interceptor]
    end

    subgraph API [Backend API Layer (FastAPI + SQLite)]
        B_Auth[Auth Endpoints: Register/Login/Logout]
        B_Profile[User Profile Management]
        B_Chat[Gemini AI Session-based Chat]
        B_Risk[Heart Cardiac Risk Calculator]
        B_Spec[Specialist & Hospital Locator]
        B_Misc[Newsletter & Contact Forms]
    end

    subgraph Storage [Database & Tests]
        DB[(SQLite - dev.db)]
        Tests[test_main.py: Integration Tests]
    end

    UI --> State
    State --> Net
    Net -- "HTTPS + Bearer JWT" --> API
    API --> DB
    Tests --> API
```

---

## 📁 Technical Subsystems Analysis

### 1. Flutter Frontend & Client Layer
* **Framework**: Flutter 3.x using Dart.
* **State Management**: Riverpod for reactive state management and dependency injection.
* **Networking**:
  * [dio_provider.dart](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/frontend/lib/core/network/dio_provider.dart) configures the Dio client, managing request headers and attaching JWT authentication tokens retrieved securely via `flutter_secure_storage`.
* **Subsystems & Features (`frontend/lib/features/`)**:
  * `landing`: Public landing page with a features grid, FAQ accordions, and newsletter subscription ([landing_screen.dart](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/frontend/lib/features/landing/presentation/landing_screen.dart)).
  * `auth`: Login & Register screen with JWT authentication flow ([auth_screen.dart](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/frontend/lib/features/auth/presentation/auth_screen.dart)).
  * `chat`: Smart voice/text conversational companion ([dashboard_screen.dart](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/frontend/lib/features/chat/presentation/dashboard_screen.dart)) with session history side drawer ([chat_history_drawer.dart](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/frontend/lib/features/chat/presentation/chat_history_drawer.dart)).
  * `profile`: Interactive health questionnaire modifying backend database models ([health_profile_screen.dart](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/frontend/lib/features/profile/presentation/health_profile_screen.dart)).
  * `risk_assessment`: Form assessing heart health risk factors ([heart_risk_screen.dart](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/frontend/lib/features/risk_assessment/presentation/heart_risk_screen.dart)).
  * `specialist`: Directories for finding medical specialists & nearby hospitals ([specialist_screen.dart](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/frontend/lib/features/specialist/presentation/specialist_screen.dart)).
  * `contact`: General support and enquiry forms ([contact_screen.dart](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/frontend/lib/features/contact/presentation/contact_screen.dart)).

### 2. FastAPI Backend Layer
* **Framework**: FastAPI (Python 3.11+) served via Uvicorn.
* **Database**: SQLite (`dev.db`) with SQLAlchemy ORM.
* **Core API Endpoints (`backend/app/api/`)**:
  * [auth.py](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/backend/app/api/auth.py): Implements secure registration, login (JWT token emission), and logout.
  * [profile.py](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/backend/app/api/profile.py): API for managing user demographic and clinical features.
  * [chat.py](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/backend/app/api/chat.py): Coordinates chat session states and stream integration with the Google Gemini API.
  * [risk.py](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/backend/app/api/risk.py): Cardiac health predictor based on cholesterol, BP, glucose, smoking status, and physical activity.
  * [specialist.py](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/backend/app/api/specialist.py): Recommends specialist domains based on patient symptoms and demographics.
  * [hospitals.py](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/backend/app/api/hospitals.py): Looks up local hospitals and clinics.
  * [newsletter.py](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/backend/app/api/newsletter.py) & [contact.py](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/backend/app/api/contact.py): Support subscriptions and general inquiries.
* **Integration Tests**: [test_main.py](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/backend/test_main.py) runs unittests testing each endpoint.

---

### 🌐 Legacy / Alternative Next.js Web Stack

For web-only deployments, the project maintains an alternative Next.js architecture:

* **Frontend**: Next.js 15 (App Router) + React 18 styled with Tailwind CSS and shadcn/ui.
* **Database & ORM**: Prisma Client linking to SQLite or PostgreSQL.
* **API Middleware**: Route middleware enforcing CORS and strict Content Security Policies.
* **Orchestration**: Integration with Google Genkit Framework and LangGraph agents.
* **Core Modules (`src/`)**:
  * `contexts/AuthContext.tsx`: Manages React authentication state and JWT renewal.
  * `lib/secure-prisma.ts`: Secure wrapper logging queries and checking SQL injections.
  * `components/landing_page/`: Responsive React components (Hero, NavBar, Footer, etc.).

---

## 🤝 Roadmap & Recommendations

1. **Production Deployment**:
   * Migrate the backend SQLite database to a managed PostgreSQL cluster (e.g. Supabase).
   * Deploy the FastAPI backend to a container service (e.g. Render, AWS ECS) and Flutter web/Next.js to Vercel/Firebase hosting.

2. **AI Capabilities Enhancement**:
   * Integrate RAG (Retrieval-Augmented Generation) on certified medical literature in the FastAPI chat service.
   * Expand specialist recommendations using clinical decision-support models.
