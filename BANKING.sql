

SELECT TOP 1 *
FROM accounts

SELECT TOP 1 *
FROM branches

SELECT TOP 1 *
FROM card_transactions

SELECT TOP 1 *
FROM cards

SELECT TOP 1 *
FROM customers

SELECT TOP 1 *
FROM employees

SELECT TOP 1 *
FROM loan_payments

SELECT TOP 1 *
FROM loans

SELECT TOP 1 *
FROM support_tickets

SELECT TOP 1 *
FROM transactions

SELECT COUNT(*)
FROM branches

/* 1. For each branch, find total account balance and rank branches within their state using RANK(). Return only the #1 branch per state.*/

CREATE VIEW TOTAL_BALANCE AS

SELECT *
FROM(
	SELECT State ,Branch_id, TOTAL_BALANCE, DENSE_RANK() OVER( PARTITION BY State ORDER BY TOTAL_BALANCE DESC ) AS R
	FROM (
		SELECT br.state AS State, br.branch_id AS Branch_id, SUM(ac.balance) AS TOTAL_BALANCE
		FROM branches AS br
		JOIN accounts AS ac
		ON br.branch_id = ac.branch_id
		GROUP BY br.state, br.branch_id
	)AS t1
) t2
WHERE R = 1



/* 2. Find the top 5 branches by loan default rate (Defaulted + Written Off as % of all loans), but only include branches with at least 100 loans issued. */

CREATE VIEW Defaulted_rate AS

SELECT TOP 5 lo.branch_id, COUNT(lo.status) AS No_of_loan_issued, 
	ROUND( CAST (SUM(CASE WHEN lo.status = 'Defaulted' THEN 1 ELSE 0 END) + SUM(CASE WHEN lo.status = 'Written Off' THEN 1 ELSE 0 END) AS FLOAT)/
	SUM(CASE WHEN lo.status IS NOT NULL THEN 1 ELSE 0 END) * 100, 2 ) AS Defaulted_rate
FROM loans AS lo
GROUP BY lo.branch_id
HAVING COUNT(loan_id) > 100
ORDER BY Defaulted_rate DESC 



/*	3. For each role, compute the average salary and the average salary as a percentage of that branch's total salary spend — i.e., 
	what share of payroll each role represents, per branch.	*/ 

CREATE VIEW average_salary_as_a_percentage AS


SELECT * ,	(t1.Role_salary_spend * 100)/t2.total_salary_spend AS per_share_of_payroll 
FROM(
	SELECT br.branch_id AS Branch_id, 
	emp.role AS Role, 
	AVG(emp.salary) AS Avg_salary,
	SUM(emp.salary) AS Role_salary_spend
	FROM branches AS br
	JOIN employees AS emp
		ON br.branch_id = emp.branch_id
	GROUP BY br.branch_id, 
			emp.role
	) AS t1
JOIN(
	SELECT br.branch_id AS Branch_id, 
	SUM (emp.salary) AS total_salary_spend 
	FROM branches AS br
	JOIN employees AS emp
	ON br.branch_id = emp.branch_id
	GROUP BY br.branch_id 
	) AS t2
ON t1.Branch_id = t2.Branch_id


/*	4. List branches where avg_satisfaction (from support_tickets, joined via each customer's most-used branch) is below 
		the company-wide average — using a subquery or CTE for the global average, not a hardcoded number.	*/

CREATE VIEW avg_support AS

WITH customer_branch AS (
    SELECT customer_id, branch_id,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY COUNT(*) DESC, MIN(open_date) ASC
           ) AS rn
    FROM accounts
    GROUP BY customer_id, branch_id
),
primary_branch AS (
    SELECT customer_id, branch_id FROM customer_branch WHERE rn = 1
)
SELECT pb.branch_id, AVG(st.satisfaction_score) AS avg_satisfaction
FROM support_tickets st
JOIN primary_branch pb ON st.customer_id = pb.customer_id
GROUP BY pb.branch_id
HAVING AVG(st.satisfaction_score) < (SELECT AVG(satisfaction_score) FROM support_tickets);



/*   5. For each branch, compute accounts-per-employee and flag branches as 'Understaffed', 'Overstaffed', or 'Normal' 
		based on whether they're more than 1 standard deviation from the mean (use a CTE + window functions for the stats). */


CREATE VIEW Status_employee AS

WITH Employee_per_branch AS (
SELECT br.branch_id AS branch, COUNT(emp.employee_id) AS Employee
FROM branches AS br
JOIN employees AS emp
ON br.branch_id = emp.branch_id
GROUP BY br.branch_id),

Account_per_branch AS (
SELECT br.branch_id AS Branch, COUNT(ac.account_id) AS account
FROM branches AS br
JOIN accounts AS ac
ON br.branch_id = ac.branch_id 
GROUP BY br.branch_id),

PER_DATA AS (
SELECT em.branch AS Branch, em.Employee, ac.account, CAST(ac.account AS FLOAT)/em.Employee AS account_per_employee
FROM Employee_per_branch AS em
JOIN Account_per_branch AS ac
ON em.branch = ac.Branch)

 SELECT Branch AS Branch_id,
		account_per_employee AS  account_per_employee , 
		AVG(account_per_employee) OVER() AS Mean, 
		STDEV(account_per_employee) OVER() AS Standard_Deviation,
		CASE WHEN account_per_employee > AVG(account_per_employee) OVER() + 1* STDEV(account_per_employee) OVER() THEN 'Understaffed' 
		WHEN account_per_employee < AVG(account_per_employee) OVER() - 1* STDEV(account_per_employee) OVER() THEN 'Overstaffed' 
		ELSE 'Normal' END AS Status
 FROM PER_DATA




/*   6.	Using a window function, compute a running total of loan amount issued per branch ordered by start_date, 
		and identify the date each branch crossed ₹50M in cumulative originations.  */

CREATE VIEW Date_of_payment AS

WITH Loan_amount AS (
SELECT br.branch_id AS Branch_id, lo.loan_amount AS Loan_amount, lo.start_date AS Date_of_payment,  SUM(lo.loan_amount) OVER( PARTITION BY br.branch_id ORDER BY lo.start_date) Sum_of_loan_amount, lo.start_date
FROM branches AS br
INNER JOIN loans AS lo
ON br.branch_id = lo.branch_id
),
Cross_50mill AS 
(SELECT Branch_id AS Branch_id, Sum_of_loan_amount AS Sum_loan_amount, Date_of_payment AS Date_of_payment, ROW_NUMBER() OVER (PARTITION BY Branch_id ORDER BY Sum_of_loan_amount ASC ) AS R
FROM Loan_amount
WHERE Sum_of_loan_amount > 50000000),

First_50mill AS
(SELECT Branch_id AS Branch_id , Sum_loan_amount AS Sum_loan_amount, Date_of_payment AS Date_of_payment,
		ROW_NUMBER() OVER( PARTITION BY Branch_id ORDER BY Sum_loan_amount ASC) AS R2
FROM Cross_50mill)

SELECT Branch_id, Sum_loan_amount, Date_of_payment
FROM First_50mill
WHERE R2 = 1


/*   7.	Write a query that finds, for every pair of branches in the same city, 
		the difference in their loan default rates (a self-join on branches, aggregated default rates as a CTE first). */

CREATE VIEW Difference AS

WITH Default_rate AS (
SELECT lo.branch_id AS Branch_id, br.city AS City,  CAST(SUM(CASE WHEN lo.status = 'Defaulted' THEN 1 ELSE 0 END) +
		SUM(CASE WHEN lo.status = 'Written Off' THEN 1 ELSE 0 END) AS FLOAT) *100 / COUNT(lo.loan_amount) AS default_rates_by_branch_id
FROM loans AS lo
JOIN branches AS br
ON br.branch_id = lo.branch_id
GROUP BY lo.branch_id, br.city )

SELECT d1.Branch_id AS Branch_id_1, d2.Branch_id AS Branch_id_2, d1.City AS City, 
		ROUND( d1.default_rates_by_branch_id,2 ) AS default_rates_by_branch_id_1, 
		ROUND( d2.default_rates_by_branch_id,2 ) AS default_rates_by_branch_id_2, 
		ROUND( ABS( d1.default_rates_by_branch_id - d2.default_rates_by_branch_id ),2 ) AS Difference
FROM Default_rate AS d1
JOIN Default_rate AS d2
ON d1.City = d2.City
WHERE d1.Branch_id < d2.Branch_id

/*  ANALYSIS OF 7TH POINT --------> the biggest same-city default-rate gap is 12.24 percentage 
	points between two branches (IDs 50 and 89) in the same city — one branch's loan book is 
	defaulting at a meaningfully different rate than another branch just down the road, serving
	what's presumably a similar local economy. */



	 
/*   8.	Compute each employee's tenure_years, then find the correlation-like signal: for each branch, compare 
		AVG(tenure_years) of employees against the branch's default_rate_pct — output branches sorted by tenure 
		but flag whether higher-tenure branches actually have lower default rates (no need for real CORR() unless 
		your dialect supports it — Postgres does: CORR(x,y)).  */

CREATE VIEW signal AS 

WITH Tenure_per_branch AS (
SELECT branch_id AS Branch_id, COUNT(employee_id) AS no_of_employee, AVG(DATEDIFF(DAY, hire_date, GETDATE())/365.25)  AS Tenure
FROM employees
GROUP BY branch_id),

Defaulted_rate_per_branch AS (
SELECT lo.branch_id AS Branch_id, 
	ROUND( CAST (SUM(CASE WHEN lo.status = 'Defaulted' THEN 1 ELSE 0 END) + SUM(CASE WHEN lo.status = 'Written Off' THEN 1 ELSE 0 END) AS FLOAT)/
	SUM(CASE WHEN lo.status IS NOT NULL THEN 1 ELSE 0 END) * 100, 2 ) AS Defaulted_rate
FROM loans AS lo
GROUP BY lo.branch_id
),
Joint AS(
SELECT t1.Branch_id AS Branch_id, t1.no_of_employee AS no_of_employee, t1.Tenure AS Tenure, d1.Defaulted_rate AS Defaulted_rate
FROM Tenure_per_branch AS t1
JOIN Defaulted_rate_per_branch AS d1
ON t1.Branch_id = d1.Branch_id)

SELECT *,
		CASE
		WHEN Tenure > AVG(Tenure) OVER() AND Defaulted_rate < AVG(Defaulted_rate) OVER() THEN 'Hypothesis Holds'
		WHEN Tenure < AVG(Tenure) OVER() AND Defaulted_rate >= AVG(Defaulted_rate) OVER() THEN 'Hypothesis Fails'
		ELSE 'Low tenure branch'
       END AS signal
FROM Joint


/*	 9.	For each branch, find the month with the highest total transaction volume (from transactions)
		— this needs GROUP BY branch_id, month then picking the max per branch via ROW_NUMBER() or DISTINCT ON. */

CREATE VIEW highest_total_transaction_volume AS 

WITH Amount AS (
	SELECT ac.branch_id AS Branch_id,  DATEFROMPARTS(YEAR(tr.txn_date), MONTH(tr.txn_date), 1) AS Txn_Month, SUM(tr.amount) AS Amount,
		ROW_NUMBER() OVER(PARTITION BY ac.branch_id ORDER BY SUM(tr.amount) DESC  ) AS r
	FROM accounts AS ac
	JOIN transactions AS tr
	ON ac.account_id = tr.account_id
	GROUP BY ac.branch_id, YEAR(tr.txn_date), MONTH(tr.txn_date))

SELECT Branch_id, Txn_Month, Amount
FROM Amount
WHERE r = 1


/*	10.	Build a full composite performance score per branch entirely in SQL: z-score-normalize account_count, loan_amount_total, 
		and avg_satisfaction (positive metrics) and default_rate_pct, fraud_rate_pct (negative metrics), sum them, and return 
		the top 10 and bottom 10 branches. (This is the hardest one — needs CTEs for each metric's mean/stddev, then a final scoring CTE.) */

CREATE VIEW final_score AS 

WITH Z_account_count AS (
SELECT branch_id AS branch_id, COUNT(account_id) AS account_per_branch, AVG(COUNT(account_id)) OVER() AS account, STDEV(COUNT(account_id)) OVER() AS standard_deviation,
		(COUNT(account_id) - AVG(COUNT(account_id)) OVER()) 
		/ STDEV(COUNT(account_id)) OVER() AS z_account_count
FROM accounts
GROUP BY branch_id ),

Z_loan_amount AS (
SELECT branch_id AS branch_id , SUM(loan_amount) AS loan_per_branch, 
		(SUM(loan_amount) - AVG(SUM(loan_amount)) OVER()) 
		/ STDEV(SUM(loan_amount)) OVER() AS z_loan_amount
FROM loans
GROUP BY branch_id ),

Customer_account AS (
SELECT ac.customer_id AS customer_id, ac.open_date AS open_date, ac.account_id AS account_id, ac.branch_id AS branch_id, 
		ROW_NUMBER() OVER( PARTITION BY ac.customer_id ORDER BY ac.open_date ASC ) AS rows_num
FROM accounts AS ac
INNER JOIN customers AS cu
ON ac.customer_id = cu.customer_id ),

Primary_account AS(
SELECT customer_id AS customer_id, account_id AS account_id, branch_id AS branch_id
FROM Customer_account
WHERE rows_num = 1),

Z_satisfaction_score AS (
SELECT  pr.branch_id AS branch_id, AVG(su.satisfaction_score) AS satisfaction_score_sum,
		(AVG(su.satisfaction_score) - AVG(AVG(su.satisfaction_score)) OVER()) 
		/ STDEV(AVG(su.satisfaction_score)) OVER() AS z_satisfaction_score
FROM support_tickets su
INNER JOIN Primary_account pr
ON su.customer_id = pr.customer_id
GROUP BY pr.branch_id ),

Default_rate AS (
SELECT branch_id AS branch_id, SUM(CASE WHEN status = 'Defaulted'OR status ='Written Off' THEN 1 ELSE 0 END)*100 
		/ CAST(COUNT(loan_id) AS FLOAT) AS Defaulted_rate
FROM loans
GROUP BY branch_id),

Z_default_rate AS (
SELECT branch_id AS branch_id, (SUM(Defaulted_rate) - AVG(SUM(Defaulted_rate)) OVER()) 
		/ STDEV(SUM(Defaulted_rate)) OVER() AS z_default_rate
FROM Default_rate
GROUP BY branch_id ),

Fraud_per_branch AS (
SELECT ac.branch_id AS branch_id, SUM(CASE WHEN ct.is_fraud = 1 THEN 1 ELSE 0 END)*100 
		/ CAST(COUNT(ct.is_fraud)AS FLOAT) AS Fraud_rate
FROM card_transactions AS ct
LEFT JOIN cards AS ca
ON ct.card_id = ca.card_id
LEFT JOIN accounts AS ac
ON ca.account_id = ac.account_id
GROUP BY ac.branch_id ),

Z_fraud_rate AS (
SELECT branch_id AS branch_id, (SUM(Fraud_rate) - AVG(SUM(Fraud_rate)) OVER()) 
		/ STDEV(SUM(Fraud_rate)) OVER() AS z_fraud_rate
FROM Fraud_per_branch
GROUP BY branch_id),

Top_10_final_score AS (
SELECT TOP 10 ac.branch_id AS branch_id, ac.z_account_count + lo.z_loan_amount + 
		sa.z_satisfaction_score - de.z_default_rate - fr.z_fraud_rate AS final_score
FROM Z_account_count AS ac
JOIN Z_loan_amount AS lo
ON ac.branch_id = lo.branch_id
JOIN Z_satisfaction_score AS sa
ON ac.branch_id = sa.branch_id
JOIN Z_default_rate AS de
ON ac.branch_id = de.branch_id
JOIN Z_fraud_rate AS fr
ON ac.branch_id = fr.branch_id
ORDER BY final_score DESC ),

Bottom_10_final_score AS(
SELECT TOP 10 ac.branch_id AS branch_id , ac.z_account_count + lo.z_loan_amount + 
		sa.z_satisfaction_score - de.z_default_rate - fr.z_fraud_rate AS final_score
FROM Z_account_count AS ac
JOIN Z_loan_amount AS lo
ON ac.branch_id = lo.branch_id
JOIN Z_satisfaction_score AS sa
ON ac.branch_id = sa.branch_id
JOIN Z_default_rate AS de
ON ac.branch_id = de.branch_id
JOIN Z_fraud_rate AS fr
ON ac.branch_id = fr.branch_id
ORDER BY final_score ASC)

SELECT * 
FROM Top_10_final_score
UNION ALL
SELECT * 
FROM Bottom_10_final_score

/*  11.	Find branches where the Loan Officer headcount per 100 active loans is below the 25th percentile 
		company-wide (use PERCENTILE_CONT). */

CREATE VIEW Loan_officer_per_branch AS 

WITH Loan_officer_per_branch AS (
SELECT branch_id AS branch_id, SUM(CASE WHEN role = 'Loan Officer' THEN 1 ELSE 0 END) AS loan_officer_count
FROM employees
GROUP BY branch_id ),

Active_loans_per_branch AS (
SELECT branch_id AS branch_id, SUM(CASE WHEN status = 'Active' THEN 1 ELSE 0 END) AS active_loan
FROM loans
GROUP BY branch_id ),

P25 AS (
SELECT lo.branch_id, (CAST(lo.loan_officer_count AS FLOAT) / ac.active_loan) * 100 AS loan_officer_per_100_active_loan,
		PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY CAST(lo.loan_officer_count AS FLOAT) * 100 / ac.active_loan) OVER () AS p25
FROM Loan_officer_per_branch AS lo
JOIN Active_loans_per_branch AS ac
ON lo.branch_id = ac.branch_id )

SELECT *
FROM P25
WHERE loan_officer_per_100_active_loan < p25


/*  12.	For each branch, identify the single largest month-over-month drop in new account openings 
		(window function LAG() on monthly counts), and return the branch + month with the steepest decline. */

CREATE VIEW branch_steepest_decline AS 

WITH count_lag_count AS (
SELECT branch_id AS branch_id , YEAR(open_date) AS Year, MONTH(open_date) AS Month , COUNT(account_id) AS id_count,
		LAG(COUNT(account_id)) OVER( PARTITION BY branch_id ORDER BY YEAR(open_date), MONTH(open_date) ) AS lag_count
FROM accounts
GROUP BY branch_id , YEAR(open_date) , MONTH(open_date) ),

Decline AS (
SELECT branch_id AS branch_id ,YEAR AS Year, Month AS Month, id_count - lag_count AS decline, ROW_NUMBER() OVER(PARTITION BY branch_id ORDER BY id_count - lag_count ASC) AS rn
FROM count_lag_count )

SELECT branch_id,Year, Month, Decline AS steepest_decline
FROM Decline
WHERE rn = 2  


