
DROP DATABASE IF EXISTS finance_tracker;
CREATE DATABASE finance_tracker;
USE finance_tracker;

CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE
);

CREATE TABLE Categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL
);

CREATE TABLE Income (
    income_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    amount DECIMAL(10,2) CHECK (amount > 0),
    income_date DATE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

CREATE TABLE Expenses (
    expense_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    category_id INT,
    amount DECIMAL(10,2) CHECK (amount > 0),
    expense_date DATE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
);

INSERT INTO Users (name, email) VALUES
('Rahul', 'rahul@email.com'),
('Anita', 'anita@email.com'),
('Vikram', 'vikram@email.com');

INSERT INTO Categories (category_name) VALUES
('Food'), ('Transport'), ('Shopping'), ('Bills'), ('Entertainment');

INSERT INTO Income VALUES
(NULL,1,50000,'2026-01-01'),
(NULL,1,52000,'2026-02-01'),
(NULL,2,45000,'2026-01-01'),
(NULL,3,60000,'2026-01-01');

INSERT INTO Expenses VALUES
(NULL,1,1,2000,'2026-01-05'),
(NULL,1,2,1500,'2026-01-06'),
(NULL,1,3,4000,'2026-01-10'),
(NULL,1,5,2500,'2026-02-02'),
(NULL,2,1,2500,'2026-01-07'),
(NULL,2,4,3000,'2026-01-12'),
(NULL,3,5,5000,'2026-01-15'),
(NULL,3,3,3500,'2026-02-05');

DELIMITER $$

CREATE TRIGGER limit_expense
BEFORE INSERT ON Expenses
FOR EACH ROW
BEGIN
    IF NEW.amount > 20000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Expense exceeds allowed limit!';
    END IF;
END $$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE GetUserSummary(IN uid INT)
BEGIN
    SELECT 
    u.name,
    SUM(i.amount) AS income,
    SUM(e.amount) AS expense,
    SUM(i.amount) - SUM(e.amount) AS balance
    FROM Users u
    LEFT JOIN Income i ON u.user_id = i.user_id
    LEFT JOIN Expenses e ON u.user_id = e.user_id
    WHERE u.user_id = uid
    GROUP BY u.name;
END $$

DELIMITER ;

CALL GetUserSummary(1);

SELECT 
u.name AS "User",

-- Income
LPAD(CONCAT('₹ ', FORMAT(COALESCE(i.total_income,0),0)), 12, ' ') AS "Income",

-- Expense
LPAD(CONCAT('₹ ', FORMAT(COALESCE(e.total_expense,0),0)), 12, ' ') AS "Expense",

-- Savings
LPAD(CONCAT('₹ ', FORMAT(
COALESCE(i.total_income,0) - COALESCE(e.total_expense,0),0)), 12, ' ') AS "Savings",

-- Savings %
LPAD(CONCAT(
ROUND(
(COALESCE(i.total_income,0) - COALESCE(e.total_expense,0)) 
/ COALESCE(i.total_income,1) * 100,2),
'%'), 10, ' ') AS "Savings %",

-- Budget Status
CASE 
    WHEN COALESCE(e.total_expense,0) > 0.8 * COALESCE(i.total_income,0) THEN 'OVER BUDGET'
    WHEN COALESCE(e.total_expense,0) > 0.5 * COALESCE(i.total_income,0) THEN 'MODERATE'
    ELSE 'SAFE'
END AS "Status"

FROM Users u

LEFT JOIN (
    SELECT user_id, SUM(amount) AS total_income
    FROM Income
    GROUP BY user_id
) i ON u.user_id = i.user_id

LEFT JOIN (
    SELECT user_id, SUM(amount) AS total_expense
    FROM Expenses
    GROUP BY user_id
) e ON u.user_id = e.user_id;

-- 🔹 SMART BUDGET STATUS
SELECT 
u.name AS "User",
CASE 
    WHEN SUM(e.amount) > 0.8 * SUM(i.amount) THEN '⚠ Over Budget'
    WHEN SUM(e.amount) > 0.5 * SUM(i.amount) THEN '⚡ Moderate'
    ELSE '✅ Safe'
END AS "Budget Status"
FROM Users u
JOIN Income i ON u.user_id = i.user_id
JOIN Expenses e ON u.user_id = e.user_id
GROUP BY u.name;

-- 🔹 CATEGORY DISTRIBUTION
SELECT 
c.category_name AS "Category",
CONCAT('₹ ', FORMAT(SUM(e.amount),0)) AS "Total",
CONCAT(
ROUND(SUM(e.amount) * 100 / (SELECT SUM(amount) FROM Expenses),2),
'%'
) AS "Share %"
FROM Expenses e
JOIN Categories c ON e.category_id = c.category_id
GROUP BY c.category_name
ORDER BY SUM(e.amount) DESC;

-- 🔹 MONTHLY TREND
SELECT 
month,
total_spent,
LAG(total_spent) OVER (ORDER BY month) AS previous_month,
total_spent - LAG(total_spent) OVER (ORDER BY month) AS growth
FROM (
    SELECT 
    DATE_FORMAT(expense_date, '%Y-%m') AS month,
    SUM(amount) AS total_spent
    FROM Expenses
    GROUP BY DATE_FORMAT(expense_date, '%Y-%m')
) AS monthly_data;

-- 🔹 TOP SPENDER
SELECT 
u.name AS "Top Spender",
CONCAT('₹ ', FORMAT(SUM(e.amount),0)) AS "Total Spent"
FROM Users u
JOIN Expenses e ON u.user_id = e.user_id
GROUP BY u.name
ORDER BY SUM(e.amount) DESC
LIMIT 1;

-- 🔹 RUNNING TOTAL (ADVANCED)
SELECT 
user_id,
expense_date,
amount,
SUM(amount) OVER (PARTITION BY user_id ORDER BY expense_date) AS running_total
FROM Expenses;

-- =========================================
-- 7. FINAL REPORT VIEW
-- =========================================
CREATE OR REPLACE VIEW Dashboard_Report AS
SELECT 
u.name,
SUM(i.amount) AS income,
SUM(e.amount) AS expense,
SUM(i.amount) - SUM(e.amount) AS balance
FROM Users u
LEFT JOIN Income i ON u.user_id = i.user_id
LEFT JOIN Expenses e ON u.user_id = e.user_id
GROUP BY u.name;


SELECT * FROM Dashboard_Report;

-- =========================================
-- END OF PROJECT
-- =========================================