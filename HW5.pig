-- HW5 - Part 1
-- Pass -param INPUT=/path/to/amazon_reviews_us_Camera_v1_00.tsv
%default INPUT 'amazon_reviews_us_Camera_v1_00.tsv'
%default OUTPUT 'hw5_part1_results'

raw = LOAD '$INPUT' USING PigStorage('\t') AS (
  marketplace:chararray, customer_id:chararray, review_id:chararray,
  product_id:chararray, product_parent:chararray, product_title:chararray,
  product_category:chararray, star_rating:int, helpful_votes:long,
  total_votes:long, vine:chararray, verified_purchase:chararray,
  review_headline:chararray, review_body:chararray, review_date:chararray
);
-- Remove the header and check the fields used in Part 1.
reviews = FILTER raw BY marketplace IS NOT NULL AND marketplace != 'marketplace'
  AND review_id IS NOT NULL AND product_category IS NOT NULL
  AND star_rating >= 1 AND star_rating <= 5;

-- Part 1 - Problem 1
pairs_grouped = GROUP reviews BY (marketplace, product_category);
pairs = FOREACH pairs_grouped GENERATE group.marketplace AS marketplace,
  group.product_category AS category, COUNT(reviews.review_id) AS review_count,
  AVG(reviews.star_rating) AS average_rating;
part1_1 = ORDER pairs BY marketplace ASC, category ASC;
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
DUMP part1_3;
STORE part1_3 INTO '$OUTPUT/part1_3' USING PigStorage('\t');
