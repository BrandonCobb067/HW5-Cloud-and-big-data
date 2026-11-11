-- HW5 - Parts 1, 2, and 3
SET pig.print.header true;

-- Pass -param INPUT=/path/to/amazon_reviews_us_Camera_v1_00.tsv
%default INPUT 'amazon_reviews_us_Camera_v1_00.tsv'
%default OUTPUT 'hw5_results'

raw = LOAD '$INPUT' USING PigStorage('\t') AS (
  marketplace:chararray, customer_id:chararray, review_id:chararray,
  product_id:chararray, product_parent:chararray, product_title:chararray,
  product_category:chararray, star_rating:int, helpful_votes:long,
  total_votes:long, vine:chararray, verified_purchase:chararray,
  review_headline:chararray, review_body:chararray, review_date:chararray
);
-- Remove the header and check the required review fields.
reviews = FILTER raw BY marketplace IS NOT NULL AND marketplace != 'marketplace'
  AND review_id IS NOT NULL AND product_category IS NOT NULL
  AND star_rating >= 1 AND star_rating <= 5;

-- Part 1 - Problem 1
pairs_grouped = GROUP reviews BY (marketplace, product_category);
pairs = FOREACH pairs_grouped GENERATE group.marketplace AS marketplace,
  group.product_category AS category, COUNT(reviews.review_id) AS review_count,
  AVG(reviews.star_rating) AS average_rating;
part1_1 = ORDER pairs BY marketplace ASC, category ASC;

sh echo "========================================";
sh echo "         PART 1 - PROBLEM 1             ";
sh echo "========================================";
DUMP part1_1;
STORE part1_1 INTO '$OUTPUT/part1_1' USING PigStorage('\t');

-- Part 1 - Problem 2
non_us = FILTER reviews BY marketplace != 'US';
non_us_categories = GROUP non_us BY product_category;
non_us_totals = FOREACH non_us_categories GENERATE group AS category,
  COUNT(non_us.review_id) AS category_count;
large_categories = FILTER non_us_totals BY category_count >= 1000;
non_us_groups = GROUP non_us BY (marketplace, product_category);
non_us_pairs = FOREACH non_us_groups GENERATE group.marketplace AS marketplace,
  group.product_category AS category, COUNT(non_us.review_id) AS review_count,
  AVG(non_us.star_rating) AS average_rating;
qualified = JOIN non_us_pairs BY category, large_categories BY category;
qualified_pairs = FOREACH qualified GENERATE non_us_pairs::marketplace AS marketplace,
  non_us_pairs::category AS category, non_us_pairs::review_count AS review_count,
  non_us_pairs::average_rating AS average_rating;
part1_2 = ORDER qualified_pairs BY review_count DESC, category ASC, marketplace ASC;

sh echo "========================================";
sh echo "         PART 1 - PROBLEM 2             ";
sh echo "========================================";
DUMP part1_2;
STORE part1_2 INTO '$OUTPUT/part1_2' USING PigStorage('\t');

-- Part 1 - Problem 3
category_groups = GROUP pairs BY category;
category_totals = FOREACH category_groups GENERATE group AS category,
  SUM(pairs.review_count) AS category_count;
pair_totals = JOIN pairs BY category, category_totals BY category;
shares = FOREACH pair_totals GENERATE pairs::category AS category,
  pairs::marketplace AS marketplace, pairs::review_count AS review_count,
  100.0 * pairs::review_count / category_totals::category_count AS share_pct;
share_groups = GROUP shares BY category;
top_marketplaces = FOREACH share_groups {
  sorted = ORDER shares BY review_count DESC, marketplace ASC;
  top_three = LIMIT sorted 3;
  GENERATE FLATTEN(top_three);
};
part1_3 = ORDER top_marketplaces BY category ASC, review_count DESC, marketplace ASC;

sh echo "========================================";
sh echo "         PART 1 - PROBLEM 3             ";
sh echo "========================================";
DUMP part1_3;
STORE part1_3 INTO '$OUTPUT/part1_3' USING PigStorage('\t');


-- Part 2

-- Part 2 - Problem 1
date_groups = GROUP reviews BY review_date;
date_totals = FOREACH date_groups GENERATE group AS review_date, 
    COUNT(reviews.review_id) AS total_reviews;

sh echo "========================================";
sh echo "         PART 2 - PROBLEM 1             ";
sh echo "========================================";
DUMP date_totals;
STORE date_totals INTO '$OUTPUT/part2_1' USING PigStorage('\t');


-- Part 2 - Problem 2
-- Average helpful votes over all reviews; total votes only where positive.
votes_filtered = FILTER reviews BY product_id IS NOT NULL;
product_groups = GROUP votes_filtered BY product_id;

product_averages = FOREACH product_groups {
    positive_votes = FILTER votes_filtered BY total_votes > 0;
    GENERATE group AS product_id,
        AVG(votes_filtered.helpful_votes) AS avg_helpful,
        AVG(positive_votes.total_votes) AS avg_total;
};
product_averages = FILTER product_averages BY avg_total > 0;

product_ratios = FOREACH product_averages GENERATE 
    product_id, 
    avg_helpful, 
    avg_total, 
    ((double)avg_helpful / (double)avg_total) AS helpfulness_ratio;

-- Use GROUP ALL and TOP to avoid the memory crash of a global ORDER BY
all_ratios = GROUP product_ratios ALL;
part2_2_top = FOREACH all_ratios {
    -- TOP(N, column_index, bag). Index 3 refers to helpfulness_ratio (0-indexed).
    top_items = TOP(50, 3, product_ratios);
    GENERATE FLATTEN(top_items);
};
part2_2_result = ORDER part2_2_top BY $3 DESC, $0 ASC;

sh echo "========================================";
sh echo "         PART 2 - PROBLEM 2             ";
sh echo "========================================";
DUMP part2_2_result;
STORE part2_2_result INTO '$OUTPUT/part2_2' USING PigStorage('\t');

-- Part 2 - Problem 3
-- Extract the month (YYYY-MM) from review_date
reviews_with_month = FOREACH reviews GENERATE product_id, star_rating, 
    SUBSTRING(review_date, 0, 7) AS month;

month_prod_groups = GROUP reviews_with_month BY (month, product_id);
month_prod_stats = FOREACH month_prod_groups GENERATE group.month AS month, 
    group.product_id AS product_id, 
    COUNT(reviews_with_month) AS review_count, 
    AVG(reviews_with_month.star_rating) AS avg_rating;

-- Only include if they have at least 50 reviews in that month
qualified_month_stats = FILTER month_prod_stats BY review_count >= 50;
month_groups = GROUP qualified_month_stats BY month;

top_5_per_month = FOREACH month_groups {
    -- Sort within each month by average star rating in descending order
    sorted_month = ORDER qualified_month_stats BY avg_rating DESC;
    top_5 = LIMIT sorted_month 5;
    GENERATE FLATTEN(top_5);
};

-- Ensure global ordering is clean for output
part2_3_result = ORDER top_5_per_month BY month ASC, avg_rating DESC;

sh echo "========================================";
sh echo "         PART 2 - PROBLEM 3             ";
sh echo "========================================";
DUMP part2_3_result;
STORE part2_3_result INTO '$OUTPUT/part2_3' USING PigStorage('\t');


-- Part 3

-- Filter records for verified purchases only
verified_reviews = FILTER reviews BY verified_purchase == 'Y';

-- Part 3 - Problem 1
cat_groups = GROUP verified_reviews BY product_category;
cat_stats = FOREACH cat_groups {
    dist_prods = DISTINCT verified_reviews.product_id;
    GENERATE group AS product_category, 
        COUNT(verified_reviews.product_id) AS total_rows, 
        COUNT(dist_prods) AS distinct_prods;
};

sh echo "========================================";
sh echo "         PART 3 - PROBLEM 1             ";
sh echo "========================================";
DUMP cat_stats;
STORE cat_stats INTO '$OUTPUT/part3_1' USING PigStorage('\t');


-- Part 3 - Problem 2
star_groups = GROUP verified_reviews BY star_rating;
star_sums = FOREACH star_groups GENERATE group AS star_rating, 
    SUM(verified_reviews.helpful_votes) AS sum_helpful, 
    SUM(verified_reviews.total_votes) AS sum_total;

-- Filter out zero denominators before division
star_filtered = FILTER star_sums BY sum_total > 0;
star_ratios = FOREACH star_filtered GENERATE star_rating, 
    sum_helpful, 
    sum_total, 
    (double)sum_helpful / (double)sum_total AS avg_votes;

part3_2_result = ORDER star_ratios BY avg_votes DESC;

sh echo "========================================";
sh echo "         PART 3 - PROBLEM 2             ";
sh echo "========================================";
DUMP part3_2_result;
STORE part3_2_result INTO '$OUTPUT/part3_2' USING PigStorage('\t');


-- Part 3 - Problem 3
-- Calculate category helpfulness rate
cat_help_groups = GROUP verified_reviews BY product_category;
cat_help_sums = FOREACH cat_help_groups GENERATE group AS category, 
    SUM(verified_reviews.helpful_votes) AS sum_helpful_cat, 
    SUM(verified_reviews.total_votes) AS sum_total_cat;

cat_help_filtered = FILTER cat_help_sums BY sum_total_cat > 0;
cat_rates = FOREACH cat_help_filtered GENERATE category, 
    (double)sum_helpful_cat / (double)sum_total_cat AS cat_help_rate;

-- Calculate product helpfulness rate (min 50 verified reviews)
prod_cat_groups = GROUP verified_reviews BY (product_category, product_id);
prod_stats = FOREACH prod_cat_groups GENERATE group.product_category AS category, 
    group.product_id AS product_id, 
    COUNT(verified_reviews) AS review_count, 
    SUM(verified_reviews.helpful_votes) AS sum_helpful_prod, 
    SUM(verified_reviews.total_votes) AS sum_total_prod;

prod_filtered = FILTER prod_stats BY review_count >= 50 AND sum_total_prod > 0;
prod_rates = FOREACH prod_filtered GENERATE category, 
    product_id, 
    review_count, 
    (double)sum_helpful_prod / (double)sum_total_prod AS prod_help_rate;

-- Join category rates and product rates
joined_rates = JOIN prod_rates BY category, cat_rates BY category;

-- Filter where product rate exceeds category rate by >= 10 percentage points (0.10)
excess_filtered = FILTER joined_rates BY prod_rates::prod_help_rate >= (cat_rates::cat_help_rate + 0.10);

final_format = FOREACH excess_filtered GENERATE 
    prod_rates::category AS category, 
    prod_rates::product_id AS product_id, 
    prod_rates::prod_help_rate AS helpfulness_rate, 
    prod_rates::review_count AS review_count, 
    cat_rates::cat_help_rate AS cat_help_rate, 
    (prod_rates::prod_help_rate - cat_rates::cat_help_rate) AS excess;

final_groups = GROUP final_format BY category;

top_3_excess_per_cat = FOREACH final_groups {
    -- Sort by excess helpfulness in descending order within each category
    sorted_excess = ORDER final_format BY excess DESC;
    top_3 = LIMIT sorted_excess 3;
    GENERATE FLATTEN(top_3);
};

part3_3_result = ORDER top_3_excess_per_cat BY category ASC, excess DESC;

sh echo "========================================";
sh echo "         PART 3 - PROBLEM 3             ";
sh echo "========================================";
DUMP part3_3_result;
STORE part3_3_result INTO '$OUTPUT/part3_3' USING PigStorage('\t');