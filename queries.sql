-- ============================================================
-- BC Surgical Wait Times Analysis
-- Author: Puwentao Yan
-- Data:   BC Data Catalogue — BC Surgical Wait Times
--         Fiscal years 2009/10 to 2025/26
-- Table:  surgery (single table, all aggregation levels)
--
-- Business question:
--   Which surgical procedure categories within Island Health
--   have the highest and most persistent wait time backlogs
--   since 2022, and how does Island Health compare to peer
--   health authorities?
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- QUERY 1: Province-wide waitlist trend over time
--
-- Answers: Has BC's overall surgical waitlist grown since 2009?
--          Where does COVID-19 appear in the trend?
--
-- Notes:
--   - Uses All Health Authorities + All Facilities + All
--     Procedures to get the true province grand total
--   - WAITING is a point-in-time snapshot at end of each
--     quarter — do not sum across quarters
--   - period_flag tags Pre-COVID / COVID Start / COVID Period
--     / Recovery for chart colouring
-- ─────────────────────────────────────────────────────────────
SELECT * 
FROM surgery
WHERE HEALTH_AUTHORITY = 'All Health Authorities' AND
    HOSPITAL_NAME = 'All Facilities' AND
    PROCEDURE_GROUP = 'All Procedures'
ORDER BY FISCAL_YEAR, QUARTER;


-- ─────────────────────────────────────────────────────────────
-- QUERY 2: Health authority comparison — current quarter only
--
-- Answers: How does Island Health compare to Fraser, Vancouver
--          Coastal, Interior, Northern, and Provincial health
--          authorities right now?
--
-- Notes:
--   - Excludes All Health Authorities rollup row to avoid
--     double-counting the province total alongside HA rows
--   - Uses MAX(period_label) subquery so no hardcoded quarter
--     — automatically picks the latest available period
--   - backlog_ratio > 1.0 means waitlist is growing
-- ─────────────────────────────────────────────────────────────
SELECT 
    FISCAL_YEAR,
    QUARTER,
    HEALTH_AUTHORITY,
    WAITING,
    COMPLETED,
    PERCENTILE_COMP_50TH,
    PERCENTILE_COMP_90TH,
    backlog_ratio
FROM surgery
WHERE HEALTH_AUTHORITY != 'All Health Authorities' AND
    HOSPITAL_NAME = 'All Facilities' AND
    PROCEDURE_GROUP = 'All Procedures' AND
    period_label = (SELECT MAX(period_label) FROM surgery)
ORDER BY WAITING DESC;


-- ─────────────────────────────────────────────────────────────
-- QUERY 3: Island Health trend over time
--
-- Answers: Has Island Health's waitlist grown or shrunk since
--          2009? How did COVID affect it specifically?
--          Is the backlog ratio recovering toward 1.0?
--
-- Notes:
--   - Most important query for Island Health and PHSA
--     interview contexts
--   - backlog_ratio staying above 1.0 through Recovery period
--     means demand is still outpacing surgical throughput
--   - Compare with Query 1 to see how closely Island Health
--     mirrors the province-wide trend
-- ─────────────────────────────────────────────────────────────
SELECT 
    FISCAL_YEAR,
    QUARTER,
    HEALTH_AUTHORITY,
    WAITING,
    COMPLETED,
    PERCENTILE_COMP_50TH,
    PERCENTILE_COMP_90TH,
    backlog_ratio,
    period_flag
FROM surgery
WHERE HEALTH_AUTHORITY = 'Vancouver Island'
    AND HOSPITAL_NAME = 'All Facilities'
    AND PROCEDURE_GROUP = 'All Procedures'
ORDER BY FISCAL_YEAR;


-- ─────────────────────────────────────────────────────────────
-- QUERY 4: Top 15 procedures by waitlist size — current quarter
--
-- Answers: Which procedures have the most patients waiting
--          province-wide right now?
--
-- Notes:
--   - Uses All Health Authorities + All Facilities level to
--     get government-calculated province totals per procedure
--   - All Other Procedures intentionally included — it is a
--     real catch-all bucket, not a rollup row
--   - WAITING here is volume (number of patients), not time
--   - Compare with Query 5 for wait time perspective — high
--     WAITING does not always mean long wait times
-- ─────────────────────────────────────────────────────────────
SELECT 
    FISCAL_YEAR,
    QUARTER,
    PROCEDURE_GROUP,
    WAITING,
    COMPLETED,
    PERCENTILE_COMP_50TH,
    PERCENTILE_COMP_90TH,
    backlog_ratio
FROM surgery
WHERE HEALTH_AUTHORITY = 'All Health Authorities' AND
    HOSPITAL_NAME = 'All Facilities' AND
    PROCEDURE_GROUP != 'All Procedures' AND
    period_label = (SELECT MAX(period_label) FROM surgery)
ORDER BY WAITING DESC
LIMIT 15;


-- ─────────────────────────────────────────────────────────────
-- QUERY 5: 50th vs 90th percentile gap over time
--
-- Answers: Are worst-case patients falling further behind the
--          median patient over time?
--
-- Notes:
--   - percentile_gap = 90th pctl minus 50th pctl in weeks
--   - A growing gap means inequality in wait times is
--     increasing — some patients are being left much further
--     behind than the typical patient
--   - Percentiles are based on COMPLETED cases only — patients
--     still waiting are not included in this calculation
--   - This is a derived analytical metric not in the source
--     data — created using SQL ROUND and subtraction
-- ─────────────────────────────────────────────────────────────
SELECT
    FISCAL_YEAR,
    QUARTER,
    period_label,
    period_flag,
    PERCENTILE_COMP_50TH,
    PERCENTILE_COMP_90TH,
    ROUND(PERCENTILE_COMP_90TH - PERCENTILE_COMP_50TH, 1) AS percentile_gap
FROM surgery
WHERE HEALTH_AUTHORITY = 'All Health Authorities'
AND HOSPITAL_NAME    = 'All Facilities'
AND PROCEDURE_GROUP  = 'All Procedures'
ORDER BY FISCAL_YEAR, QUARTER;


-- ─────────────────────────────────────────────────────────────
-- QUERY 6: Island Health hospital comparison — current quarter
--
-- Answers: Which hospitals within Island Health are driving
--          the backlog? Where should surgical capacity be
--          prioritised?
--
-- Notes:
--   - Uses specific hospital rows (HOSPITAL_NAME != All
--     Facilities) with All Procedures to get each hospital's
--     total waitlist without procedure-level double-counting
--   - Excludes All Facilities rollup to avoid counting the
--     Island Health total alongside its component hospitals
--   - Directly relevant to Island Health surgical planning
--     teams — identifies which facilities need resource focus
-- ─────────────────────────────────────────────────────────────
SELECT
    HOSPITAL_NAME,
    WAITING,
    COMPLETED,
    PERCENTILE_COMP_50TH,
    PERCENTILE_COMP_90TH,
    backlog_ratio
FROM surgery
WHERE HEALTH_AUTHORITY = 'Vancouver Island'
AND HOSPITAL_NAME    != 'All Facilities'
AND PROCEDURE_GROUP  = 'All Procedures'
AND period_label     = (SELECT MAX(period_label) FROM surgery)
ORDER BY WAITING DESC;
