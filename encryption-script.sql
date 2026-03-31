USE CourseRegistrationDB;
GO

-- ============================================================
-- COLUMN-LEVEL ENCRYPTION FOR SENSITIVE STUDENT DATA
-- Encrypts: Student phone numbers and email addresses
-- ============================================================

-- Step 1: Create a Database Master Key
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'CourseReg$trongP@ss2026!';
END
GO

-- Step 2: Create a Certificate
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'StudentDataCertificate')
BEGIN
    CREATE CERTIFICATE StudentDataCertificate
    WITH SUBJECT = 'Certificate for Student PII Encryption';
END
GO

-- Step 3: Create a Symmetric Key
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'StudentDataSymKey')
BEGIN
    CREATE SYMMETRIC KEY StudentDataSymKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE StudentDataCertificate;
END
GO

-- Step 4: Add encrypted columns to Student table
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Student') AND name = 'encrypted_phone')
BEGIN
    ALTER TABLE dbo.Student ADD encrypted_phone VARBINARY(256) NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Student') AND name = 'encrypted_email')
BEGIN
    ALTER TABLE dbo.Student ADD encrypted_email VARBINARY(512) NULL;
END
GO

-- Step 5: Encrypt existing data
OPEN SYMMETRIC KEY StudentDataSymKey
DECRYPTION BY CERTIFICATE StudentDataCertificate;

UPDATE dbo.Student
SET encrypted_phone = ENCRYPTBYKEY(KEY_GUID('StudentDataSymKey'), phone),
    encrypted_email = ENCRYPTBYKEY(KEY_GUID('StudentDataSymKey'), email);

CLOSE SYMMETRIC KEY StudentDataSymKey;
GO

-- ============================================================
-- Helper View: Decrypt student data for authorized access
-- ============================================================
IF OBJECT_ID('dbo.vw_StudentDecrypted', 'V') IS NOT NULL DROP VIEW dbo.vw_StudentDecrypted;
GO

CREATE VIEW dbo.vw_StudentDecrypted
AS
SELECT
    student_id,
    first_name,
    last_name,
    CONVERT(VARCHAR(100), DECRYPTBYKEY(encrypted_email)) AS decrypted_email,
    CONVERT(VARCHAR(20), DECRYPTBYKEY(encrypted_phone))  AS decrypted_phone,
    credit_hours_completed,
    max_credit_hours,
    [status]
FROM dbo.Student;
GO

-- ============================================================
-- Usage Example (run manually to test):
-- ============================================================
-- To read encrypted data, open the key first:
--
--   OPEN SYMMETRIC KEY StudentDataSymKey
--   DECRYPTION BY CERTIFICATE StudentDataCertificate;
--
--   SELECT * FROM dbo.vw_StudentDecrypted;
--
--   CLOSE SYMMETRIC KEY StudentDataSymKey;
--
-- Without opening the key, decrypted_email and decrypted_phone return NULL.
-- ============================================================

PRINT 'Encryption script executed successfully.';
GO
