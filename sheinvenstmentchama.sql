/* =============================================
   DATABASE SETUP
============================================= */
CREATE DATABASE IF NOT EXISTS SheInvestmentChama;
USE SheInvestmentChama;

/* =============================================
   SECTION: CONFIGURATION
============================================= */
CREATE TABLE Config (
    config_key VARCHAR(50) PRIMARY KEY,
    config_value DECIMAL(15,2),
    description VARCHAR(255)
);

INSERT INTO Config VALUES 
    ('share_value', 2000, 'Monthly contribution per share'),
    ('penalty_rate', 5.0, 'Daily late payment penalty rate'),
    ('base_interest_rate', 10.0, 'Default loan interest rate');


/* =============================================
   SECTION: CORE MEMBER DATA
============================================= */
CREATE TABLE Members (
    member_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(15) UNIQUE NOT NULL COMMENT 'Format: +254XXXXXXXXX',
    email VARCHAR(255) UNIQUE NOT NULL,
    shares_owned INT NOT NULL CHECK (shares_owned >= 1),
    total_contributed DECIMAL(10,2) DEFAULT 0,
    role ENUM('Chair', 'Treasurer', 'Secretary', 'Member') DEFAULT 'Member',
    join_date DATE DEFAULT (CURRENT_DATE)
) COMMENT='Core member information and roles';


/* =============================================
   SECTION: FINANCIAL TRANSACTIONS
============================================= */
-- Contributions Table
CREATE TABLE Contributions (
    contribution_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    contribution_date DATE NOT NULL,
    mpesa_code VARCHAR(20) UNIQUE,
    FOREIGN KEY (member_id) REFERENCES Members(member_id) ON DELETE CASCADE
) COMMENT='Monthly member contributions';

-- Transactions Table (Central Ledger)
CREATE TABLE Transactions (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    transaction_type ENUM('Contribution', 'Loan Repayment', 'Penalty', 'Dividend') NOT NULL,
    reference_id INT COMMENT 'Source table ID (contributions_id/repayment_id/penalty_id)',
    member_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    transaction_date DATE NOT NULL,
    mpesa_code VARCHAR(20) UNIQUE,
    FOREIGN KEY (member_id) REFERENCES Members(member_id)
) COMMENT='Central transaction ledger for all financial activities';

/* =============================================
   SECTION: LOAN MANAGEMENT
============================================= */
CREATE TABLE Loans (
    loan_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT NOT NULL,
    principal DECIMAL(10,2) NOT NULL,
    interest_rate DECIMAL(5,2) NOT NULL COMMENT 'Annual percentage rate',
    disbursement_date DATE NOT NULL,
    due_date DATE NOT NULL,
    status ENUM('Active', 'Paid', 'Defaulted') DEFAULT 'Active',
    FOREIGN KEY (member_id) REFERENCES Members(member_id) ON DELETE CASCADE,
    
    -- Combined table-level constraints
    CONSTRAINT chk_principal_positive CHECK (principal > 0),
    CONSTRAINT chk_valid_dates CHECK (
        disbursement_date <= due_date AND 
        due_date > disbursement_date
    )
) COMMENT='Loan issuance and status tracking';

CREATE TABLE LoanRepayments (
    repayment_id INT PRIMARY KEY AUTO_INCREMENT,
    loan_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_date DATE NOT NULL,
    mpesa_code VARCHAR(20) UNIQUE,
    FOREIGN KEY (loan_id) REFERENCES Loans(loan_id) ON DELETE CASCADE
) COMMENT='Loan repayment records';

CREATE TABLE Penalties (
    penalty_id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT NOT NULL,
    loan_id INT,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    penalty_date DATE NOT NULL,
    reason VARCHAR(255),
    FOREIGN KEY (member_id) REFERENCES Members(member_id),
    FOREIGN KEY (loan_id) REFERENCES Loans(loan_id)
) COMMENT='Penalty records for late/missed payments';


/* =============================================
   SECTION: OPERATIONAL DATA
============================================= */
CREATE TABLE Meetings (
    meeting_id INT PRIMARY KEY AUTO_INCREMENT,
    meeting_date DATE NOT NULL,
    agenda TEXT NOT NULL,
    minutes TEXT,
    attendees JSON
) COMMENT='Meeting records with attendance tracking';

CREATE TABLE AuditLogs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    action_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id INT NOT NULL,
    user VARCHAR(100) NOT NULL,
    action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT
) COMMENT='Audit trail for database activities';


/* =============================================
   SECTION: INITIAL DATA POPULATION
============================================= */
-- Insert Core Members
INSERT INTO Members (name, phone, email, shares_owned, role) VALUES
('Florence Otieno', '+254712345678', 'florence@chama.co.ke', 2, 'Chair'),
('Carol Kamau', '+254723456789', 'carol@chama.co.ke', 2, 'Treasurer'),
('Susan Wafula', '+254734567890', 'susan@chama.co.ke', 2, 'Secretary'),
('Mercy Mwangi', '+254745678901', 'mercy@chama.co.ke', 2, 'Member'),
('Latipha Oduor', '+254756789012', 'latipha@chama.co.ke', 2, 'Member'),
('Mukami Esther', '+254767890123', 'mukami@chama.co.ke', 2, 'Member'),
('Milka Karanja', '+254778901234', 'milka@chama.co.ke', 1, 'Member'),
('Amina Christine', '+254789012345', 'amina@chama.co.ke', 1, 'Member');


/* =============================================
   SECTION: STORED PROCEDURES
============================================= */
-- =============================================
-- Name: InsertMonthlyContributions
-- Purpose: Generate monthly member contributions
-- =============================================
DELIMITER $$
CREATE PROCEDURE InsertMonthlyContributions()
BEGIN
    DECLARE share_value DECIMAL(10,2);
    DECLARE start_date DATE DEFAULT '2024-12-01';
    DECLARE end_date DATE DEFAULT '2025-05-01';
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    SELECT config_value INTO share_value FROM Config WHERE config_key = 'share_value';
    
    WHILE start_date <= end_date DO
        INSERT INTO Contributions (member_id, amount, contribution_date)
        SELECT member_id, shares_owned * share_value, start_date
        FROM Members;
        
        SET start_date = DATE_ADD(start_date, INTERVAL 1 MONTH);
    END WHILE;
    
    COMMIT;
END$$
DELIMITER ;

-- =============================================
-- Name: CalculateDividends
-- Purpose: Distribute profits as dividends
-- =============================================
DELIMITER $$
CREATE PROCEDURE CalculateDividends(IN dividend_rate DECIMAL(5,2))
BEGIN
    DECLARE total_profit DECIMAL(15,2);
    DECLARE share_value DECIMAL(10,2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    SELECT config_value INTO share_value FROM Config WHERE config_key = 'share_value';
    SELECT SUM(principal * interest_rate/100) INTO total_profit FROM Loans;
    
    INSERT INTO Contributions (member_id, amount, contribution_date)
    SELECT member_id, (shares_owned * share_value) * (dividend_rate/100), CURDATE()
    FROM Members;
    
    COMMIT;
END$$
DELIMITER ;


/* =============================================
   SECTION: TRIGGERS
============================================= */
-- =============================================
-- Name: LogContributionTransaction
-- Purpose: Auto-log contributions to Transactions
-- =============================================
DELIMITER $$
CREATE TRIGGER LogContributionTransaction
AFTER INSERT ON Contributions
FOR EACH ROW
BEGIN
    INSERT INTO Transactions 
    (transaction_type, reference_id, member_id, amount, transaction_date, mpesa_code)
    VALUES ('Contribution', NEW.contribution_id, NEW.member_id, 
            NEW.amount, NEW.contribution_date, NEW.mpesa_code);
END$$

-- =============================================
-- Name: LogRepaymentTransaction
-- Purpose: Auto-log loan repayments to Transactions
-- =============================================
CREATE TRIGGER LogRepaymentTransaction
AFTER INSERT ON LoanRepayments
FOR EACH ROW
BEGIN
    INSERT INTO Transactions 
    (transaction_type, reference_id, member_id, amount, transaction_date, mpesa_code)
    SELECT 'Loan Repayment', NEW.repayment_id, l.member_id, 
           NEW.amount, NEW.payment_date, NEW.mpesa_code
    FROM Loans l WHERE l.loan_id = NEW.loan_id;
END$$

-- =============================================
-- Name: LogPenaltyTransaction
-- Purpose: Auto-log penalties to Transactions
-- =============================================
CREATE TRIGGER LogPenaltyTransaction
AFTER INSERT ON Penalties
FOR EACH ROW
BEGIN
    INSERT INTO Transactions 
    (transaction_type, reference_id, member_id, amount, transaction_date)
    VALUES ('Penalty', NEW.penalty_id, NEW.member_id, 
            NEW.amount, NEW.penalty_date);
END$$
DELIMITER ;


/* =============================================
   SECTION: REPORTING VIEWS
============================================= */
-- =============================================
-- Name: MemberPortfolio
-- Purpose: Consolidated member financial overview
-- =============================================
CREATE VIEW MemberPortfolio AS
SELECT 
    m.member_id,
    m.name,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'Contribution' THEN t.amount END), 0) AS total_contributions,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'Loan Repayment' THEN t.amount END), 0) AS total_repayments,
    COALESCE(SUM(l.principal), 0) AS total_loans_taken,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'Penalty' THEN t.amount END), 0) AS total_penalties
FROM Members m
LEFT JOIN Transactions t ON m.member_id = t.member_id
LEFT JOIN Loans l ON m.member_id = l.member_id
GROUP BY m.member_id;

-- =============================================
-- Name: ActiveLoans
-- Purpose: Monitor outstanding loans
-- =============================================
CREATE VIEW ActiveLoans AS
SELECT 
    l.loan_id,
    m.name,
    l.principal,
    l.interest_rate,
    l.due_date,
    DATEDIFF(CURDATE(), l.due_date) AS days_overdue,
    COALESCE(SUM(lr.amount), 0) AS amount_repaid,
    (l.principal * (1 + l.interest_rate/100)) - COALESCE(SUM(lr.amount), 0) AS outstanding_balance
FROM Loans l
JOIN Members m ON l.member_id = m.member_id
LEFT JOIN LoanRepayments lr ON l.loan_id = lr.loan_id
WHERE l.status = 'Active'
GROUP BY l.loan_id;


/* =============================================
   SECTION: SYSTEM INITIALIZATION
============================================= */
CALL InsertMonthlyContributions();

-- Sample Loan Data
INSERT INTO Loans (member_id, principal, interest_rate, disbursement_date, due_date) VALUES
(1, 10000, 12.5, '2024-12-01', '2025-06-01'),
(2, 15000, 12.5, '2024-12-15', '2025-06-15'),
(6, 40000, 15.0, '2025-02-15', '2025-08-15');

-- Sample Loan Repayments
INSERT INTO LoanRepayments (loan_id, amount, payment_date) VALUES
(1, 5000, '2025-01-05'), (1, 6000, '2025-02-05'),
(2, 8000, '2025-01-20'), (2, 9000, '2025-02-20');

-- Sample Penalties
INSERT INTO Penalties (member_id, loan_id, amount, penalty_date, reason) VALUES
(6, 3, 1500, '2025-03-01', 'Late payment penalty'),
(2, 2, 500, '2025-02-21', 'Partial payment penalty');

-- Sample Meetings
INSERT INTO Meetings (meeting_date, agenda, minutes, attendees) VALUES
('2024-12-05', 'Year-End Strategy', 'Approved loan policy updates', '[1,2,3,4,5,6,7,8]'),
('2025-01-10', 'Financial Review', 'Reviewed December transactions', '[1,2,3,4,5,6]');