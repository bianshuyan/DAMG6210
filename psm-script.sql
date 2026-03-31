USE CourseRegistrationDB;
GO

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

-- ============================================================
-- SP1: Register a student for a course section
-- Validates: student status, section status, capacity, 
--   schedule conflicts, credit hour limits, prerequisites
-- ============================================================
IF OBJECT_ID('dbo.sp_RegisterStudent', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_RegisterStudent;
GO

CREATE PROCEDURE dbo.sp_RegisterStudent
    @StudentID    INT,
    @SectionID    INT,
    @PerformedBy  VARCHAR(50),
    @ResultMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StudentStatus   VARCHAR(20),
            @SectionStatus   VARCHAR(20),
            @Capacity        INT,
            @EnrolledCount   INT,
            @SectionCredits  INT,
            @CourseID        INT,
            @TermID          INT,
            @MaxCredits      INT,
            @CurrentCredits  INT,
            @RegStart        DATE,
            @RegEnd          DATE,
            @Today           DATE = GETDATE(),
            @RegistrationID  INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validate student exists and is Active
        SELECT @StudentStatus = [status], @MaxCredits = max_credit_hours
        FROM dbo.Student
        WHERE student_id = @StudentID;

        IF @StudentStatus IS NULL
        BEGIN
            SET @ResultMessage = 'Error: Student not found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @StudentStatus NOT IN ('Active', 'Probation')
        BEGIN
            SET @ResultMessage = 'Error: Student status (' + @StudentStatus + ') does not allow registration.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 2. Validate section exists and is Open
        SELECT @SectionStatus = [status],
               @Capacity = capacity,
               @EnrolledCount = enrolled_count,
               @SectionCredits = max_credit_hours,
               @CourseID = course_id,
               @TermID = term_id
        FROM dbo.Course_Section
        WHERE section_id = @SectionID;

        IF @SectionStatus IS NULL
        BEGIN
            SET @ResultMessage = 'Error: Section not found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @SectionStatus <> 'Open'
        BEGIN
            SET @ResultMessage = 'Error: Section is ' + @SectionStatus + '.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 3. Check registration window
        SELECT @RegStart = registration_start, @RegEnd = registration_end
        FROM dbo.Term
        WHERE term_id = @TermID;

        IF @Today < @RegStart OR @Today > @RegEnd
        BEGIN
            SET @ResultMessage = 'Error: Registration is not open for this term.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 4. Check duplicate registration
        IF EXISTS (
            SELECT 1 FROM dbo.Registration
            WHERE student_id = @StudentID AND section_id = @SectionID
              AND [status] IN ('Enrolled', 'Waitlisted')
        )
        BEGIN
            SET @ResultMessage = 'Error: Student is already registered or waitlisted for this section.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 5. Check credit hour limit for the term
        SELECT @CurrentCredits = ISNULL(SUM(cs.max_credit_hours), 0)
        FROM dbo.Registration r
        JOIN dbo.Course_Section cs ON r.section_id = cs.section_id
        WHERE r.student_id = @StudentID
          AND cs.term_id = @TermID
          AND r.[status] = 'Enrolled';

        IF (@CurrentCredits + @SectionCredits) > @MaxCredits
        BEGIN
            SET @ResultMessage = 'Error: Registering exceeds max credit hours (' 
                                  + CAST(@MaxCredits AS VARCHAR) + '). Currently enrolled: ' 
                                  + CAST(@CurrentCredits AS VARCHAR) + '.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 6. Check prerequisites
        IF EXISTS (
            SELECT 1
            FROM dbo.Course_Prerequisite cp
            WHERE cp.course_id = @CourseID
              AND NOT EXISTS (
                  SELECT 1
                  FROM dbo.Registration r2
                  JOIN dbo.Course_Section cs2 ON r2.section_id = cs2.section_id
                  WHERE r2.student_id = @StudentID
                    AND cs2.course_id = cp.prerequisite_course_id
                    AND r2.[status] = 'Completed'
                    AND r2.grade IS NOT NULL
                    AND r2.grade <> 'F'
                    AND r2.grade <> 'W'
              )
        )
        BEGIN
            SET @ResultMessage = 'Error: Prerequisites not met for this course.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 7. Check schedule conflict
        IF EXISTS (
            SELECT 1
            FROM dbo.Schedule s_new
            JOIN dbo.Schedule s_existing ON s_new.day_of_week = s_existing.day_of_week
                AND s_new.start_time < s_existing.end_time
                AND s_new.end_time > s_existing.start_time
            JOIN dbo.Registration r ON r.section_id = s_existing.section_id
            JOIN dbo.Course_Section cs ON cs.section_id = s_existing.section_id
            WHERE s_new.section_id = @SectionID
              AND r.student_id = @StudentID
              AND r.[status] = 'Enrolled'
              AND cs.term_id = @TermID
        )
        BEGIN
            SET @ResultMessage = 'Error: Schedule conflict with an existing enrollment.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 8. Register or Waitlist
        IF @EnrolledCount < @Capacity
        BEGIN
            -- Enroll
            INSERT INTO dbo.Registration (student_id, section_id, registration_date, [status], grade)
            VALUES (@StudentID, @SectionID, @Today, 'Enrolled', NULL);

            SET @RegistrationID = SCOPE_IDENTITY();

            UPDATE dbo.Course_Section
            SET enrolled_count = enrolled_count + 1
            WHERE section_id = @SectionID;

            -- Close section if full
            IF (@EnrolledCount + 1) = @Capacity
            BEGIN
                UPDATE dbo.Course_Section
                SET [status] = 'Closed'
                WHERE section_id = @SectionID;
            END

            INSERT INTO dbo.Registration_Audit (registration_id, student_id, section_id, action, action_date, performed_by)
            VALUES (@RegistrationID, @StudentID, @SectionID, 'Registered', @Today, @PerformedBy);

            SET @ResultMessage = 'Success: Student enrolled in section ' + CAST(@SectionID AS VARCHAR) + '.';
        END
        ELSE
        BEGIN
            -- Add to waitlist
            DECLARE @NextPosition INT;
            SELECT @NextPosition = ISNULL(MAX(position), 0) + 1
            FROM dbo.Waitlist
            WHERE section_id = @SectionID;

            INSERT INTO dbo.Registration (student_id, section_id, registration_date, [status], grade)
            VALUES (@StudentID, @SectionID, @Today, 'Waitlisted', NULL);

            SET @RegistrationID = SCOPE_IDENTITY();

            INSERT INTO dbo.Waitlist (student_id, section_id, position, added_date, [status])
            VALUES (@StudentID, @SectionID, @NextPosition, @Today, 'Active');

            INSERT INTO dbo.Registration_Audit (registration_id, student_id, section_id, action, action_date, performed_by)
            VALUES (@RegistrationID, @StudentID, @SectionID, 'Waitlisted', @Today, @PerformedBy);

            SET @ResultMessage = 'Info: Section full. Student added to waitlist at position ' 
                                  + CAST(@NextPosition AS VARCHAR) + '.';
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @ResultMessage = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO


-- ============================================================
-- SP2: Drop a student from a course section
-- Handles: enrolled/waitlisted students, auto-promote from waitlist
-- ============================================================
IF OBJECT_ID('dbo.sp_DropStudent', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_DropStudent;
GO

CREATE PROCEDURE dbo.sp_DropStudent
    @StudentID     INT,
    @SectionID     INT,
    @PerformedBy   VARCHAR(50),
    @ResultMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RegStatus       VARCHAR(20),
            @RegistrationID  INT,
            @TermID          INT,
            @AddDropDeadline DATE,
            @Today           DATE = GETDATE(),
            @NextStudentID   INT,
            @NextWaitlistID  INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Find the registration
        SELECT @RegistrationID = registration_id, @RegStatus = [status]
        FROM dbo.Registration
        WHERE student_id = @StudentID AND section_id = @SectionID
          AND [status] IN ('Enrolled', 'Waitlisted');

        IF @RegistrationID IS NULL
        BEGIN
            SET @ResultMessage = 'Error: No active enrollment or waitlist record found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 2. Check add/drop deadline
        SELECT @TermID = term_id FROM dbo.Course_Section WHERE section_id = @SectionID;

        SELECT @AddDropDeadline = add_drop_deadline
        FROM dbo.Term
        WHERE term_id = @TermID;

        IF @Today > @AddDropDeadline
        BEGIN
            -- After deadline, mark grade as W
            UPDATE dbo.Registration
            SET [status] = 'Dropped', grade = 'W'
            WHERE registration_id = @RegistrationID;
        END
        ELSE
        BEGIN
            UPDATE dbo.Registration
            SET [status] = 'Dropped', grade = NULL
            WHERE registration_id = @RegistrationID;
        END

        -- 3. If student was enrolled, decrement count and try to promote waitlist
        IF @RegStatus = 'Enrolled'
        BEGIN
            UPDATE dbo.Course_Section
            SET enrolled_count = enrolled_count - 1,
                [status] = 'Open'
            WHERE section_id = @SectionID;

            -- Promote next waitlisted student
            SELECT TOP 1 @NextWaitlistID = waitlist_id, @NextStudentID = student_id
            FROM dbo.Waitlist
            WHERE section_id = @SectionID AND [status] = 'Active'
            ORDER BY position;

            IF @NextStudentID IS NOT NULL
            BEGIN
                UPDATE dbo.Waitlist
                SET [status] = 'Offered'
                WHERE waitlist_id = @NextWaitlistID;

                -- Auto-enroll the promoted student
                UPDATE dbo.Registration
                SET [status] = 'Enrolled'
                WHERE student_id = @NextStudentID AND section_id = @SectionID AND [status] = 'Waitlisted';

                UPDATE dbo.Course_Section
                SET enrolled_count = enrolled_count + 1
                WHERE section_id = @SectionID;
            END
        END
        ELSE
        BEGIN
            -- Remove from waitlist
            UPDATE dbo.Waitlist
            SET [status] = 'Removed'
            WHERE student_id = @StudentID AND section_id = @SectionID;
        END

        -- 4. Audit
        INSERT INTO dbo.Registration_Audit (registration_id, student_id, section_id, action, action_date, performed_by)
        VALUES (@RegistrationID, @StudentID, @SectionID, 'Dropped', @Today, @PerformedBy);

        COMMIT TRANSACTION;

        SET @ResultMessage = 'Success: Student dropped from section ' + CAST(@SectionID AS VARCHAR) + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @ResultMessage = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO


-- ============================================================
-- SP3: Swap a student from one section to another
-- Atomically drops from old section and registers in new section
-- ============================================================
IF OBJECT_ID('dbo.sp_SwapSection', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_SwapSection;
GO

CREATE PROCEDURE dbo.sp_SwapSection
    @StudentID       INT,
    @OldSectionID    INT,
    @NewSectionID    INT,
    @PerformedBy     VARCHAR(50),
    @ResultMessage   NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OldRegID       INT,
            @NewCapacity    INT,
            @NewEnrolled    INT,
            @NewStatus      VARCHAR(20),
            @OldTermID      INT,
            @NewTermID      INT,
            @Today          DATE = GETDATE();

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validate current enrollment
        SELECT @OldRegID = registration_id
        FROM dbo.Registration
        WHERE student_id = @StudentID AND section_id = @OldSectionID AND [status] = 'Enrolled';

        IF @OldRegID IS NULL
        BEGIN
            SET @ResultMessage = 'Error: Student is not enrolled in the old section.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 2. Validate both sections are in the same term
        SELECT @OldTermID = term_id FROM dbo.Course_Section WHERE section_id = @OldSectionID;
        SELECT @NewTermID = term_id, @NewStatus = [status], @NewCapacity = capacity, @NewEnrolled = enrolled_count
        FROM dbo.Course_Section WHERE section_id = @NewSectionID;

        IF @OldTermID <> @NewTermID
        BEGIN
            SET @ResultMessage = 'Error: Sections must be in the same term to swap.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @NewStatus <> 'Open'
        BEGIN
            SET @ResultMessage = 'Error: New section is not open.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @NewEnrolled >= @NewCapacity
        BEGIN
            SET @ResultMessage = 'Error: New section is full.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 3. Check schedule conflict (exclude old section)
        IF EXISTS (
            SELECT 1
            FROM dbo.Schedule s_new
            JOIN dbo.Schedule s_existing ON s_new.day_of_week = s_existing.day_of_week
                AND s_new.start_time < s_existing.end_time
                AND s_new.end_time > s_existing.start_time
            JOIN dbo.Registration r ON r.section_id = s_existing.section_id
            JOIN dbo.Course_Section cs ON cs.section_id = s_existing.section_id
            WHERE s_new.section_id = @NewSectionID
              AND r.student_id = @StudentID
              AND r.[status] = 'Enrolled'
              AND cs.term_id = @NewTermID
              AND s_existing.section_id <> @OldSectionID
        )
        BEGIN
            SET @ResultMessage = 'Error: Schedule conflict with the new section.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- 4. Drop from old section
        UPDATE dbo.Registration
        SET [status] = 'Swapped'
        WHERE registration_id = @OldRegID;

        UPDATE dbo.Course_Section
        SET enrolled_count = enrolled_count - 1, [status] = 'Open'
        WHERE section_id = @OldSectionID;

        -- 5. Enroll in new section
        INSERT INTO dbo.Registration (student_id, section_id, registration_date, [status], grade)
        VALUES (@StudentID, @NewSectionID, @Today, 'Enrolled', NULL);

        UPDATE dbo.Course_Section
        SET enrolled_count = enrolled_count + 1
        WHERE section_id = @NewSectionID;

        IF (@NewEnrolled + 1) = @NewCapacity
        BEGIN
            UPDATE dbo.Course_Section SET [status] = 'Closed' WHERE section_id = @NewSectionID;
        END

        -- 6. Audit
        INSERT INTO dbo.Registration_Audit (registration_id, student_id, section_id, action, action_date, performed_by)
        VALUES (@OldRegID, @StudentID, @OldSectionID, 'Swapped', @Today, @PerformedBy);

        COMMIT TRANSACTION;

        SET @ResultMessage = 'Success: Swapped from section ' + CAST(@OldSectionID AS VARCHAR) 
                              + ' to section ' + CAST(@NewSectionID AS VARCHAR) + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @ResultMessage = 'Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO


-- ============================================================
-- VIEWS
-- ============================================================

-- ============================================================
-- View 1: Course Enrollment Summary
-- ============================================================
IF OBJECT_ID('dbo.vw_CourseEnrollmentSummary', 'V') IS NOT NULL DROP VIEW dbo.vw_CourseEnrollmentSummary;
GO

CREATE VIEW dbo.vw_CourseEnrollmentSummary
AS
SELECT
    t.name                  AS TermName,
    c.course_code           AS CourseCode,
    c.title                 AS CourseTitle,
    i.first_name + ' ' + i.last_name AS InstructorName,
    cl.building + ' ' + cl.room_number AS ClassroomLocation,
    cs.capacity             AS SectionCapacity,
    cs.enrolled_count       AS EnrolledCount,
    cs.capacity - cs.enrolled_count AS AvailableSeats,
    cs.[status]             AS SectionStatus,
    CAST(ROUND(cs.enrolled_count * 100.0 / cs.capacity, 1) AS DECIMAL(5,1)) AS FillRatePercent
FROM dbo.Course_Section cs
JOIN dbo.Course c      ON cs.course_id = c.course_id
JOIN dbo.Term t        ON cs.term_id = t.term_id
JOIN dbo.Instructor i  ON cs.instructor_id = i.instructor_id
JOIN dbo.Classroom cl  ON cs.classroom_id = cl.classroom_id;
GO


-- ============================================================
-- View 2: Student Registration Details
-- ============================================================
IF OBJECT_ID('dbo.vw_StudentRegistrationDetails', 'V') IS NOT NULL DROP VIEW dbo.vw_StudentRegistrationDetails;
GO

CREATE VIEW dbo.vw_StudentRegistrationDetails
AS
SELECT
    s.student_id,
    s.first_name + ' ' + s.last_name AS StudentName,
    s.email                           AS StudentEmail,
    s.[status]                        AS StudentStatus,
    c.course_code,
    c.title                           AS CourseTitle,
    t.name                            AS TermName,
    r.[status]                        AS RegistrationStatus,
    r.grade,
    r.registration_date,
    sch.day_of_week,
    sch.start_time,
    sch.end_time,
    i.first_name + ' ' + i.last_name AS InstructorName
FROM dbo.Registration r
JOIN dbo.Student s         ON r.student_id = s.student_id
JOIN dbo.Course_Section cs ON r.section_id = cs.section_id
JOIN dbo.Course c          ON cs.course_id = c.course_id
JOIN dbo.Term t            ON cs.term_id = t.term_id
JOIN dbo.Instructor i      ON cs.instructor_id = i.instructor_id
LEFT JOIN dbo.Schedule sch ON cs.section_id = sch.section_id;
GO


-- ============================================================
-- View 3: Waitlist Status Report
-- ============================================================
IF OBJECT_ID('dbo.vw_WaitlistReport', 'V') IS NOT NULL DROP VIEW dbo.vw_WaitlistReport;
GO

CREATE VIEW dbo.vw_WaitlistReport
AS
SELECT
    w.waitlist_id,
    s.first_name + ' ' + s.last_name AS StudentName,
    s.email                           AS StudentEmail,
    c.course_code,
    c.title                           AS CourseTitle,
    t.name                            AS TermName,
    w.position,
    w.added_date,
    w.[status]                        AS WaitlistStatus,
    cs.capacity                       AS SectionCapacity,
    cs.enrolled_count                 AS CurrentEnrolled
FROM dbo.Waitlist w
JOIN dbo.Student s         ON w.student_id = s.student_id
JOIN dbo.Course_Section cs ON w.section_id = cs.section_id
JOIN dbo.Course c          ON cs.course_id = c.course_id
JOIN dbo.Term t            ON cs.term_id = t.term_id;
GO


-- ============================================================
-- USER-DEFINED FUNCTIONS
-- ============================================================

-- ============================================================
-- UDF 1: Get total enrolled credits for a student in a term
-- ============================================================
IF OBJECT_ID('dbo.fn_GetEnrolledCredits', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_GetEnrolledCredits;
GO

CREATE FUNCTION dbo.fn_GetEnrolledCredits
(
    @StudentID INT,
    @TermID    INT
)
RETURNS INT
AS
BEGIN
    DECLARE @TotalCredits INT;

    SELECT @TotalCredits = ISNULL(SUM(cs.max_credit_hours), 0)
    FROM dbo.Registration r
    JOIN dbo.Course_Section cs ON r.section_id = cs.section_id
    WHERE r.student_id = @StudentID
      AND cs.term_id = @TermID
      AND r.[status] IN ('Enrolled', 'Completed');

    RETURN @TotalCredits;
END;
GO


-- ============================================================
-- UDF 2: Check if a student has met prerequisites for a course
-- Returns 1 if all prerequisites are met, 0 otherwise
-- ============================================================
IF OBJECT_ID('dbo.fn_CheckPrerequisites', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_CheckPrerequisites;
GO

CREATE FUNCTION dbo.fn_CheckPrerequisites
(
    @StudentID INT,
    @CourseID  INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @MetAll BIT = 1;

    IF EXISTS (
        SELECT 1
        FROM dbo.Course_Prerequisite cp
        WHERE cp.course_id = @CourseID
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.Registration r
              JOIN dbo.Course_Section cs ON r.section_id = cs.section_id
              WHERE r.student_id = @StudentID
                AND cs.course_id = cp.prerequisite_course_id
                AND r.[status] = 'Completed'
                AND r.grade IS NOT NULL
                AND r.grade NOT IN ('F', 'W')
          )
    )
    BEGIN
        SET @MetAll = 0;
    END

    RETURN @MetAll;
END;
GO


-- ============================================================
-- UDF 3: Table-valued function - Get a student's full schedule for a term
-- ============================================================
IF OBJECT_ID('dbo.fn_GetStudentSchedule', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_GetStudentSchedule;
GO

CREATE FUNCTION dbo.fn_GetStudentSchedule
(
    @StudentID INT,
    @TermID    INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        c.course_code,
        c.title           AS CourseTitle,
        sch.day_of_week,
        sch.start_time,
        sch.end_time,
        cl.building + ' ' + cl.room_number AS Classroom,
        i.first_name + ' ' + i.last_name   AS Instructor
    FROM dbo.Registration r
    JOIN dbo.Course_Section cs ON r.section_id = cs.section_id
    JOIN dbo.Course c          ON cs.course_id = c.course_id
    JOIN dbo.Schedule sch      ON cs.section_id = sch.section_id
    JOIN dbo.Classroom cl      ON cs.classroom_id = cl.classroom_id
    JOIN dbo.Instructor i      ON cs.instructor_id = i.instructor_id
    WHERE r.student_id = @StudentID
      AND cs.term_id = @TermID
      AND r.[status] = 'Enrolled'
);
GO


-- ============================================================
-- DML TRIGGER: Auto-audit on Registration INSERT/UPDATE
-- ============================================================
IF OBJECT_ID('dbo.trg_Registration_AuditLog', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_Registration_AuditLog;
GO

CREATE TRIGGER dbo.trg_Registration_AuditLog
ON dbo.Registration
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only fire when status changes
    INSERT INTO dbo.Registration_Audit (registration_id, student_id, section_id, action, action_date, performed_by)
    SELECT
        i.registration_id,
        i.student_id,
        i.section_id,
        CASE i.[status]
            WHEN 'Enrolled'   THEN 'Registered'
            WHEN 'Dropped'    THEN 'Dropped'
            WHEN 'Waitlisted' THEN 'Waitlisted'
            WHEN 'Swapped'    THEN 'Swapped'
            WHEN 'Completed'  THEN 'Completed'
            ELSE 'Approved'
        END,
        GETDATE(),
        SYSTEM_USER
    FROM inserted i
    JOIN deleted d ON i.registration_id = d.registration_id
    WHERE i.[status] <> d.[status];
END;
GO

PRINT 'PSM Script executed successfully.';
GO
