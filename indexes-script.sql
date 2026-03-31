USE CourseRegistrationDB;
GO

-- ============================================================
-- NON-CLUSTERED INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================

-- Index 1: Speed up lookups on Registration by student + status
-- Used heavily in enrollment checks, schedule conflict detection, credit calculations
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Registration_StudentID_Status' AND object_id = OBJECT_ID('dbo.Registration'))
    DROP INDEX IX_Registration_StudentID_Status ON dbo.Registration;
GO

CREATE NONCLUSTERED INDEX IX_Registration_StudentID_Status
ON dbo.Registration (student_id, [status])
INCLUDE (section_id, grade, registration_date);
GO

-- Index 2: Speed up lookups on Course_Section by term and status
-- Used in enrollment summary views and registration validation
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CourseSection_TermID_Status' AND object_id = OBJECT_ID('dbo.Course_Section'))
    DROP INDEX IX_CourseSection_TermID_Status ON dbo.Course_Section;
GO

CREATE NONCLUSTERED INDEX IX_CourseSection_TermID_Status
ON dbo.Course_Section (term_id, [status])
INCLUDE (course_id, instructor_id, classroom_id, capacity, enrolled_count);
GO

-- Index 3: Speed up waitlist queries by section and status ordered by position
-- Used in waitlist promotion logic and reporting
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Waitlist_SectionID_Status_Position' AND object_id = OBJECT_ID('dbo.Waitlist'))
    DROP INDEX IX_Waitlist_SectionID_Status_Position ON dbo.Waitlist;
GO

CREATE NONCLUSTERED INDEX IX_Waitlist_SectionID_Status_Position
ON dbo.Waitlist (section_id, [status], position)
INCLUDE (student_id, added_date);
GO

-- Index 4: Speed up schedule conflict detection
-- Joins on section_id with day/time range checks
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Schedule_SectionID_Day_Time' AND object_id = OBJECT_ID('dbo.Schedule'))
    DROP INDEX IX_Schedule_SectionID_Day_Time ON dbo.Schedule;
GO

CREATE NONCLUSTERED INDEX IX_Schedule_SectionID_Day_Time
ON dbo.Schedule (section_id, day_of_week, start_time, end_time);
GO

-- Index 5: Speed up prerequisite checks by course
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CoursePrerequisite_CourseID' AND object_id = OBJECT_ID('dbo.Course_Prerequisite'))
    DROP INDEX IX_CoursePrerequisite_CourseID ON dbo.Course_Prerequisite;
GO

CREATE NONCLUSTERED INDEX IX_CoursePrerequisite_CourseID
ON dbo.Course_Prerequisite (course_id)
INCLUDE (prerequisite_course_id, minimum_grade);
GO

-- Index 6: Speed up audit trail queries by student and action date
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RegistrationAudit_StudentID_ActionDate' AND object_id = OBJECT_ID('dbo.Registration_Audit'))
    DROP INDEX IX_RegistrationAudit_StudentID_ActionDate ON dbo.Registration_Audit;
GO

CREATE NONCLUSTERED INDEX IX_RegistrationAudit_StudentID_ActionDate
ON dbo.Registration_Audit (student_id, action_date)
INCLUDE (section_id, action, performed_by);
GO

PRINT 'Indexes created successfully.';
GO
