# 🩺 Med Genie - System Architecture Plan

Welcome to the Med Genie Architecture Plan. This document provides a comprehensive overview of the Med Genie application's directory structure, technologies, technical architecture, and a roadmap outlining key areas where we (User and AI Agent) can collaborate and contribute.

---

## 🗺️ System Architecture Overview

Med Genie is designed as a state-of-the-art AI-powered health assistant featuring secure JWT authentication, health profile customization, and context-aware medical Q&A. The system consists of three main architectural layers:

```mermaid
graph TD
    subgraph Client [Frontend Layer (Next.js 15 & React 18)]
        UI[Tailwind & shadcn/ui Components]
        Contexts[AuthContext & ThemeProvider]
        Hooks[useChatHistory & useToast]
        Voice[VoiceSearch (Web Speech API)]
    end

    subgraph API [Backend API Layer (Next.js App Router)]
        Mid[Middleware: Security Headers & CORS]
        AuthAPI[Auth Endpoints: Login/Register/Refresh/OAuth]
        UserAPI[User & Profile endpoints]
        HospAPI[Hospital Finder & Newsletter]
    end

    subgraph Security [Security & DB Layer]
        SecUtil[DatabaseSecurity & InputSanitizer]
        JWTUtil[JWT & Token Storage]
        SecureDB[SecurePrisma Wrapper]
        DB[(Prisma Client / SQLite/Postgres)]
    end

    subgraph AI [AI & Orchestration Layer]
        Genkit[Google Genkit Framework]
        Gemini[Gemini 1.5 Flash Model]
        Flows[Personalized Q&A & Specialist Rec Flows]
        LangGraph[LangGraph ReAct Agent]
        Tools[DuckDuckGo & Calculator Tools]
    end

    UI --> Contexts
    Contexts --> API
    API --> Mid
    Mid --> SecUtil
    SecUtil --> SecureDB
    SecureDB --> DB
    API --> Flows
    Flows --> Genkit
    Genkit --> Gemini
    LangGraph --> Tools
    LangGraph --> Gemini
```

---

## 📁 Technical Subsystems Analysis

### 1. Frontend & Client Layer
* **Framework**: Next.js 15 (App Router) with React 18.
* **State & Authentication Context**:
  * [AuthContext.tsx](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/contexts/AuthContext.tsx) handles login, sign-up, JWT validation, token refreshing, and global state persistence.
  * [useChatHistory.ts](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/hooks/use-chat-history.ts) manages chat sessions, renaming, deleting, and storing locally while synchronizing with the user's active session.
* **Core Components**:
  * [ChatInterface.tsx](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/components/ChatInterface.tsx) & [homepage/page.tsx](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/app/homepage/page.tsx): Main dashboard integrating custom chat input, a permanently-visible quick reply grid, particle backgrounds, and the important medical disclaimer.
  * [VoiceSearch.tsx](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/components/VoiceSearch.tsx): Integrated speech-to-text queries utilizing the browser's Web Speech API.
  * [UserProfileModal.tsx](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/components/user-profile-modal.tsx): Dynamic form enabling users to submit optional health factors (medical history, lifestyle, symptoms, allergies, medications) to personalize AI recommendations.

### 2. Backend, API, & Middleware Layer
* **Security Middleware**:
  * [middleware.ts](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/middleware.ts) enforces rigid Content Security Policies (CSP), Frame Options (preventing Clickjacking), Referrer Policies, and CORS headers for APIs.
* **Authentication Infrastructure**:
  * Fully modular routes for registration, token generation, refresh tokens, cookie updates, email availability, and Google OAuth redirection.
* **Location-based Search**:
  * `/api/nearby-hospitals` dynamically searches and responds with hospital details based on query location parameters.

### 3. Database & Security Layer
* **Prisma Schema**:
  * [schema.prisma](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/prisma/schema.prisma) defines rich relational models: `User`, `Session`, `AuditLog`, `HealthProfile`, `ChatSession`, `ChatMessage`, `RateLimit`, `SecurityEvent`, and `NewsletterSubscription`.
* **Prisma Wrapper**:
  * [secure-prisma.ts](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/lib/secure-prisma.ts) wraps queries inside transaction logging hooks, query duration tracking, parameter sanitization, and rate limit validation.
* **Utility Classes**:
  * [database-security.ts](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/lib/database-security.ts): Direct checks for SQL-injection patterns, input length truncation, and email/name regex parsing.
  * [input-sanitizer.ts](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/lib/input-sanitizer.ts): HTML/Script stripping, XSS protection, and logging security events for auditing.

### 4. AI & Orchestration Layer
* **Genkit Framework**:
  * [genkit.ts](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/ai/genkit.ts) handles initial initialization.
* **Personalized Q&A Flow**:
  * [personalized-health-question-answering.ts](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/ai/flows/personalized-health-question-answering.ts) feeds conversation history + health profiles to the Gemini model, requesting structured JSON containing the answers and potential follow-up questions.
* **ReAct Agent & Custom Tools**:
  * [agent.ts](file:///c:/Users/JERANTJENCATH/Desktop/Wellness/src/ai/agent.ts) builds a stateful LangGraph agent that has access to search (`DuckDuckGoSearch`) and calculation (`CalculatorTool` for BMI/Dosage) tools.

---

## 🤝 Collaboration & Contribution Division

To rapidly build and deploy Med Genie, we can divide features based on specialization:

| Area / Feature | 🧑‍💻 User Contribution (Design & Integration) | 🤖 AI Agent Contribution (Implementation & Code) |
| :--- | :--- | :--- |
| **Mobile App (PWA & Flutter)** | • Provide feedback on responsive dashboard styling.<br>• Set up Flutter project settings or native configuration. | • Code custom mobile widgets for the Flutter repository.<br>• Implement Service Workers & manifest assets for standard PWA. |
| **Authentication & Security** | • Set up environment configuration (OAuth provider keys, JWT secrets).<br>• Define user security policies. | • Build Two-Factor Authentication (2FA) flows & API routes.<br>• Add Zod validation schemas to existing login/register endpoints. |
| **AI Personalization & Diagnostics** | • Fine-tune prompts for specialized medical areas (e.g. cardio, pediatric).<br>• Verify medical suggestions & disclaimer tone. | • Integrate advanced LangGraph multi-agent orchestration.<br>• Build specialized specialist avatar API routes and AI workflows. |
| **Location & External APIs** | • Set up location provider API keys (Google Maps API / OpenStreetMap). | • Create a robust local search parser with geo-filtering.<br>• Write integrations for local clinic/hospital registries. |
| **Data Security & Hosting** | • Configure and manage PostgreSQL production databases (e.g., Supabase).<br>• Handle cloud environment secrets. | • Optimize Prisma queries, database indices, and schema migrations.<br>• Implement automated sanitization scripts and DB cleanups. |

---

## 📈 Suggested Roadmap

1. **Phase 1: Deep Security & Validation Polish**
   * Review all open API endpoints and add input-sanitizer hooks to prevent edge-case injections.
   * Add 2FA/Password Reset flows.

2. **Phase 2: Specialized Diagnostics & RAG**
   * Integrate vector search (e.g. Pinecone/Supabase Vector) to support RAG (Retrieval-Augmented Generation) on certified medical literature.
   * Customize specialists (e.g. Cardiologist AI, Nutritionist AI) utilizing tailored system prompts.

3. **Phase 3: Native Integration & Location Services**
   * Replace mock hospital APIs with real Google Maps/OSM search queries.
   * Transition app into an installable Progressive Web App (PWA) with push notifications.
