# idstack Chrome Extension: Full-Course Crawler

## Overview
Currently, the idstack Chrome Extension audits individual pages (e.g., a single Canvas assignment or syllabus). This feature expands the extension's capabilities to audit an entire Canvas course at once. When a user is on a Canvas course homepage, the extension will provide an "Audit Entire Course" option.

## Architecture & Data Flow

### 1. Context Detection & UI
- **Content Script (`extractor.js`)**: Updated to detect if the current URL is a Canvas course homepage (matches `*/courses/:course_id` without specific sub-pages like `/assignments`).
- **Side Panel UI (`index.html` / `sidepanel.js`)**: 
  - If a course homepage is detected, the UI displays a primary "Audit Entire Course" button.
  - A progress indicator UI will be added to show the status of the background crawl (e.g., "Fetching course data...", "Analyzing alignment...").
  - A link to "Get a free Google AI Studio API key" will be added to the Settings drawer to encourage users to move beyond the demo mode.

### 2. The Canvas API Crawler
- **Background Worker (`service-worker.js`)**:
  - Implements a new handler for a `CRAWL_COURSE` message.
  - Uses native `fetch()` calls to the Canvas REST API endpoints:
    - `GET /api/v1/courses/:course_id?include[]=syllabus_body` (Course info & Syllabus)
    - `GET /api/v1/courses/:course_id/assignments` (Assignments & Rubrics)
  - **Authentication**: Inherits the user's active Canvas session cookies automatically. No OAuth or API tokens needed.
  - **Data Processing**: Extracts raw text, strips HTML tags, and aggregates the content.
  - **Data Cap**: Implements a safety limit (e.g., 40,000 characters) on the aggregated payload to prevent LLM token limits from being exceeded.

### 3. LLM Integration & Presentation
- **Prompt Generation (`prompts.js`)**: A new prompt variant will be created for course-level audits, asking the LLM to assess constructive alignment across the aggregated syllabus and assignments.
- **Rendering**: The course audit results will reuse the existing scholarly `DESIGN.md` presentation, rendering T1-T5 evidence badges and actionable recommendations.

## Error Handling
- If the Canvas API fetch fails (e.g., network error or permission denied), the side panel will display the existing inline error banner with a clear message.
- If the course data exceeds the character limit, it will be safely truncated before being sent to the LLM.

## Testing Strategy
- Unit tests will be added to mock the Canvas API responses and verify the crawler's data aggregation and truncation logic.
- The UI tests will be updated to cover the new "Audit Entire Course" state and progress indicators.
