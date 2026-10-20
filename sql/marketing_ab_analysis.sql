-- ============================================================
-- Marketing Campaign A/B Testing | Portfolio SQL Analysis
-- Database: marketing_ab_analysis
-- Table: marketing_campaign
-- MySQL 8.0+
-- Notes:
--   Converted is encoded as 1 (yes) and 0 (no).
--   Exposure/day/hour breakdowns describe associations, not
--   causal effects or optimal ad schedules.
--   Run after importing the cleaned dataset (364,521 records).
-- ============================================================

USE marketing_ab_analysis;

-- 1. DATA VALIDATION -------------------------------------------------
-- Expected: 364521 records, 12797 conversions, 364521 unique users.
SELECT
    COUNT(*) AS total_users,
    SUM(converted) AS total_conversions,
    COUNT(DISTINCT user_id) AS unique_users
FROM marketing_campaign;

-- Check missing values in critical fields.
SELECT
    SUM(user_id IS NULL) AS missing_user_ids,
    SUM(test_group IS NULL) AS missing_test_groups,
    SUM(converted IS NULL) AS missing_conversions,
    SUM(total_ads IS NULL) AS missing_total_ads,
    SUM(most_ads_day IS NULL) AS missing_days,
    SUM(most_ads_hour IS NULL) AS missing_hours,
    SUM(exposure_group IS NULL) AS missing_exposure_groups
FROM marketing_campaign;

-- 2. OVERALL CONVERSION PERFORMANCE ---------------------------------
-- Expected: ad: 351185 users, 12468 conversions, 3.55%;
--           psa: 13336 users, 329 conversions, 2.47%.
SELECT
    test_group,
    COUNT(*) AS total_users,
    SUM(converted) AS conversions,
    ROUND(AVG(converted) * 100, 2) AS conversion_rate_pct
FROM marketing_campaign
GROUP BY test_group
ORDER BY FIELD(test_group, 'ad', 'psa');

-- 3. EXPOSURE-LEVEL PERFORMANCE USING A CTE ------------------------
WITH exposure_performance AS (
    SELECT
        exposure_group,
        test_group,
        COUNT(*) AS total_users,
        SUM(converted) AS conversions
    FROM marketing_campaign
    GROUP BY exposure_group, test_group
)
SELECT
    exposure_group,
    test_group,
    total_users,
    conversions,
    ROUND(conversions * 100.0 / NULLIF(total_users, 0), 2)
        AS conversion_rate_pct
FROM exposure_performance
ORDER BY
    FIELD(exposure_group, '1-5', '6-10', '11-20',
          '21-50', '51-100', '101+'),
    FIELD(test_group, 'ad', 'psa');

-- 4. EXPOSURE-LEVEL RANKING USING A WINDOW FUNCTION ----------------
WITH exposure_summary AS (
    SELECT
        test_group,
        exposure_group,
        COUNT(*) AS total_users,
        SUM(converted) AS conversions,
        AVG(converted) * 100 AS conversion_rate_pct
    FROM marketing_campaign
    GROUP BY test_group, exposure_group
)
SELECT
    test_group,
    exposure_group,
    total_users,
    conversions,
    ROUND(conversion_rate_pct, 2) AS conversion_rate_pct,
    DENSE_RANK() OVER (
        PARTITION BY test_group
        ORDER BY conversion_rate_pct DESC
    ) AS performance_rank
FROM exposure_summary
ORDER BY FIELD(test_group, 'ad', 'psa'), performance_rank;

-- 5. DAILY COMPARISON USING CONDITIONAL AGGREGATION ---------------
-- most_ads_day is day of highest exposure, NOT conversion date.
WITH daily_performance AS (
    SELECT
        most_ads_day,
        test_group,
        AVG(converted) * 100 AS conversion_rate_pct
    FROM marketing_campaign
    GROUP BY most_ads_day, test_group
)
SELECT
    most_ads_day,
    ROUND(MAX(CASE WHEN test_group = 'ad'
              THEN conversion_rate_pct END), 2) AS ad_conversion_rate_pct,
    ROUND(MAX(CASE WHEN test_group = 'psa'
              THEN conversion_rate_pct END), 2) AS psa_conversion_rate_pct,
    ROUND(
        MAX(CASE WHEN test_group = 'ad' THEN conversion_rate_pct END)
        - MAX(CASE WHEN test_group = 'psa' THEN conversion_rate_pct END),
        2
    ) AS difference_percentage_points
FROM daily_performance
GROUP BY most_ads_day
ORDER BY FIELD(most_ads_day, 'Monday', 'Tuesday', 'Wednesday',
               'Thursday', 'Friday', 'Saturday', 'Sunday');

-- 6. HOURLY COMPARISON USING CONDITIONAL AGGREGATION --------------
-- most_ads_hour is hour of highest exposure, NOT purchase hour.
WITH hourly_performance AS (
    SELECT
        most_ads_hour,
        test_group,
        COUNT(*) AS total_users,
        SUM(converted) AS conversions,
        AVG(converted) * 100 AS conversion_rate_pct
    FROM marketing_campaign
    GROUP BY most_ads_hour, test_group
)
SELECT
    most_ads_hour,
    ROUND(MAX(CASE WHEN test_group = 'ad'
              THEN conversion_rate_pct END), 2) AS ad_conversion_rate_pct,
    ROUND(MAX(CASE WHEN test_group = 'psa'
              THEN conversion_rate_pct END), 2) AS psa_conversion_rate_pct,
    ROUND(
        MAX(CASE WHEN test_group = 'ad' THEN conversion_rate_pct END)
        - MAX(CASE WHEN test_group = 'psa' THEN conversion_rate_pct END),
        2
    ) AS difference_percentage_points
FROM hourly_performance
GROUP BY most_ads_hour
ORDER BY most_ads_hour;
