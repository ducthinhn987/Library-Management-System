-- =====================================================================
-- PROJECT : Topic 22 - Library Management System
-- VERSION : 2 - adds SET NAMES ... COLLATE to avoid error 1267
-- FILE    : The five queries the database must answer (Part 3, Topic 22)
-- DBMS    : MySQL 8.4.11 | Tool: DBeaver26.2.2
-- RUN     : Run database.sql first (it creates and fills
--           library_management_db), then run this script.
--
-- MySQL-specific parts (Requirement 2.3: say so in a comment):
--   * user variables  SET @name = ...   (stand-ins for the "?" parameters
--                                        that the Java PreparedStatement fills)
--   * CURRENT_DATE, MAKEDATE() and LIMIT
--   * the views Loan_Detail_Fine / Loan_Summary use DATEDIFF and GREATEST
--
-- "Today" in these queries is CURRENT_DATE, so results of Q2 and Q5 depend
-- on the day the script is run (the sample loans are already overdue).
-- =====================================================================

USE library_management_db;

-- The database was created with utf8mb4_unicode_ci, but a MySQL 8 connection
-- defaults to utf8mb4_0900_ai_ci. A user variable (@title, ...) takes the
-- connection collation, so comparing it with a column fails with
-- "Illegal mix of collations" (error 1267). Match the connection to the
-- database; run the whole script in ONE session so this line stays in effect.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;


-- =====================================================================
-- Q1. Which copies of a given title are currently available?
-- Helped by: idx_book_title, idx_book_copy_status (Book_ID, Status)
-- Technique: multi-table join (Book + Book_Copy)
-- Java parameter: title (String)  ->  WHERE b.Title = ?
-- Expected on sample data: 2 rows (B01-C01 and B01-C02)
-- =====================================================================
SET @title = 'Introduction to Algorithms';

SELECT b.Book_ID,
       b.Title,
       bc.Copy_ID,
       bc.Shelf_Location,
       bc.Condition_Notes
FROM Book b
INNER JOIN Book_Copy bc
        ON bc.Book_ID = b.Book_ID
WHERE b.Title   = @title
  AND bc.Status = 'Available'          -- not Borrowed, Reserved, Damaged or Lost
ORDER BY bc.Copy_ID;


-- =====================================================================
-- Q2. Which loans of one member are overdue today?
--     (a copy is overdue when it has not been returned and its due date
--      is before today; the fine so far comes from view Loan_Detail_Fine)
-- Helped by: index_loanTransaction_member_due (Member_ID, Due_Date),
--            idx_loan_detail_return_date (Return_Date)
-- Technique: multi-table join + view
-- Java parameter: member id (String)  ->  WHERE lt.Member_ID = ?
-- Expected on sample data for M01: 3 rows (L03-D01, L03-D02, L06-D01)
-- =====================================================================
SET @member_id = 'M01';

SELECT lt.Loan_ID,
       ld.Detail_ID,
       b.Title,
       ld.Copy_ID,
       lt.Borrow_Date,
       lt.Due_Date,
       f.Days_Late,
       f.Fine_Amount                   -- VND, 5,000 per day late so far
FROM Loan_Transaction lt
INNER JOIN Loan_Detail ld
        ON ld.Loan_ID = lt.Loan_ID
INNER JOIN Book b
        ON b.Book_ID = ld.Book_ID
INNER JOIN Loan_Detail_Fine f
        ON f.Loan_ID   = ld.Loan_ID
       AND f.Detail_ID = ld.Detail_ID
WHERE lt.Member_ID   = @member_id
  AND ld.Return_Date IS NULL           -- still out
  AND lt.Due_Date    < CURRENT_DATE    -- and already past its due date
ORDER BY lt.Due_Date, lt.Loan_ID, ld.Detail_ID;


-- =====================================================================
-- Q3. What are the ten most borrowed titles this year?
--     (one loan line = one copy borrowed; the year is the year of today)
-- Helped by: idx_loantransaction_borrow_date (the year is written as a
--            date range, so the index on Borrow_Date can be used)
-- Technique: aggregation with GROUP BY, ORDER BY ... LIMIT
-- Note: ties are broken by title, so the 10th place among equal counts
--       is decided alphabetically.
-- Expected on sample data: Algorithms Unlocked (3), Introduction to
--       Algorithms (3), Clean Code (2), then titles with 1 loan each.
-- =====================================================================
SELECT b.Book_ID,
       b.Title,
       COUNT(*) AS Times_Borrowed
FROM Loan_Detail ld
INNER JOIN Loan_Transaction lt
        ON lt.Loan_ID = ld.Loan_ID
INNER JOIN Book b
        ON b.Book_ID = ld.Book_ID
WHERE lt.Borrow_Date >= MAKEDATE(YEAR(CURRENT_DATE), 1)         -- 1 Jan this year
  AND lt.Borrow_Date <  MAKEDATE(YEAR(CURRENT_DATE) + 1, 1)     -- 1 Jan next year
GROUP BY b.Book_ID, b.Title
ORDER BY Times_Borrowed DESC, b.Title
LIMIT 10;


-- =====================================================================
-- Q4. Which members have borrowed EVERY title written by a given author?
-- Helped by: idx_author_name
-- Technique: relational division, written with NOT EXISTS ("for all")
--   Read it as: a member qualifies if there is NO title of the author
--   for which there is NO loan line of that member.
--   The first EXISTS stops an author with no titles from qualifying
--   every member (the empty "for all" is vacuously true).
-- Java parameter: author name (String), used twice (or pass Author_ID)
-- Expected on sample data for Thomas H. Cormen (B01, B02): M01 and M02
-- =====================================================================
SET @author_name = 'Thomas H. Cormen';

SELECT m.Member_ID,
       m.Full_Name
FROM Member m
WHERE EXISTS (                                   -- the author has at least one title
          SELECT 1
          FROM Author a
          INNER JOIN Book_Author ba
                  ON ba.Author_ID = a.Author_ID
          WHERE a.Author_Name = @author_name
      )
  AND NOT EXISTS (                               -- no title of the author ...
          SELECT 1
          FROM Author a
          INNER JOIN Book_Author ba
                  ON ba.Author_ID = a.Author_ID
          WHERE a.Author_Name = @author_name
            AND NOT EXISTS (                     -- ... that this member never borrowed
                    SELECT 1
                    FROM Loan_Transaction lt
                    INNER JOIN Loan_Detail ld
                            ON ld.Loan_ID = lt.Loan_ID
                    WHERE lt.Member_ID = m.Member_ID
                      AND ld.Book_ID   = ba.Book_ID
                )
      )
ORDER BY m.Member_ID;


-- =====================================================================
-- Q5. What is the total of fines still outstanding per member category?
--     (a fine is outstanding while Fine_Amount > 0 and Payment_Status is
--      neither 'Paid' nor 'Waived'; same definition as view Loan_Detail_Fine)
-- Helped by: idx_loan_detail_payment_status
-- Technique: multi-table join + view + aggregation with GROUP BY
-- Expected on sample data (run on 2026-11-14):
--   MC01 Undergraduate Student  5 lines  1,255,000
--   MC08 Alumni Standard        1 line     280,000
--   MC03 Doctoral Researcher    2 lines    115,000
--   MC05 Visiting Scholar       1 line      50,000
-- (amounts of copies still out grow every day, so the totals change)
-- =====================================================================
SELECT mc.Member_Type_ID,
       mc.Type_Name,
       COUNT(*)           AS Fine_Lines,
       SUM(f.Fine_Amount) AS Total_Outstanding_VND
FROM Loan_Detail_Fine f
INNER JOIN Member m
        ON m.Member_ID = f.Member_ID
INNER JOIN Member_Category mc
        ON mc.Member_Type_ID = m.Member_Type_ID
WHERE f.Fine_Amount > 0
  AND f.Payment_Status NOT IN ('Paid', 'Waived')
GROUP BY mc.Member_Type_ID, mc.Type_Name
ORDER BY Total_Outstanding_VND DESC;
