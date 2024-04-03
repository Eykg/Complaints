library(dplyr)
library(tidytext)
library(reshape2)
library(stringr)
library(tidyr)
library(ggplot2)

# Load stop words to remove common words
data("stop_words")

# Read the CSV file
df_complaints <- read.csv("Consumer_Complaints.csv")

# Filter out blank complaints columns and rename the complaint column
tidy_complaints <- df_complaints %>%
  filter(Consumer.complaint.narrative != "" & Company.public.response != "") %>%
  select(Product, Complain = Consumer.complaint.narrative, Company) 

# Clean the text: remove punctuation, numbers, and extra spaces
tidy_complaints <- tidy_complaints %>%
  mutate(Complain = stringr::str_replace_all(Complain, "[[:punct:]]", "") %>%
           stringr::str_remove_all("\\d+") %>%
           stringr::str_squish()) %>%
  # Tokenize the complaints into individual words after cleaning
  tidyr::unnest_tokens(word, Complain) %>%
  # Remove stop words, unnecessary characters, single characters, and numbers
  anti_join(stop_words, by = "word") %>%
  filter(!grepl("[^[:alnum:][:space:]]", word)) %>%
  filter(nchar(word) > 1) %>%
  filter(!grepl("\\d+", word))

# Load sentiment lexicons
nrc_lexicon <- get_sentiments("nrc")
afinn_lexicon <- get_sentiments("afinn")
bing_lexicon <- get_sentiments("bing")

# common joy words in products
nrc_joy <- nrc_lexicon %>%
  filter(sentiment == "joy")

joy_words <- tidy_complaints %>%
  filter(Product == "Credit card") %>%
  inner_join(nrc_joy) %>%
  count(word, sort = TRUE)

#negative and positive sentiment in separate columns
product_sentiment <- tidy_complaints %>%
  inner_join(bing_lexicon, by = "word") %>%
  count(Product, index = linenumber %/% 0.25, sentiment) %>%
  tidyr::pivot_wider(names_from = sentiment, values_from = n, values_fill = 0) %>%
  mutate(sentiment = positive - negative)

# Comparing the three sentiment dictionaries
afinn <- tidy_complaints %>% 
  inner_join(afinn_lexicon, by = c("word" = "word")) %>% 
  group_by(index = linenumber %/% 80) %>% 
  summarise(sentiment = sum(value)) %>% 
  mutate(method = "AFINN")

bing_and_nrc <- bind_rows(
  tidy_complaints %>% 
    inner_join(bing_lexicon, by = c("word" = "word")) %>%
    mutate(method = "Bing et al."),
  tidy_complaints %>% 
    inner_join(nrc_lexicon %>% 
                 filter(sentiment %in% c("positive", "negative")), by = c("word" = "word")) %>%
    mutate(method = "NRC")) %>%
  count(method, index = linenumber %/% 80, sentiment) %>%
  tidyr::pivot_wider(names_from = sentiment,
                     values_from = n,
                     values_fill = 0) %>% 
  mutate(sentiment = positive - negative)

#visualizing the estimate of the net sentiment (positive - negative)
bind_rows(afinn, bing_and_nrc) %>%
  ggplot(aes(index, sentiment, fill = method)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~method, ncol = 1, scales = "free_y")

#  how many positive and negative words are in these lexicons.
#nrc
nrc_lexicon %>%
  filter(sentiment %in% c("positive", "negative")) %>% 
  count(sentiment)

#bing
bing_lexicon %>% 
  count(sentiment)

#To answer the most negative word receiving Products in the company.
bingnegative <- bing_lexicon %>% 
  filter(sentiment == "negative")

wordcounts <- tidy_complaints %>%
  group_by(Company, Product) %>%
  summarize(words = n())

tidy_complaints %>%
  semi_join(bingnegative) %>%
  group_by(Company, Product) %>%
  summarize(negativewords = n()) %>%
  left_join(wordcounts, by = c("Company", "Product")) %>%
  mutate(ratio = negativewords/words) %>%
  filter(Product != 0) %>%
  slice_max(ratio, n = 1) %>% 
  ungroup()

# Word cloud
sentiment_counts <- tidy_complaints %>%
  inner_join(bing_lexicon) %>%
  count(word, sentiment, sort = TRUE) %>%
  tidyr::spread(sentiment, n, fill = 0)

# Create the word cloud with custom settings
comparison.cloud(sentiment_counts,
                 colors = c("orange", "darkgreen"),
                 max.words = 100,
                 random.order = FALSE,   # Disable random word order
                 scale = c(3, 0.5)       # Adjust scaling factor for word sizes
)

# Joining complaint words with sentiment lexicon
word_sentiment <- tidy_complaints %>%
  inner_join(bing_lexicon, by = "word")

# Get the frequency of positive and negative sentiments
positive_words <- word_sentiment %>%
  filter(sentiment == "positive") %>%
  count(word) %>%
  top_n(20, n)

negative_words <- word_sentiment %>%
  filter(sentiment == "negative") %>%
  count(word) %>%
  top_n(20, n)

# Plot positive and negative sentiments separately
ggplot(positive_words, aes(x = reorder(word, n), y = n)) +
  geom_col(fill = "Darkgreen") +
  labs(title = "Top 20 Words with Positive Sentiment",
       x = "Word",
       y = "Frequency") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggplot(negative_words, aes(x = reorder(word, n), y = n)) +
  geom_col(fill = "Orange") +
  labs(title = "Top 20 Words with Negative Sentiment",
       x = "Word",
       y = "Frequency") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
