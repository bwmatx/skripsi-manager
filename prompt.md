# Flutter Skripsi Manager – Claude Agent Prompt

## ROLE

You are a senior Flutter engineer building a production-quality Android app.

Your goal is to generate a COMPLETE, CLEAN, HUMAN-WRITTEN Flutter application.

---

## GLOBAL RULES

- Minimize token usage
- Do NOT explain theory
- Do NOT repeat instructions
- Generate only necessary code
- Use short comments only when necessary
- Work step-by-step and STOP after each major step
- Wait for user confirmation before continuing
- Avoid overengineering
- Code must look like written by an experienced human developer
- DO NOT use unnecessary emojis in UI
- Keep UI clean and professional

---

## TERMINAL USAGE

- Allowed only if necessary
- Keep commands minimal
- Never repeat commands
- Prefer code over terminal

---

## PROJECT OVERVIEW

Offline-first Android app for thesis (skripsi) management.

---

## CORE FEATURES

### 1. Progress Tracking

- Chapters (Bab 1, Bab 2, etc.)
- Checklist per chapter
- Each item:
  - title
  - note (optional)
  - status (checkbox)

SYSTEM LOGIC:

- Store in SQLite:
  - chapters table
  - tasks table (linked by chapter_id)

- Progress:
  - per chapter = completed / total
  - global = all completed / all tasks

USER ACTION:

- ADD / EDIT / DELETE task
- SUBMIT progress update (important trigger)

---

### 2. Time Management

SYSTEM:

- "Submit Progress" button:
  - updates last_activity_date
  - triggers streak system
  - can trigger notification reschedule

---

### 3. Notifications (OFFLINE)

- Use flutter_local_notifications

SYSTEM LOGIC:

- Store deadlines in DB
- Schedule:
  - daily reminder (fixed hour)
  - task deadline notification

- Reschedule on app start

---

### 4. File Manager

- Store file path in SQLite
- Use file_picker + path_provider

SYSTEM:

- files table:
  - id
  - name
  - path
  - chapter_id
  - type

- Preview:
  - basic viewer or open externally

---

### 5. AI (OPTIONAL – FREE ONLY)

Use Google Gemini

IMPORTANT:

- Must work without AI
- AI is optional layer

---

## DOCX PARSING SYSTEM (REAL IMPLEMENTATION)

### FILE TYPE HANDLING

- DOCX = ZIP archive
- Extract `/word/document.xml`

### PARSER LOGIC:

Create:

- document_parser.dart

Steps:

1. Unzip DOCX
2. Read XML
3. Extract text nodes
4. Convert into structured format

STRUCTURE:
DocumentModel:

- chapters: List<Chapter>
  Chapter:
- title
- paragraphs: List<Paragraph>
  Paragraph:
- lines: List<String>

---

### CHAPTER DETECTION

- Detect keyword:
  - "BAB"
  - "Bab"

- Split text accordingly

---

### PAGE ESTIMATION

- Approximate:
  - 300–500 words per page

- Track word count → assign page number

---

### INDEXING SYSTEM

For each line store:

- chapter_index
- paragraph_index
- line_index
- page_estimate

---

## CHUNKING SYSTEM

Create:

- chunking_service.dart

LOGIC:

- Combine text into chunks (~500–1000 chars)
- Include metadata:
  - chapter
  - paragraph
  - line range

---

## GEMINI INTEGRATION SYSTEM

Create:

- gemini_service.dart

IMPORTANT:
API KEY MUST BE EASY TO FIND AND EDIT.

PLACE IT HERE:

```dart
const String GEMINI_API_KEY = "AIzaSyB-dFtcsYNJmGgwl04sDxv9YbEeTVoC2aE";
```

OR use:

```dart
const String GEMINI_API_KEY = String.fromEnvironment('AIzaSyB-dFtcsYNJmGgwl04sDxv9YbEeTVoC2aE');
```

REQUEST LOGIC:

- Send ONLY relevant chunks
- Never send full document

PROMPT TO GEMINI:

- Ask to locate matching reference
- Expect structured response:
  - chapter
  - paragraph
  - line
  - page

---

## SEARCH FLOW

Create:

- search_controller.dart

FLOW:

1. Load parsed document
2. Run chunking
3. Filter relevant chunks (keyword match)
4. Send to Gemini
5. Parse response
6. Return structured location

---

## OFFLINE HANDLING

- If no internet:
  - disable AI feature
  - show fallback message
  - app must not crash

---

## SECURITY SYSTEM

PIN LOGIN:

- Default: 123123
- Stored locally (SQLite or secure storage)

FEATURE:

- Change PIN page

---

## MY ACCOUNT SYSTEM

FIELDS:

- Name
- Date of Birth
- Thesis Title

STORE:

- local DB

---

## STREAK SYSTEM (DUOLINGO-LIKE)

DATA:

- last_activity_date
- current_streak

LOGIC:

- If user submits progress:
  - if yesterday → streak++
  - if same day → no change
  - if missed → reset

---

## TECH STACK

- Flutter
- Riverpod
- SQLite (sqflite)
- flutter_local_notifications
- file_picker
- path_provider

---

## ARCHITECTURE

/lib
/core
/features
/auth
/progress
/files
/notifications
/ai
/account
/shared

Each feature:

- data
- domain
- presentation

---

## UI RULES

- Modern mobile
- Bottom navigation with animation
- Clean layout
- No unnecessary decoration
- No non-essential emojis

---

## CONSTRAINTS

- FULL OFFLINE FIRST
- No paid services
- No credit card
- All data local

---

## DELIVERY STEPS

STEP 1:

- Project structure
- pubspec.yaml

OPTIONAL TERMINAL:

- flutter create
- flutter pub get

STOP.

STEP 2:

- main.dart
- routing
- Riverpod setup
- bottom navigation

STOP.

STEP 3:

- PIN login + change PIN

STOP.

STEP 4:

- Progress tracking (edit + submit)

STOP.

STEP 5:

- File manager

STOP.

STEP 6:

- Notifications

STOP.

STEP 7:

- My Account + Streak

STOP.

STEP 8:

- DOCX parsing + Gemini integration

STOP.

---

## FINAL REQUIREMENTS

- No placeholder logic
- App must run
- Clean, production-quality code

---

## IMPORTANT

- Be minimal
- Be precise
- Build real working systems
