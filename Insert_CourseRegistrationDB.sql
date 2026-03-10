USE CourseRegistrationDB;
GO

INSERT INTO dbo.Term (name, season, [year], registration_start, registration_end, add_drop_deadline, start_date, end_date)
VALUES
('Spring 2026', 'Spring', 2026, '2025-11-01', '2026-01-10', '2026-01-25', '2026-01-12', '2026-05-05'),
('Summer 1 2026', 'Summer', 2026, '2026-03-01', '2026-05-01', '2026-05-10', '2026-05-11', '2026-06-25'),
('Summer 2 2026', 'Summer', 2026, '2026-04-01', '2026-06-20', '2026-07-01', '2026-06-29', '2026-08-15'),
('Fall 2026', 'Fall', 2026, '2026-03-15', '2026-08-20', '2026-09-10', '2026-09-02', '2026-12-18'),
('Winter 2026', 'Winter', 2026, '2026-09-01', '2026-12-10', '2026-12-20', '2026-12-15', '2027-01-10'),
('Spring 2027', 'Spring', 2027, '2026-11-01', '2027-01-08', '2027-01-22', '2027-01-11', '2027-05-03'),
('Summer 1 2027', 'Summer', 2027, '2027-03-01', '2027-05-02', '2027-05-09', '2027-05-10', '2027-06-24'),
('Summer 2 2027', 'Summer', 2027, '2027-04-01', '2027-06-21', '2027-07-02', '2027-06-28', '2027-08-14'),
('Fall 2027', 'Fall', 2027, '2027-03-15', '2027-08-21', '2027-09-09', '2027-09-01', '2027-12-17'),
('Spring 2028', 'Spring', 2028, '2027-11-01', '2028-01-09', '2028-01-23', '2028-01-10', '2028-05-01');
GO

INSERT INTO dbo.Admin_User (username, email, [role], permissions)
VALUES
('aregistrar', 'aregistrar@neu.edu', 'Registrar', 'Manage registration periods, approve overrides'),
('bscheduler', 'bscheduler@neu.edu', 'Scheduler', 'Manage classrooms and schedules'),
('cdeptadmin', 'cdeptadmin@neu.edu', 'DepartmentAdmin', 'Manage department sections'),
('dsuper', 'dsuper@neu.edu', 'SuperAdmin', 'Full system access'),
('eregistrar', 'eregistrar@neu.edu', 'Registrar', 'Audit enrollment records'),
('fscheduler', 'fscheduler@neu.edu', 'Scheduler', 'Edit meeting times and rooms'),
('gdeptadmin', 'gdeptadmin@neu.edu', 'DepartmentAdmin', 'Review faculty assignments'),
('hsuper', 'hsuper@neu.edu', 'SuperAdmin', 'Security and user administration'),
('iregistrar', 'iregistrar@neu.edu', 'Registrar', 'Manage add drop requests'),
('jscheduler', 'jscheduler@neu.edu', 'Scheduler', 'Publish course schedule');
GO

INSERT INTO dbo.Classroom (building, room_number, capacity)
VALUES
('Snell', '101', 40),
('Snell', '202', 35),
('West Village H', '120', 50),
('West Village H', '210', 45),
('Shillman', '305', 60),
('Shillman', '110', 55),
('ISEC', '420', 70),
('ISEC', '515', 80),
('Hayden', '150', 30),
('Richards', '220', 65);
GO

INSERT INTO dbo.Instructor (first_name, last_name, email, department)
VALUES
('Maya', 'Chen', 'maya.chen@neu.edu', 'Information Systems'),
('Daniel', 'Brooks', 'daniel.brooks@neu.edu', 'Computer Science'),
('Olivia', 'Patel', 'olivia.patel@neu.edu', 'Information Systems'),
('Noah', 'Kim', 'noah.kim@neu.edu', 'Data Science'),
('Sophia', 'Reed', 'sophia.reed@neu.edu', 'Computer Science'),
('Liam', 'Murphy', 'liam.murphy@neu.edu', 'Mathematics'),
('Emma', 'Turner', 'emma.turner@neu.edu', 'Software Engineering'),
('James', 'Foster', 'james.foster@neu.edu', 'Information Systems'),
('Ava', 'Diaz', 'ava.diaz@neu.edu', 'Analytics'),
('Ethan', 'Hall', 'ethan.hall@neu.edu', 'Computer Science');
GO

INSERT INTO dbo.Course (course_code, title, description, credit_hours, department)
VALUES
('INFO5100', 'Application Engineering and Development', 'Java programming and object-oriented design.', 4, 'Information Systems'),
('INFO6150', 'Web Design and User Experience Engineering', 'Front-end web design and usability concepts.', 4, 'Information Systems'),
('DAMG6210', 'Data Management and Database Design', 'Relational modeling, SQL, and normalization.', 4, 'Information Systems'),
('CSYE6200', 'Object-Oriented Design', 'Advanced object-oriented design patterns and principles.', 4, 'Software Engineering'),
('CSYE7280', 'User Experience Design and Testing', 'UX design, research, and prototyping.', 4, 'Software Engineering'),
('INFO6105', 'Data Science Engineering Methods', 'Data engineering and analytics workflows.', 4, 'Information Systems'),
('CS5800', 'Algorithms', 'Algorithm analysis and design.', 4, 'Computer Science'),
('CS5001', 'Intensive Foundations of Computer Science', 'Programming foundations for graduate students.', 4, 'Computer Science'),
('MATH5130', 'Statistics for Data Science', 'Probability and statistics for data analysis.', 4, 'Mathematics'),
('INFO7000', 'Information Systems Capstone', 'Capstone project course.', 3, 'Information Systems');
GO

INSERT INTO dbo.Student (first_name, last_name, email, phone, credit_hours_completed, max_credit_hours, [status])
VALUES
('Yuhao', 'Liu', 'yuhao.liu@northeastern.edu', '617-555-0101', 12, 18, 'Active'),
('Amy', 'Zhang', 'amy.zhang@northeastern.edu', '617-555-0102', 8, 18, 'Active'),
('Jimmy', 'Wang', 'jimmy.wang@northeastern.edu', '617-555-0103', 16, 18, 'Active'),
('Sarah', 'Johnson', 'sarah.johnson@northeastern.edu', '617-555-0104', 20, 21, 'Active'),
('Kevin', 'Lee', 'kevin.lee@northeastern.edu', '617-555-0105', 4, 18, 'Probation'),
('Emily', 'Davis', 'emily.davis@northeastern.edu', '617-555-0106', 28, 18, 'Active'),
('Michael', 'Brown', 'michael.brown@northeastern.edu', '617-555-0107', 32, 18, 'Graduated'),
('Linda', 'Garcia', 'linda.garcia@northeastern.edu', '617-555-0108', 10, 18, 'Active'),
('Jason', 'Miller', 'jason.miller@northeastern.edu', '617-555-0109', 6, 18, 'Active'),
('Nina', 'Wilson', 'nina.wilson@northeastern.edu', '617-555-0110', 14, 18, 'Active');
GO

INSERT INTO dbo.Course_Section (course_id, term_id, instructor_id, classroom_id, capacity, enrolled_count, max_credit_hours, [status])
VALUES
(1, 1, 1, 1, 40, 28, 4, 'Open'),
(2, 1, 3, 2, 35, 35, 4, 'Closed'),
(3, 1, 8, 3, 50, 41, 4, 'Open'),
(4, 1, 7, 4, 45, 30, 4, 'Open'),
(5, 1, 5, 5, 60, 55, 4, 'Open'),
(6, 1, 4, 6, 55, 48, 4, 'Open'),
(7, 1, 2, 7, 70, 70, 4, 'Closed'),
(8, 1, 10, 8, 80, 64, 4, 'Open'),
(9, 1, 6, 9, 30, 24, 4, 'Open'),
(10, 1, 1, 10, 65, 40, 3, 'Open');
GO

INSERT INTO dbo.Course_Prerequisite (course_id, prerequisite_course_id, minimum_grade)
VALUES
(1, 8, 'C'),
(2, 8, 'C'),
(3, 8, 'C'),
(4, 8, 'B-'),
(5, 2, 'C'),
(6, 9, 'C'),
(7, 8, 'B'),
(10, 1, 'C'),
(10, 2, 'C'),
(10, 3, 'C');
GO

INSERT INTO dbo.Schedule (section_id, day_of_week, start_time, end_time)
VALUES
(1, 'Monday', '09:00', '10:40'),
(2, 'Tuesday', '11:00', '12:40'),
(3, 'Wednesday', '13:00', '14:40'),
(4, 'Thursday', '09:00', '10:40'),
(5, 'Friday', '10:00', '11:40'),
(6, 'Monday', '14:00', '15:40'),
(7, 'Tuesday', '15:00', '16:40'),
(8, 'Wednesday', '09:00', '10:40'),
(9, 'Thursday', '13:00', '14:40'),
(10, 'Friday', '15:00', '16:40');
GO

INSERT INTO dbo.Registration (student_id, section_id, registration_date, [status], grade)
VALUES
(1, 1, '2026-01-03', 'Enrolled', NULL),
(2, 2, '2026-01-04', 'Waitlisted', NULL),
(3, 3, '2026-01-05', 'Enrolled', NULL),
(4, 4, '2026-01-05', 'Completed', 'A-'),
(5, 5, '2026-01-06', 'Dropped', 'W'),
(6, 6, '2026-01-06', 'Enrolled', NULL),
(7, 7, '2026-01-07', 'Completed', 'B+'),
(8, 8, '2026-01-07', 'Swapped', NULL),
(9, 9, '2026-01-08', 'Enrolled', NULL),
(10, 10, '2026-01-08', 'Enrolled', NULL);
GO

INSERT INTO dbo.Waitlist (student_id, section_id, position, added_date, [status])
VALUES
(2, 2, 1, '2026-01-04', 'Active'),
(1, 7, 1, '2026-01-04', 'Active'),
(3, 7, 2, '2026-01-05', 'Active'),
(4, 2, 2, '2026-01-05', 'Offered'),
(5, 7, 3, '2026-01-06', 'Active'),
(6, 2, 3, '2026-01-06', 'Removed'),
(7, 2, 4, '2026-01-06', 'Active'),
(8, 7, 4, '2026-01-07', 'Active'),
(9, 2, 5, '2026-01-07', 'Active'),
(10, 7, 5, '2026-01-08', 'Active');
GO

INSERT INTO dbo.Registration_Audit (registration_id, student_id, section_id, action, action_date, performed_by)
VALUES
(1, 1, 1, 'Registered', '2026-01-03', 'aregistrar'),
(2, 2, 2, 'Waitlisted', '2026-01-04', 'aregistrar'),
(3, 3, 3, 'Registered', '2026-01-05', 'eregistrar'),
(4, 4, 4, 'Completed', '2026-05-06', 'cdeptadmin'),
(5, 5, 5, 'Dropped', '2026-01-20', 'iregistrar'),
(6, 6, 6, 'Registered', '2026-01-06', 'aregistrar'),
(7, 7, 7, 'Completed', '2026-05-06', 'cdeptadmin'),
(8, 8, 8, 'Swapped', '2026-01-18', 'eregistrar'),
(9, 9, 9, 'Registered', '2026-01-08', 'aregistrar'),
(10, 10, 10, 'Approved', '2026-01-09', 'dsuper');
GO
