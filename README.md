# Banking Analytics — SQL & Power BI

An end-to-end banking analytics project combining **SQL Server analysis** with an interactive **Power BI dashboard**.

## Project Overview

This project analyzes a banking dataset across customers, accounts, branches, employees, loans, transactions, cards, fraud, and support tickets.

The SQL analysis covers advanced analytical SQL patterns such as:

- `RANK()` / `DENSE_RANK()`
- Window functions
- `ROW_NUMBER()` and `LAG()`
- CTEs and subqueries
- Running totals
- Standard deviation and z-score normalization
- Percentiles with `PERCENTILE_CONT`
- Self-joins
- Branch-level performance scoring
- Loan default and fraud-rate analysis
- Employee tenure analysis
- Month-over-month account-opening declines

The Power BI report contains three dashboard pages covering branch/account performance, employee and staffing analysis, and loan/risk performance.

## Repository Structure

```text
banking-git-repo/
├── README.md
├── .gitignore
├── .gitattributes
├── LICENSE
├── sql/
│   └── BANKING.sql
└── docs/
    └── data-model.md
```

> The `.pbix` file is intentionally managed with Git LFS because Power BI files can exceed GitHub's normal 100 MB file limit.

## Dataset / Model

The Power BI model contains these core tables:

- `accounts`
- `branches`
- `card_transactions`
- `cards`
- `customers`
- `employees`
- `loan_payments`
- `loans`
- `support_tickets`
- `transactions`

The SQL script also creates analytical views including:

- `TOTAL_BALANCE`
- `Defaulted_rate`
- `average_salary_as_a_percentage`
- `avg_support`
- `Status_employee`
- `Date_of_payment`
- `Difference`
- `signal`
- `highest_total_transaction_volume`
- `final_score`
- `Loan_officer_per_branch`
- `branch_steepest_decline`

## Power BI Dashboard

### Page 1 — Branch & Account Overview

Includes visuals for:

- Account-related KPIs
- Branch-level account distribution
- Employee distribution by branch
- Number of accounts per branch
- Branch filtering/slicing

### Page 2 — Workforce & Branch Operations

Includes analysis of:

- Employees by branch
- Employee/account staffing ratios
- Account-per-employee analysis
- Employee tenure versus default rate
- Role distribution
- Branch staffing status

### Page 3 — Loan & Risk Performance

Includes analysis of:

- High-risk branches by default rate
- Loan portfolio size by branch
- Branches crossing ₹50M cumulative loan originations
- Branch performance scoring
- Branch-level risk/performance indicators

## SQL Analysis Highlights

### 1. Branch ranking
Ranks branches within each state according to total account balance.

### 2. Loan default rate
Identifies the top branches by defaulted + written-off loan percentage, subject to a minimum loan-volume condition.

### 3. Payroll mix
Calculates average salary and each role's share of branch payroll.

### 4. Customer support
Identifies branches whose average customer satisfaction is below the company-wide average.

### 5. Staffing classification
Classifies branches as `Understaffed`, `Overstaffed`, or `Normal` using the account-per-employee ratio and one standard deviation from the mean.

### 6. ₹50M cumulative loan threshold
Calculates running loan originations and identifies when each branch first crosses ₹50 million.

### 7. Same-city default-rate comparison
Uses a self-join to compare default rates between branches operating in the same city.

### 8. Employee tenure signal
Compares average employee tenure with branch default rates.

### 9. Highest transaction month
Finds the month with the highest transaction volume for each branch.

### 10. Composite branch score
Builds a z-score-based branch performance score using:

- Account count
- Total loan amount
- Average satisfaction
- Default rate
- Fraud rate

### 11. Loan officer staffing
Identifies branches below the company-wide 25th percentile for loan officers per 100 active loans.

### 12. Account-opening decline
Uses `LAG()` to identify the steepest month-over-month decline in new account openings for each branch.

## Tools & Technologies

- **SQL Server / T-SQL**
- **Power BI**
- **DAX**
- **Microsoft Excel** (supporting analysis, where applicable)
- **Git / GitHub**
- **Git LFS** for the Power BI `.pbix` file

## How to Use

### SQL

1. Open `sql/BANKING.sql` in SQL Server Management Studio or Azure Data Studio.
2. Connect to the database containing the banking tables.
3. Run the queries/views in sequence.
4. Review the resulting analytical views.

### Power BI

1. Install Power BI Desktop.
2. Obtain the `banking.pbix` file.
3. Open it in Power BI Desktop.
4. Refresh the data source if your database connection differs from the original environment.

## Git LFS Setup

Because `banking.pbix` is larger than GitHub's standard file limit, use Git LFS:

```bash
git lfs install
git lfs track "*.pbix"
git add .gitattributes
git add banking.pbix
git commit -m "Add Power BI banking dashboard"
git push origin main
```

## Suggested Git Workflow

```bash
git init
git add .
git commit -m "Initial banking analytics project"
git branch -M main
git remote add origin <YOUR_GITHUB_REPOSITORY_URL>
git push -u origin main
```

## Portfolio Value

This project demonstrates practical skills in:

- Advanced SQL analytics
- Window functions and CTEs
- Banking KPI analysis
- Risk and fraud analysis
- Branch performance measurement
- Workforce analytics
- Power BI dashboard development
- Business-oriented data storytelling

## Notes

The SQL script is preserved from the working analysis. Before presenting the project as production-ready, validate the final SQL views against the target SQL Server version and review any assumptions in the business definitions.
