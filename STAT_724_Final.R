
library("leaps")
library("nnet")
library("e1071")
library("gbm")
library("randomForest")
library("tree")
library("class")
library("MASS")

wine.data0 <- read.csv("~/Desktop/winequality.csv")
sum(is.na(wine.data0)) # Check for NAs
summary(wine.data0)
dim(wine.data0) # Check dimensions of the dataset

# We Create the qualitative response with three classes.

wine.quality <- ifelse(wine.data0$quality < 7, ifelse(wine.data0$quality <5,"Bad","Average"),"good")
#wine.quality[1:15]
wine.data1 <- data.frame(wine.data0, wine.quality)
wine.data <- wine.data1[,-12] # Exclude the old quantitative response. 

# Take a random 80% of the data for train and the rest for test. 
set.seed(1)
train <- sample(1:nrow(wine.data), round(0.80*nrow(wine.data)), replace = F )
train.set <- wine.data[train,]
test.set <- wine.data[-train,]

#########################################################################

# Perform a PCA and look at the aggregate weights to look for suggestions for feature selection and exploratory analysis. 

# Look for the mean and variance of the variables to see if scaling is needed. 
apply(wine.data0[,-12],2,mean)
apply(wine.data0[,-12],2,var)

# The means and specially variances are significantly different, so we should scale the data.

pca <- prcomp(wine.data0, scale = TRUE)

aggregate.weights <- apply(pca$rotation, 1, sum) # Aggregate the weights. 
ordered.weights <- order(abs(aggregate.weights), decreasing = T) # Impose a decreasing order. 
ordered.weights
aggregate.weights[ordered.weights][1:3]

# The PCA analysis tells us that alcohol is significantly more important than the other variables. As we shall see later, in
# many of the models, the most statistically significant predictor is alcohol. We plot the poportions of response levels against
# this variable. 

plot(wine.data$wine.quality, wine.data$alcohol)

# The plot shows that on average the "good" quality is associated with higher amounts of alcohol. However, the "Bad" quality 
# and "Average" both have similar values, this can potentialy cause the model to falsely classify the bad ones as average, given
# that alcohol is by far the most influential variable, and the number of "Bad" observations is small. 

###########################################################################

# We First fit a multinomial logistic regression with all the variables included.

mult.logist <- multinom(wine.quality ~ ., data = train.set) # Fit the logistic regression. 
summary(mult.logist)

# The residual deviance is quite high, Standard errors are low, but the coefficient for alcohol is not very large. 

# Test the model
mult.preds <- predict(mult.logist, newdata = test.set) 
xtabs(~ mult.preds + test.set$wine.quality) # Compute the confusion matrix. 

# The model does not identify any "bad" quality observations.  

logist.correct.rate <- mean(mult.preds == test.set$wine.quality) # Compute the correct test classification rate.
test.error.rate <- mean(mult.preds != test.set$wine.quality) # Compute the test error. 
logist.correct.rate
test.error.rate  
# test error is at about 0.22, not very bad. 

#######################################################################

# We now use the Best Subset Selection method to see if we can get a reduced set of predictors.

# Perform best subset selection and include all the variables.  

best.subsets <- regsubsets(wine.quality ~., data = train.set, nvmax = 11) 
summary(best.subsets)
plot(best.subsets) # Plot the result.

# The best subset selection method suggests that the model with 6 variables has the lowest BIC. The five excluded variables 
# are "volatile acidity", "chloride", "citric acid", "free sulfur dioxide", and "total sulfur dioxide". We fit this reduced 
# model using logistic regression again and look at the test error rate. 

reduced.logist <- multinom(wine.quality ~ .-volatile.acidity - 
                             chlorides - citric.acid - free.sulfur.dioxide - 
                             total.sulfur.dioxide, 
                           data = train.set) 
summary(reduced.logist)


reduced.preds <- predict(reduced.logist, newdata = test.set)
xtabs(~ reduced.preds + test.set$wine.quality)

logist.err.rate2 <- mean(reduced.preds != test.set$wine.quality) # Compute the test error. 
logist.err.rate2
# The reduced model has a slightly smaller test error rate, although it has higher deviance.  

c(deviance(reduced.logist), deviance(mult.logist)) # COmpare the deviances

# We perform a variable selection using the hybrid stepwise selection method as our last feature selection attempt. 
logist.best.mod <- step(mult.logist, trace = F, direction = "both")
summary(logist.best.mod)

# The stepwise selection method suggests that the model that includes all of the variables has the lowest AIC. 

# We proceed with keeping all of the variables, and in some cases perform stepwise selection methods again for that particular model. 

##########################################################################

# Since the response classes have a natural order, as did the original quantitative response, we try fitting some ordinal multinomial 
# models and see if it outperforms the regular fit. 

# We begin with a proportional odds model that includes all of the variables. 
prop.mod <- polr(wine.quality ~ .,
                 data = train.set) 

c(deviance(mult.logist), mult.logist$edf)
c(deviance(prop.mod), prop.mod$edf)
# We see that the proportional odds model uses fewer variables but has higher deviance than the logit model. 

# Get the test error rate
prop.preds <- predict(prop.mod, newdata = test.set)
xtabs(~ prop.preds + test.set$wine.quality)

prop.err.rate <- mean(prop.preds != test.set$wine.quality)
prop.err.rate
# The test error is similar to the logit models.

# Perform variable selection on the proportional odds model. 
reduced.prop <- step(prop.mod, trace = F)
summary(reduced.prop)

# The best model chosen excludes two of the variables: "free sulfur dioxide" and "citric acid".

# Get the test error for this model. 
reduced.prop.preds <- predict(reduced.prop, newdata = test.set)
xtabs(~ reduced.prop.preds + test.set$wine.quality)

prop.err.rate2 <- mean(reduced.preds != test.set$wine.quality) # Compute the test error. 
prop.err.rate2 
# Test error for the reduced model is similar to the original model, very slightly lower. 

#########################################################################

# We fit a Probit model.
probit.mod <- polr(wine.quality ~., method = "probit", data = train.set)
summary(probit.mod)
reduced.probit <- step(probit.mod, trace = 0) # Perform stepwise selection.
summary(reduced.probit)
# Three variables are excluded in the best model chosen by stepwise selection. 

reduced.probit.preds <- predict(reduced.probit, newdata = test.set)
table(reduced.probit.preds, test.set$wine.quality)
reduced.probit.preds <- predict(reduced.probit, newdata = test.set)

red.prob.tst.err <- mean(reduced.probit.preds != test.set$wine.quality)
red.prob.tst.err 

# Similar to previous models, slightly higher than the redoced proportional odds model. 

###########################################################################

# Fit LDA models. 
# No interactions between the variables.
lda.fit <- lda(wine.quality ~ ., data = train.set)
lda.fit.preds <- predict(lda.fit, newdata = test.set)
lda.fit.class <- lda.fit.preds$class
table(lda.fit.class, test.set$wine.quality)
lda.test.error <- mean(lda.fit.class != test.set$wine.quality)
lda.test.error
# Close to logistic error rate as expected, but it does correctly classify one observation as Bad, none of the previousmodels did.

#######################################

# Including all 2-way interactions
lda.fit.1 <- lda(wine.quality ~ .^2, data = train.set)
lda.fit.preds.1 <- predict(lda.fit.1, newdata = test.set)
lda.fit.class.1 <- lda.fit.preds.1$class
table(lda.fit.class.1, test.set$wine.quality)

lds.test.error1 <- mean(lda.fit.class.1 != test.set$wine.quality)
lds.test.error1 

# We observe that the model has improved in two ways: The test error rate is reduced slightly, and there are now 8 correct classifications 
# for the Bad quality, comparing to only 1 in the model that did not include the interactions.  

###########################################################################

# Fit a QDA while including all of the variables.
qda.fit <- qda(wine.quality ~ ., data = train.set)

qda.fit.class <- predict(qda.fit, newdata = test.set)$class
table(qda.fit.class, test.set$wine.quality) # Build the confusion matrix.
# Get the test error
qda.test.error <- mean(qda.fit.class != test.set$wine.quality)
qda.test.error 

# The error is higher than all of the previous models! So a quadratic decision boundary does not fit the data. 

##########################################################################

# Fit KNNs


# Create the input matrices
train.X <- train.set[,-12]
train.Y <- train.set[,12]
test.X <- test.set[,-12]

# Fit a KNN with K = 1. 
knn.fit.preds <- knn(train.X, test.X, train.Y , k=1)

table(knn.fit.preds, test.set$wine.quality)

test.error.knn.1 <- mean(knn.fit.preds != test.set$wine.quality) 
test.error.knn.1

# The test error is similar to the previous models at around 0.22. However, there are 8 correct and 8 incorrect classifications of the BAD observation.

# Increase K to 5. 
knn.fit.preds.3 <- knn(train.X, test.X, train.Y , k=3)

table(knn.fit.preds.3, test.set$wine.quality)

test.error.knn.3 <- mean(knn.fit.preds.3 != test.set$wine.quality) 
test.error.knn.3 

# k = 1 gives the best result, still outperformed by the parametric methods. 

##############################################################################

# Fit some Trees

tree.fit <- tree(wine.quality ~., train.set)
summary(tree.fit)
# This tree has 5 nodes, with alcohol being the most significant predictor, followed by volatile acidity and citric acid. 

plot(tree.fit)
text(tree.fit, pretty=0)

tree.preds <- predict(tree.fit, newdata = test.set, type = "class")
table(tree.preds, test.set$wine.quality)
test.error.tree <- mean(tree.preds != test.set$wine.quality)
test.error.tree 
## The misclassification error rate on the test set is close to that of the previous models. 

#############################################

# Perform cross validation for tree size. 
tree.cv <- cv.tree(tree.fit, FUN = prune.misclass)
tree.cv
# The trees with 3 and 5 nodes have the same error rate(deviance)

# We prune to the simpler 3-node tree which has the same error rate. 
pruned.tree <- prune.misclass(tree.fit, best = 3)

plot(pruned.tree)
text(pruned.tree, pretty=0)

# Get the test error
pruned.tree.preds <- predict(pruned.tree, newdata = test.set, type = "class")
table(pruned.tree.preds, test.set$wine.quality) # Confusion matrix

pruned.test.error <- mean(pruned.tree.preds != test.set$wine.quality)
pruned.test.error 
# Same test error, but the tree is more interpretable.

############################################################################

# Perform Bagging

set.seed(2)
bagged.tree <- randomForest(wine.quality ~ ., data = train.set, mtry=11, importance = TRUE )
bagged.tree
bagged.tree.preds <- predict(bagged.tree, newdata = test.set, type = "class")
table(bagged.tree.preds, test.set$wine.quality)
test.error.bagged <- mean(bagged.tree.preds != test.set$wine.quality)
test.error.bagged
# We see that bagging has signiifcantly improved the test error rate, at about 0.14. 
# Changing the number of trees did not improve the fit. 

#############################################################################

# Perform Random Forests with mtry = 4. 
set.seed(2)
r.forest <- randomForest(wine.quality ~ ., mtry=4, data = train.set, importance = TRUE )
r.forest
#importance(r.forest)
r.forest.preds <- predict(r.forest, newdata = test.set, type = "class")
table(r.forest.preds, test.set$wine.quality)
test.error.forest <- mean(r.forest.preds != test.set$wine.quality)
test.error.forest
# The test error is improved to 0.13, with 3 correct classifications of Bad quality. 

##################################################################################

# Perform Boosting

set.seed(2)
boost.fit <- gbm(wine.quality ~., data = train.set,distribution = "multinomial", n.trees = 100, interaction.depth = 3, shrinkage = 0.005)
summary(boost.fit, order=T)
# We see that the relative influence of alcohol is by far higher than the other ones. 

boost.fit.probs <- predict(boost.fit, newdata = test.set, n.trees = 100, type = "response")
boost.fit.preds.0 <- apply(boost.fit.probs, 1, which.max)
boost.fit.preds <- colnames(boost.fit.probs)[boost.fit.preds.0]
table(boost.fit.preds, test.set$wine.quality)
test.error.boost <- mean(boost.fit.preds != test.set$wine.quality)
test.error.boost 
# Test error is comparable to the earlier models, at around 0.21. The bagging and random forest methods outperformed this model.

#####################################################################################

# Fit SVC and SVMs.


# We now fit a Support Vecgtor Machine using the polynomial kernel, with the degree of the polynomial and the cost determined by croos-validation. 

# Use cross validation to determine optimal values for cost and the polynomial degree. 
svm.mod1.tuning <- tune(svm, wine.quality~., data = train.set, kernel = "polynomial",
                       ranges = list(cost = c(0.01, 0.1, 1, 100), degree = c(2,3,4)))
svm.mod1.tuning$best.parameters
svm.mod.pol <- svm.mod1.tuning$best.model

# We do not run the cross-validation results here because it takes a fairly long time when knitting the pdf. 
# The optimal model suggested had cost = 100 and degree = 4. We fit a SVM with these parameters.

svm.mod.pol <- svm(wine.quality ~., data=train.set, kernel="polynomial", degree=4, cost =100)
#summary(svm.mod.pol)

svm.pol.preds <- predict(svm.mod.pol, newdata = test.set)
table(svm.pol.preds, test.set$wine.quality)

svm.pol.test.err <- mean(svm.pol.preds != test.set$wine.quality)
svm.pol.test.err
# The error is is at around 0.20, slightly lower than the earlier models, but still not comparable with the bagged and random forest models. It also 
# correctly classifies 10 observations as "Bad".

#########################################

# Repeat for radial kernel.

# Cross-validate the gamma and cost parameters.

svm.mod2.tuning <- tune(svm, wine.quality~., data = train.set, kernel = "radial",
                       ranges = list(cost = c(0.01,0.1,1,10,100), gamma = c(0.5,1,2,3,4)))
svm.mod2.tuning$best.parameters

# The optimal model suggested had cost = 100 and gamma = 3. We fit a SVM with these parameters.

svm.mod.radi <- svm.mod2.tuning$best.model
svm.mod.radi <- svm(wine.quality ~., data=train.set, kernel="radial", gamma=3, cost =100)
summary(svm.mod.radi)
# The number of support vectors is quite high, at 4353, compared to the train set size which is 5198. 

svm.radi.preds <- predict(svm.mod.radi, newdata = test.set, decision.values = TRUE)
table(svm.radi.preds, test.set$wine.quality)

svm.radi.test.err <- mean(svm.radi.preds != test.set$wine.quality)
svm.radi.test.err

# We see a significant improvement on the test error, close to that of obtained by the bagging trees method, and it correctly classifies 5 Bad quality observations. 

##########################################################################################

# Four plots for the radial svm. 

# Compare the test error of all models in a plot. 

# Where there were variations on a certain model, such as with different values for the parameters, the lowest test error among the original and variation 
# models are considered for this plot. 

errors <- c(test.error.rate,  prop.err.rate2, red.prob.tst.err, 
            lda.test.error, qda.test.error, test.error.knn.1, 
            pruned.test.error, test.error.bagged, test.error.forest, 
            test.error.boost, svm.radi.test.err, svm.pol.test.err)


names(errors) <- c("Logist", "Propprods", "Probit", "LDA", "QDA", 
                   "KNN", "Tree", "Bagged", "rForest", "Boosted", 
                   "SVMradial", "SVMpoly")

par(mfrow=c(1,1))
barplot(errors, names.arg =  c("Logist", "Propprods", "Probit", "LDA", "QDA", 
                               "KNN", "Tree", "Bagged", "rForest", "Boosted", 
                               "SVMradial", "SVMpoly"),col="navy" , ylab="Test Classification Error Rate", las=2)

title(xlab="Test Error Names", line=4.6, cex.lab=1.2)



# The random forest model has the lowest test classification error rate, it also correctly classifies three observations as "Bad". 
# The next lowest test error rate is for the bagged trees model, it correctly classifies 4 observations as "Bad". The third lowest 
# rate is for the SVM model using a radial kernel. This model correctly classified 5 observations as "Bad"




