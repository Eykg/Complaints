library(dplyr)
library(tidytext)
library(reshape2)
library(stringr)
library(tidyr)
library(ggplot2)

#Sentiments
get_sentiments("afinn")
get_sentiments("nrc")
get_sentiments(df_complaints$text)
get_nrc_sentiments(df_complaints$text)

get_sentiments("bing")

rm(list = ls())

setwd('~/Data-332/Assignment/archive')

# Read the CSV file
df_complaints <- read.csv ("Consumer_Complaints.csv")

# Filter out blank complaints columns
df_complaints <- df_complaints %>%
  filter(Consumer.complaint.narrative != "" & Company.public.response != "")
# Rename the complaint column
df_complaints <- df_complaints %>%
  rename(Complain = Consumer.complaint.narrative)
# Create new table containing Product, Complain, and Company columns
new_table <- df_complaints %>%
  select(Product, Complain, Company)

# Clean the text: remove punctuation, numbers, and extra spaces
mutate(Complain = str_replace_all(Complain, "[[:punct:]]", "") %>%
         str_remove_all("\\d+") %>%
         str_squish()) %>%
  # Tokenize the complaints into individual words after cleaning
  tidy_complaints <- new_table %>%
  unnest_tokens(word, Complain) %>%
  # Remove stop words, unnecessary characters, single characters, and numbers
  anti_join(stop_words, by = "word") %>%
  filter(!grepl("[^[:alnum:][:space:]]", word)) %>%
  filter(nchar(word) > 1) %>%
  filter(!grepl("\\d+", word))
#--------------
tidy_complaints <- new_table %>%
  mutate(Complain = str_replace_all(Complain, "[[:punct:]]", "") %>%
           str_remove_all("\\d+") %>%
           str_squish()) %>%
  unnest_tokens(word, Complain) %>%
  anti_join(stop_words, by = "word") %>%
  filter(!grepl("[^[:alnum:][:space:]]", word)) %>%
  filter(nchar(word) > 1) %>%
  filter(!grepl("\\d+", word))

#--------------

# Load stop words to remove common words
data("stop_words")

# Tokenize the complaints into individual words
tidy_complaints <- new_table %>%
  group_by(Product) %>%
  mutate(linenumber = row_number()) %>%
  ungroup() %>%
  unnest_tokens(word, Complain)

get_sentiments("nrc")

nrc_lexicon <- get_sentiments("nrc")
library(tidytext)

get_sentiments("afinn")
# common joy words in products
nrc_joy <- get_sentiments("nrc") %>%
  filter(sentiment == "joy")

tidy_complaints %>%
  filter(Product == "Credit card") %>%
  inner_join(nrc_joy) %>%
  count(word, sort = TRUE)

#negative and positive sentiment in separate columns
product_sentiment <- tidy_complaints %>%
  inner_join(get_sentiments("bing"), by = "word", relationship = "many-to-many") %>%
  count(Product, index = linenumber %/% 0.25, sentiment) %>%
  pivot_wider(names_from = sentiment, values_from = n, values_fill = 0) %>%
  mutate(sentiment = positive - negative)

ggplot(product_sentiment, aes(index, sentiment, fill = Product)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~Product, ncol = 2, scales = "free_x")

# Comparing the three sentiment dictionaries
afinn <- tidy_complaints %>% 
  inner_join(get_sentiments("afinn"), by = c("word" = "word"), suffix = c("_complaint", "_lexicon"), relationship = "many-to-many") %>% 
  group_by(index = linenumber %/% 80) %>% 
  summarise(sentiment = sum(value)) %>% 
  mutate(method = "AFINN")

bing_and_nrc <- bind_rows(
  tidy_complaints %>% 
    inner_join(get_sentiments("bing"), by = c("word" = "word"), suffix = c("_complaint", "_lexicon"), relationship = "many-to-many") %>%
    mutate(method = "Bing et al."),
  tidy_complaints %>% 
    inner_join(get_sentiments("nrc") %>% 
                 filter(sentiment %in% c("positive", "negative")), by = c("word" = "word"), suffix = c("_complaint", "_lexicon"), relationship = "many-to-many") %>%
    mutate(method = "NRC")) %>%
  count(method, index = linenumber %/% 80, sentiment) %>%
  pivot_wider(names_from = sentiment,
              values_from = n,
              values_fill = 0) %>% 
  mutate(sentiment = positive - negative)
#visualizing the estimate of the net sentiment (positive - negative)
bind_rows(afinn, 
          bing_and_nrc) %>%
  ggplot(aes(index, sentiment, fill = method)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~method, ncol = 1, scales = "free_y")

#  how many positive and negative words are in these lexicons.
#nrc
get_sentiments("nrc") %>% 
  filter(sentiment %in% c("positive", "negative")) %>% 
  count(sentiment)
#bing
get_sentiments("bing") %>% 
  count(sentiment)

#To answer the most negative wod reciveing Products in the company.
bingnegative <- get_sentiments("bing") %>% 
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

#Word cloud
tidy_complaints %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  acast(word ~ sentiment, value.var = "n", fill = 0) %>%
  comparison.cloud(colors = c("orange", "darkgreen"),
                   max.words = 100)
sentiment_counts <- tidy_complaints %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  acast(word ~ sentiment, value.var = "n", fill = 0)

# Create the word cloud with custom settings
comparison.cloud(sentiment_counts,
                 colors = c("orange", "darkgreen"),
                 max.words = 100,
                 random.order = FALSE,   # Disable random word order
                 scale = c(3, 0.5)       # Adjust scaling factor for word sizes
)

# Joining complaint words with sentiment lexicon
word_sentiment <- tidy_complaints %>%
  inner_join(get_sentiments("bing"), by = "word", relationship = "many-to-many")

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
