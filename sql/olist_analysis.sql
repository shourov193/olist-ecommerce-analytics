-- Create the database
CREATE DATABASE olist_clean;

USE olist_clean;
-- Create the fact table

select * from fact_olist; 


-- ==================== Analysis ==================== --

-- ── VERIFY IMPORT ─────────────────────────────────────────
SELECT COUNT(*) AS total_rows FROM fact_olist;
SELECT * FROM fact_olist LIMIT 3;

-- ── SANITY CHECKS ─────────────────────────────────────────
SELECT DISTINCT delivery_status FROM fact_olist;
SELECT order_year, COUNT(*) AS orders FROM fact_olist GROUP BY order_year ORDER BY order_year;
SELECT COUNT(*) AS null_price_count FROM fact_olist WHERE price IS NULL;
SELECT DISTINCT product_category FROM fact_olist ORDER BY product_category LIMIT 15;

-- ── ANALYSIS 1: Monthly Revenue ───────────────────────────
SELECT
    order_year,
    order_month,
    month_name,
    CONCAT(order_year, '-', LPAD(order_month, 2, '0')) AS yr_month,
    COUNT(DISTINCT order_id)     AS total_orders,
    ROUND(SUM(price), 2)         AS revenue,
    ROUND(AVG(price), 2)         AS avg_order_value,
    ROUND(SUM(freight_value), 2) AS total_freight
FROM fact_olist
WHERE order_year IN (2017, 2018)
GROUP BY order_year, order_month, month_name
ORDER BY order_year, order_month;

-- ── ANALYSIS 2: Revenue by Product Category ───────────────
SELECT
    product_category,
    COUNT(DISTINCT order_id)    AS orders,
    ROUND(SUM(price), 2)        AS revenue,
    ROUND(AVG(price), 2)        AS avg_price,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM fact_olist
WHERE review_score > 0
GROUP BY product_category
ORDER BY revenue DESC
LIMIT 15;

-- ── ANALYSIS 3: Delivery Performance by State ─────────────
SELECT
    customer_state,
    COUNT(DISTINCT order_id)                                   AS total_orders,
    ROUND(AVG(delivery_days), 1)                               AS avg_delivery_days,
    SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1
    )                                                          AS late_rate_pct
FROM fact_olist
GROUP BY customer_state
HAVING COUNT(DISTINCT order_id) > 200
ORDER BY late_rate_pct DESC;

-- ── ANALYSIS 4: Review Sentiment by Category ──────────────
SELECT
    product_category,
    COUNT(*)                                                           AS total_reviews,
    ROUND(AVG(review_score), 2)                                        AS avg_score,
    SUM(CASE WHEN review_sentiment = 'Positive' THEN 1 ELSE 0 END)   AS positive,
    SUM(CASE WHEN review_sentiment = 'Negative' THEN 1 ELSE 0 END)   AS negative,
    ROUND(
        SUM(CASE WHEN review_sentiment = 'Positive' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1
    )                                                                  AS positive_pct
FROM fact_olist
WHERE review_score > 0
GROUP BY product_category
ORDER BY avg_score DESC
LIMIT 15;

-- ── ANALYSIS 5: Payment Type ──────────────────────────────
SELECT
    payment_type,
    COUNT(DISTINCT order_id)            AS orders,
    ROUND(SUM(payment_value), 2)        AS total_payment,
    ROUND(AVG(payment_value), 2)        AS avg_payment,
    ROUND(AVG(payment_installments), 1) AS avg_installments
FROM fact_olist
GROUP BY payment_type
ORDER BY orders DESC;

-- ── ANALYSIS 6: Revenue by State ──────────────────────────
SELECT
    customer_state,
    COUNT(DISTINCT order_id)    AS orders,
    ROUND(SUM(price), 2)        AS revenue,
    ROUND(AVG(price), 2)        AS avg_order_value
FROM fact_olist
GROUP BY customer_state
ORDER BY revenue DESC;

-- ── ANALYSIS 7: Month-over-Month Growth ───────────────────
WITH monthly AS (
    SELECT
        order_year,
        order_month,
        CONCAT(order_year, '-', LPAD(order_month, 2, '0')) AS yr_month,
        ROUND(SUM(price), 2) AS revenue
    FROM fact_olist
    WHERE order_year IN (2017, 2018)
    GROUP BY order_year, order_month
)
SELECT
    yr_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_year, order_month)  AS prev_month_rev,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY order_year, order_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_year, order_month), 0)
        * 100, 1
    )                                                      AS mom_growth_pct
FROM monthly;

-- ── ANALYSIS 8: Top 20 Sellers ────────────────────────────
SELECT
    seller_id,
    COUNT(DISTINCT order_id)    AS orders,
    ROUND(SUM(price), 2)        AS revenue,
    ROUND(AVG(review_score), 2) AS avg_review
FROM fact_olist
WHERE review_score > 0
GROUP BY seller_id
ORDER BY revenue DESC
LIMIT 20;

-- ── DROP OLD VIEWS IF EXIST ───────────────────────────────
DROP VIEW IF EXISTS vw_monthly;
DROP VIEW IF EXISTS vw_category;
DROP VIEW IF EXISTS vw_state;
DROP VIEW IF EXISTS vw_fact_main;

-- ── CREATE VIEWS FOR POWER BI ─────────────────────────────
CREATE VIEW vw_monthly AS
SELECT
    order_year,
    order_month,
    month_name,
    CONCAT(order_year, '-', LPAD(order_month, 2, '0')) AS yr_month,
    COUNT(DISTINCT order_id)    AS total_orders,
    ROUND(SUM(price), 2)        AS revenue,
    ROUND(AVG(review_score), 2) AS avg_review
FROM fact_olist
WHERE order_year IN (2017, 2018)
GROUP BY order_year, order_month, month_name;

CREATE VIEW vw_category AS
SELECT
    product_category,
    COUNT(DISTINCT order_id)  AS orders,
    ROUND(SUM(price), 2)      AS revenue,
    ROUND(AVG(price), 2)      AS avg_price,
    ROUND(AVG(
        CASE WHEN review_score > 0 THEN review_score END
    ), 2)                     AS avg_review
FROM fact_olist
GROUP BY product_category;

CREATE VIEW vw_state AS
SELECT
    customer_state,
    COUNT(DISTINCT order_id)                                   AS orders,
    ROUND(SUM(price), 2)                                       AS revenue,
    ROUND(AVG(delivery_days), 1)                               AS avg_delivery_days,
    ROUND(
        SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 1
    )                                                          AS late_pct
FROM fact_olist
GROUP BY customer_state;

CREATE VIEW vw_fact_main AS
SELECT * FROM fact_olist
WHERE order_year IN (2017, 2018);

-- ── VERIFY VIEWS ──────────────────────────────────────────
SELECT COUNT(*) AS fact_main_rows FROM vw_fact_main;
SELECT COUNT(*) AS monthly_rows   FROM vw_monthly;
SELECT COUNT(*) AS category_rows  FROM vw_category;
SELECT COUNT(*) AS state_rows     FROM vw_state;
