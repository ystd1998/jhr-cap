rm(list=ls())
data_path<-paste(getwd(),"/data/en_US", sep="")
setwd(data_path)
#package I use to do this project：
library(ggplot2)
library(NLP) # for natural language processing
library(stringr) # package for handling string in R
library(R.utils) # ultils to count lines
library(SnowballC) # for steming words.
library(RWeka) #for n-gram model
library(ngram) # for n-grams model
library(qdap) # count word
library(stringi) # use to count lines fast 
library(pryr) # to see file size with command object_size
library(wordcloud) # for visualization 

library(RWeka)
library(data.table)
library(dplyr)


#read in the data and read several lines of data:
con_twitts<- file("en_US.twitter.txt",open="rb") 
con_news<- file("en_US.news.txt", open="rb") 
con_blogs<- file("en_US.blogs.txt", open="rb")

twitts<-readLines(con_twitts,encoding="UTF-8",warn=FALSE)
news<-readLines(con_news,encoding="UTF-8")
blogs<-readLines(con_blogs,encoding="UTF-8")
#close connection: 
close(con_twitts)
close(con_news)
close(con_blogs)
set.seed(1233)
ran_twitts<-sample(twitts, 2000, replace=FALSE)
ran_news<-sample(news, 2000, replace=FALSE)
ran_blogs<-sample(blogs, 2000, replace=FALSE)
#all is the combined data by twitts_part news_part and blogs_part.
all<-paste(ran_twitts, ran_news, ran_blogs, sep=" ")
#all <- sent_detect(all, language = "en", model = NULL) #splitting of text paragraphs into sentences
#count how many words in data: 
#stri_stats_general(all) #it should be 2000.

#sum(sapply(gregexpr("\\W+", all), length))

library(tm)
#tokenization function: 
#create corpus 
my_corp<-VCorpus(VectorSource(all),readerControl=list(language="lat"))
#write corpus on hard drive: 
#writeCorpus(my_corp)
#find more about meta data: 
#inspect(my_corp[1:2])
#do transformation on corpus I made:

# remove URLs
toSpace <- content_transformer(function(x, pattern) gsub(pattern, " ", x))
my_corp <- tm_map(my_corp, toSpace, "(f|ht)tp(s?)://(.*)[.][a-z]+")

# remove RTs and vias (mostly from tweets)
toSpace <- content_transformer(function(x, pattern) gsub(pattern, " ", x))
my_corp <- tm_map(my_corp, toSpace, "RT |via ")


# replace twitter accounts (@diegopozu) by space
toSpace <- content_transformer(function(x, pattern) gsub(pattern, " ", x))
my_corp <- tm_map(my_corp, toSpace, "@[^\\s]+")

# to lower case
my_corp <- tm_map(my_corp, content_transformer(tolower))


# common text cleaning steps
getTransformations()

# remove stopwords
my_corp <- tm_map(my_corp, removeWords, stopwords("english"))

# remove numbers, punctuation, whitespace
my_corp <- tm_map(my_corp, removeNumbers)
my_corp<-tm_map(my_corp, content_transformer(removePunctuation))
my_corp<-tm_map(my_corp, stripWhitespace)

my_corp<-tm_map(my_corp, stemDocument)


#remove profanity words: (I will upload profanity words in my github)
profane_path<-paste(getwd(), "/bad-words",sep="")
my_corp<-tm_map(my_corp, removeWords, profane_path)
# corp_dtm<- DocumentTermMatrix(my_corp, control=list(wordLengths=c(1,Inf)))
#n gram : 

gc()
options(mc.cores=1)

UnigramTokenizer<-function(x) NGramTokenizer(x, Weka_control(min = 1, max = 1))
BigramTokenizer<-function(x) NGramTokenizer(x, Weka_control(min = 2, max = 2))
TrigramTokenizer<-function(x) NGramTokenizer(x, Weka_control(min = 3, max = 3))
QuadgramTokenizer<-function(x) NGramTokenizer(x, Weka_control(min = 4, max = 4))
tdm_unigram<-TermDocumentMatrix(my_corp, control = list(tokenize = UnigramTokenizer))
tdm_bigram<-TermDocumentMatrix(my_corp, control = list(tokenize = BigramTokenizer))
tdm_trigram<-TermDocumentMatrix(my_corp, control = list(tokenize = TrigramTokenizer))
tdm_quagram<-TermDocumentMatrix(my_corp, control = list(tokenize = QuadgramTokenizer))
#convert to matrix 
#mat_2gram<-as.matrix(tdm_bigram)
#head(sort(rowSums(mat_2gram),decreasing=TRUE),20)
#mat_3gram<-as.matrix(tdm_trigram)
#head(sort(rowSums(mat_3gram),decreasing=TRUE),20)

#function to transform data frame to final data frame for further prediction: 
df_ngram<-function (tdm) {
        df_ngram<-as.data.frame(inspect(tdm))
        df_ngram$count<-rowSums(df_ngram)
        df_ngram<-subset(df_ngram, count> 1)
        df_ngram$terms<-row.names(df_ngram)
        df_ngram<-df_ngram[order(-df_ngram$count),]
        row.names(df_ngram)<-NULL
        df_ngram$probability<-df_ngram$count/sum(df_ngram$count)
        df_ngram_final<-subset(df_ngram, select=c("terms","count","probability"))
        df_ngram_final
        
}

#return data frame of each tdm gram.

#df_unigram<-df_ngram(tdm_unigram)
#df_bigram<-df_ngram(tdm_bigram)
#df_trigram<-df_ngram(tdm_trigram)
#df_quagram<-df_ngram(tdm_quagram)

freqTerms1 <- findFreqTerms(tdm_unigram, lowfreq = 5)
termFreq1 <- rowSums(as.matrix(tdm_unigram[freqTerms1,]))
termFreq1 <- data.frame(unigram=names(termFreq1), frequency=termFreq1)
termFreq1 <- termFreq1[order(-termFreq1$frequency),]
unigramlist <- setDT(termFreq1)
save(unigramlist,file="unigram.Rda")

freqTerms2 <- findFreqTerms(tdm_bigram, lowfreq = 3)
termFreq2 <- rowSums(as.matrix(tdm_bigram[freqTerms2,]))
termFreq2 <- data.frame(bigram=names(termFreq2), frequency=termFreq2)
termFreq2 <- termFreq2[order(-termFreq2$frequency),]
bigramlist <- setDT(termFreq2)
save(bigramlist,file="bigram.Rda")


freqTerms3 <- findFreqTerms(tdm_trigram, lowfreq = 2)
termFreq3 <- rowSums(as.matrix(tdm_trigram[freqTerms3,]))
termFreq3 <- data.frame(trigram=names(termFreq3), frequency=termFreq3)
trigramlist <- setDT(termFreq3)
save(trigramlist,file="trigram.Rda")


freqTerms4 <- findFreqTerms(tdm_quagram, lowfreq = 1)
termFreq4 <- rowSums(as.matrix(tdm_quagram[freqTerms4,]))
termFreq4 <- data.frame(fourgram=names(termFreq4), frequency=termFreq4)
fourgramlist <- setDT(termFreq4)
save(fourgramlist,file="fourgram.Rda")
