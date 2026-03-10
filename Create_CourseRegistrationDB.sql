USE master;
GO

IF DB_ID('CourseRegistrationDB') IS NOT NULL
BEGIN
    ALTER DATABASE CourseRegistrationDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CourseRegistrationDB;
END
GO

CREATE DATABASE CourseRegistrationDB;
GO

USE CourseRegistrationDB;
GO

-- Drop objects if they already exist inside the database
IF OBJECT_ID('dbo.Registration_Audit', 'U') IS NOT NULL DROP TABLE dbo.Registration_Audit;
IF OBJECT_ID('dbo.Waitlist', 'U') IS NOT NULL DROP TABLE dbo.Waitlist;
IF OBJECT_ID('dbo.Registration', 'U') IS NOT NULL DROP TABLE dbo.Registration;
IF OBJECT_ID('dbo.Schedule', 'U') IS NOT NULL DROP TABLE dbo.Schedule;
IF OBJECT_ID('dbo.Course_Prerequisite', 'U') IS NOT NULL DROP TABLE dbo.Course_Prerequisite;
IF OBJECT_ID('dbo.Course_Section', 'U') IS NOT NULL DROP TABLE dbo.Course_Section;
IF OBJECT_ID('dbo.Student', 'U') IS NOT NULL DROP TABLE dbo.Student;
IF OBJECT_ID('dbo.Course', 'U') IS NOT NULL DROP TABLE dbo.Course;
IF OBJECT_ID('dbo.Instructor', 'U') IS NOT NULL DROP TABLE dbo.Instructor;
IF OBJECT_ID('dbo.Classroom', 'U') IS NOT NULL DROP TABLE dbo.Classroom;
IF OBJECT_ID('dbo.Admin_User', 'U') IS NOT NULL DROP TABLE dbo.Admin_User;
IF OBJECT_ID('dbo.Term', 'U') IS NOT NULL DROP TABLE dbo.Term;
GO

CREATE TABLE dbo.Term (
    term_id INT IDENTITY(1,1) NOT NULL,
    name VARCHAR(50) NOT NULL,
    season VARCHAR(10) NOT NULL,
    [year] INT NOT NULL,
    registration_start DATE NOT NULL,
    registration_end DATE NOT NULL,
    add_drop_deadline DATE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    CONSTRAINT PK_Term PRIMARY KEY (term_id),
    CONSTRAINT UQ_Term_Name UNIQUE (name),
    CONSTRAINT CK_Term_Season CHECK (season IN ('Spring', 'Summer', 'Fall', 'Winter')),
    CONSTRAINT CK_Term_Year CHECK ([year] BETWEEN 2020 AND 2035),
    CONSTRAINT CK_Term_Dates CHECK (
        registration_start <= registration_end
        AND registration_end <= add_drop_deadline
        AND start_date < end_date
        AND add_drop_deadline <= end_date
    )
);
GO

CREATE TABLE dbo.Admin_User (
    admin_id INT IDENTITY(1,1) NOT NULL,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    [role] VARCHAR(30) NOT NULL,
    permissions VARCHAR(200) NOT NULL,
    CONSTRAINT PK_Admin_User PRIMARY KEY (admin_id),
    CONSTRAINT UQ_Admin_User_Username UNIQUE (username),
    CONSTRAINT UQ_Admin_User_Email UNIQUE (email),
    CONSTRAINT CK_Admin_User_Role CHECK ([role] IN ('Registrar', 'Scheduler', 'DepartmentAdmin', 'SuperAdmin'))
);
GO

CREATE TABLE dbo.Classroom (
    classroom_id INT IDENTITY(1,1) NOT NULL,
    building VARCHAR(60) NOT NULL,
    room_number VARCHAR(20) NOT NULL,
    capacity INT NOT NULL,
    CONSTRAINT PK_Classroom PRIMARY KEY (classroom_id),
    CONSTRAINT UQ_Classroom UNIQUE (building, room_number),
    CONSTRAINT CK_Classroom_Capacity CHECK (capacity BETWEEN 10 AND 500)
);
GO

CREATE TABLE dbo.Instructor (
    instructor_id INT IDENTITY(1,1) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,
    CONSTRAINT PK_Instructor PRIMARY KEY (instructor_id),
    CONSTRAINT UQ_Instructor_Email UNIQUE (email)
);
GO

CREATE TABLE dbo.Course (
    course_id INT IDENTITY(1,1) NOT NULL,
    course_code VARCHAR(20) NOT NULL,
    title VARCHAR(120) NOT NULL,
    description VARCHAR(300) NULL,
    credit_hours INT NOT NULL,
    department VARCHAR(100) NOT NULL,
    CONSTRAINT PK_Course PRIMARY KEY (course_id),
    CONSTRAINT UQ_Course_Code UNIQUE (course_code),
    CONSTRAINT CK_Course_CreditHours CHECK (credit_hours BETWEEN 1 AND 6)
);
GO

CREATE TABLE dbo.Student (
    student_id INT IDENTITY(1,1) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NULL,
    credit_hours_completed INT NOT NULL CONSTRAINT DF_Student_Credits DEFAULT (0),
    max_credit_hours INT NOT NULL CONSTRAINT DF_Student_MaxCredits DEFAULT (18),
    [status] VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Student PRIMARY KEY (student_id),
    CONSTRAINT UQ_Student_Email UNIQUE (email),
    CONSTRAINT CK_Student_Credits CHECK (credit_hours_completed >= 0 AND max_credit_hours BETWEEN 3 AND 21),
    CONSTRAINT CK_Student_Status CHECK ([status] IN ('Active', 'Probation', 'Graduated', 'Inactive'))
);
GO

CREATE TABLE dbo.Course_Section (
    section_id INT IDENTITY(1,1) NOT NULL,
    course_id INT NOT NULL,
    term_id INT NOT NULL,
    instructor_id INT NOT NULL,
    classroom_id INT NOT NULL,
    capacity INT NOT NULL,
    enrolled_count INT NOT NULL CONSTRAINT DF_CourseSection_EnrolledCount DEFAULT (0),
    max_credit_hours INT NOT NULL,
    [status] VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Course_Section PRIMARY KEY (section_id),
    CONSTRAINT FK_CourseSection_Course FOREIGN KEY (course_id) REFERENCES dbo.Course(course_id),
    CONSTRAINT FK_CourseSection_Term FOREIGN KEY (term_id) REFERENCES dbo.Term(term_id),
    CONSTRAINT FK_CourseSection_Instructor FOREIGN KEY (instructor_id) REFERENCES dbo.Instructor(instructor_id),
    CONSTRAINT FK_CourseSection_Classroom FOREIGN KEY (classroom_id) REFERENCES dbo.Classroom(classroom_id),
    CONSTRAINT CK_CourseSection_Capacity CHECK (capacity BETWEEN 1 AND 300 AND enrolled_count BETWEEN 0 AND capacity),
    CONSTRAINT CK_CourseSection_MaxCreditHours CHECK (max_credit_hours BETWEEN 1 AND 6),
    CONSTRAINT CK_CourseSection_Status CHECK ([status] IN ('Open', 'Closed', 'Cancelled')),
    CONSTRAINT UQ_CourseSection UNIQUE (course_id, term_id, instructor_id, classroom_id)
);
GO

CREATE TABLE dbo.Course_Prerequisite (
    prerequisite_id INT IDENTITY(1,1) NOT NULL,
    course_id INT NOT NULL,
    prerequisite_course_id INT NOT NULL,
    minimum_grade VARCHAR(2) NOT NULL,
    CONSTRAINT PK_Course_Prerequisite PRIMARY KEY (prerequisite_id),
    CONSTRAINT FK_CoursePrereq_Course FOREIGN KEY (course_id) REFERENCES dbo.Course(course_id),
    CONSTRAINT FK_CoursePrereq_PrereqCourse FOREIGN KEY (prerequisite_course_id) REFERENCES dbo.Course(course_id),
    CONSTRAINT CK_CoursePrereq_NoSelf CHECK (course_id <> prerequisite_course_id),
    CONSTRAINT CK_CoursePrereq_MinGrade CHECK (minimum_grade IN ('A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-')),
    CONSTRAINT UQ_CoursePrereq UNIQUE (course_id, prerequisite_course_id)
);
GO

CREATE TABLE dbo.Schedule (
    schedule_id INT IDENTITY(1,1) NOT NULL,
    section_id INT NOT NULL,
    day_of_week VARCHAR(10) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    CONSTRAINT PK_Schedule PRIMARY KEY (schedule_id),
    CONSTRAINT FK_Schedule_Section FOREIGN KEY (section_id) REFERENCES dbo.Course_Section(section_id),
    CONSTRAINT CK_Schedule_Day CHECK (day_of_week IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')),
    CONSTRAINT CK_Schedule_Time CHECK (start_time < end_time),
    CONSTRAINT UQ_Schedule UNIQUE (section_id, day_of_week, start_time)
);
GO

CREATE TABLE dbo.Registration (
    registration_id INT IDENTITY(1,1) NOT NULL,
    student_id INT NOT NULL,
    section_id INT NOT NULL,
    registration_date DATE NOT NULL,
    [status] VARCHAR(20) NOT NULL,
    grade VARCHAR(2) NULL,
    CONSTRAINT PK_Registration PRIMARY KEY (registration_id),
    CONSTRAINT FK_Registration_Student FOREIGN KEY (student_id) REFERENCES dbo.Student(student_id),
    CONSTRAINT FK_Registration_Section FOREIGN KEY (section_id) REFERENCES dbo.Course_Section(section_id),
    CONSTRAINT CK_Registration_Status CHECK ([status] IN ('Enrolled', 'Dropped', 'Swapped', 'Completed', 'Waitlisted')),
    CONSTRAINT CK_Registration_Grade CHECK (grade IS NULL OR grade IN ('A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D', 'F', 'W')),
    CONSTRAINT UQ_Registration UNIQUE (student_id, section_id)
);
GO

CREATE TABLE dbo.Waitlist (
    waitlist_id INT IDENTITY(1,1) NOT NULL,
    student_id INT NOT NULL,
    section_id INT NOT NULL,
    position INT NOT NULL,
    added_date DATE NOT NULL,
    [status] VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Waitlist PRIMARY KEY (waitlist_id),
    CONSTRAINT FK_Waitlist_Student FOREIGN KEY (student_id) REFERENCES dbo.Student(student_id),
    CONSTRAINT FK_Waitlist_Section FOREIGN KEY (section_id) REFERENCES dbo.Course_Section(section_id),
    CONSTRAINT CK_Waitlist_Position CHECK (position >= 1),
    CONSTRAINT CK_Waitlist_Status CHECK ([status] IN ('Active', 'Offered', 'Removed')),
    CONSTRAINT UQ_Waitlist UNIQUE (student_id, section_id),
    CONSTRAINT UQ_Waitlist_Position UNIQUE (section_id, position)
);
GO

CREATE TABLE dbo.Registration_Audit (
    audit_id INT IDENTITY(1,1) NOT NULL,
    registration_id INT NOT NULL,
    student_id INT NOT NULL,
    section_id INT NOT NULL,
    action VARCHAR(30) NOT NULL,
    action_date DATE NOT NULL,
    performed_by VARCHAR(50) NOT NULL,
    CONSTRAINT PK_Registration_Audit PRIMARY KEY (audit_id),
    CONSTRAINT FK_RegistrationAudit_Registration FOREIGN KEY (registration_id) REFERENCES dbo.Registration(registration_id),
    CONSTRAINT FK_RegistrationAudit_Student FOREIGN KEY (student_id) REFERENCES dbo.Student(student_id),
    CONSTRAINT FK_RegistrationAudit_Section FOREIGN KEY (section_id) REFERENCES dbo.Course_Section(section_id),
    CONSTRAINT CK_RegistrationAudit_Action CHECK (action IN ('Registered', 'Dropped', 'Waitlisted', 'Swapped', 'Completed', 'Approved'))
);
GO
