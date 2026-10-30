-- Part (c): bug ticket database. Seed tickets come from the ADK software-bug-assistant
-- sample; embeddings are filled by scripts/embed_backfill.py (gemini-embedding-001, 768-d).
\connect ticketsdb
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE tickets (
    ticket_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    assignee VARCHAR(100),
    priority VARCHAR(50),
    status VARCHAR(50) DEFAULT 'Open',
    creation_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    embedding vector(768)
);
CREATE INDEX tickets_embedding_hnsw ON tickets USING hnsw (embedding vector_cosine_ops);

CREATE OR REPLACE FUNCTION update_updated_time_tickets() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_time = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tickets_updated_time
BEFORE UPDATE ON tickets FOR EACH ROW EXECUTE PROCEDURE update_updated_time_tickets();

INSERT INTO tickets (title, description, assignee, priority, status, creation_time) VALUES
('Login Page Freezes After Multiple Failed Attempts', 'Users are reporting that after 3 failed login attempts, the login page becomes unresponsive and requires a refresh. No specific error message is displayed.', 'samuel.green@example.com', 'P0 - Critical', 'Open', now() - interval '12 days'),
('Dashboard Sales Widget Intermittent Data Loading Failure', 'The "Sales Overview" widget on the main dashboard intermittently shows a loading spinner but no data. Primarily affects Chrome browser users.', 'maria.rodriguez@example.com', 'P1 - High', 'In Progress', now() - interval '10 days'),
('Broken Link in Footer - Privacy Policy', 'The "Privacy Policy" hyperlink located in the website footer leads to a 404 "Page Not Found" error.', 'maria.rodriguez@example.com', 'P3 - Low', 'Resolved', now() - interval '30 days'),
('UI Misalignment on Mobile Landscape View (iOS)', 'On specific iOS devices (e.g., iPhone 14 models), the top navigation bar shifts downwards when the device is viewed in landscape orientation, obscuring content.', 'maria.rodriguez@example.com', 'P2 - Medium', 'In Progress', now() - interval '8 days'),
('Critical XZ Utils Backdoor Detected in Core Dependency (CVE-2024-3094)', 'Urgent: A sophisticated supply chain compromise (CVE-2024-3094) has been identified in XZ Utils versions 5.6.0 and 5.6.1. This malicious code potentially allows unauthorized remote SSH access by modifying liblzma. Immediate investigation and action required for affected Linux/Unix systems and services relying on XZ Utils.', 'frank.white@example.com', 'P0 - Critical', 'Open', now() - interval '3 days'),
('Database Connection Timeouts During Peak Usage', 'The application is experiencing frequent database connection timeouts, particularly during peak hours (10 AM - 12 PM EDT), affecting all users and causing service interruptions.', 'frank.white@example.com', 'P1 - High', 'Open', now() - interval '5 days'),
('Export to PDF Truncates Long Text Fields in Reports', 'When generating PDF exports of reports containing extensive text fields, the text is abruptly cut off at the end of the page instead of wrapping or continuing to the next page.', 'samuel.green@example.com', 'P1 - High', 'Open', now() - interval '6 days'),
('Search Filter "Date Range" Not Applying Correctly', 'The "Date Range" filter on the search results page does not filter records accurately; results outside the specified date range are still displayed.', 'samuel.green@example.com', 'P2 - Medium', 'Resolved', now() - interval '20 days'),
('Typo in Error Message: "Unathorized Access"', 'The error message displayed when a user attempts an unauthorized action reads "Unathorized Access" instead of "Unauthorized Access."', 'maria.rodriguez@example.com', 'P3 - Low', 'Resolved', now() - interval '25 days'),
('Intermittent File Upload Failures for Large Files', 'Users are intermittently reporting that file uploads fail without a clear error message or explanation, especially for files exceeding 10MB in size.', 'frank.white@example.com', 'P1 - High', 'Open', now() - interval '2 days');
