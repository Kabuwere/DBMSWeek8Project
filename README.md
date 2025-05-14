# DBMSWeek8Project
📌 Project Title
She Investment Chama Group Database Management System

📖 Description
This DBMS is designed to manage the financial records of She Investment Chama Group, a Friends’s investment group operating like a Sacco. The system tracks members, contributions, loans, meetings, auditlogs and repayments while ensuring data integrity.

🚀 How to Run/Setup the Project
Install MySQL on your system.

Download the SQL file (she_investment_chama.sql).

Import the SQL file into MySQL:

Open MySQL Workbench or use the command line.

Run:

bash
mysql -u your_username -p your_database < she_investment_chama.sql
Alternatively, use MySQL Workbench to import the file.

You can run these example queries to see how the system works:
-- View all transactions
SELECT * FROM Transactions ORDER BY transaction_date DESC;

-- View financial summary
SELECT * FROM FinancialSummary;

-- Filter transactions by type
SELECT * FROM Transactions WHERE transaction_type = 'Loan Repayment';

🏗️ Database Structure
Members: Stores member details (name, phone, email, shares owned).

Contributions: Logs monthly contributions.

Loans: Manages loan issuance and repayments.

Transactions: Records financial activities.

Auditlog: Detals system activities

Meetings: Shows meeting details

🔗 ERD Diagram


📂 Repository Structure
📂 She-Investment-Chama
 ├── 📜 README.md
 ├── 📜 she_investment_chama.sql  # Well-commented SQL file
 ├── 📷 ERD.png  # ERD diagram screenshot
