dataFilePath = strcat(pwd,'/DATA.TXT');
[fileLocationTrain,fileLocationTest,C] = readDataFile (dataFilePath);

%IF WISHES TO MANUALLY ENTRING DATA
%C = 0.0001;
%fileNameTrain = 'citeseer.train.ltc.svm';
%fileNameTest = 'citeseer.test.ltc.svm';
%dir = 'Users/daniel/Documents/MATLAB/+SearchEnginesHW5/+Data/';
%fileLocationTrain = strcat(dir,fileNameTrain);
%fileLocationTest = strcat(dir,fileNameTest);


tic;


%Import database
% fprintf('loading training data...\n');
% [Xtrain,Ytrain,QueryIdTrain] = readLabeledSparseMatrix (fileLocationTrain);
% fprintf('loading testing data...\n');
% [Xtest,Ytest,QueryIdTest] = readLabeledSparseMatrix (fileLocationTest);
% fprintf('data loaded\n\n');
load('train.mat');
Xtrain = data.X;
Ytrain = data.Y;
QueryIdTrain = data.QueryId;
load('test.mat');
Xtest = data.X;
Ytest = data.Y;
clearvars 'data';


%Add custom parameters
%Xtrain(:,size(Xtrain,2)+1) = sqrt(Xtrain(:,43).*Xtrain(:,2));
%Xtest(:,size(Xtest,2)+1) = sqrt(Xtest(:,43).*Xtest(:,2)); 


%Pairwise training
[Xv,Qid] = buildPairwiseTraingSet (Xtrain,Ytrain,QueryIdTrain);
totalRowsV = size(Xv,1);
Xtrain = [Xv;-Xv];
Ytrain = [ones(totalRowsV,1);-ones(totalRowsV,1)];

%Normalize rows
numRowsTrain = size(Xtrain,1);
numRowsTest = size(Xtest,1);
Xtrain = spdiags(1./sum(Xtrain,2),0,numRowsTrain,numRowsTrain)*Xtrain;
Xtest = spdiags(1./sum(Xtest,2),0,numRowsTest,numRowsTest)*Xtest;

%average row value
%avgValue = sum(Xtrain(Xtrain>0)) /  size(Xtrain(Xtrain>0),1);

%Add column of 1's to data
%Xtrain = [avgValue*(ones(size(Xtrain,1),1)) Xtrain];
%Xtest = [avgValue*(ones(size(Xtest,1),1)) Xtest];

%Model parameters
alpha = 0.00000001;
convPrecision = 0.001;
maxT = 100;
adaptativeLearningRate = 0.95;
FV_dimension = size(Xtrain,2);

%TRAINING
w = zeros(1, FV_dimension);
lastValue = 0;
convValue = convPrecision + 1;
currentAlpha = alpha;
T = 0;
while T < maxT && convValue > convPrecision

    T = T + 1;

    %shuffle data for stochastic descent algorithm
    randIndex = randperm(size(Xtrain,1));
    shuffledXtrain = Xtrain(randIndex,:);
    shuffledYtrain = Ytrain(randIndex);

    %stochastic gradient descent
    for i=1:size(shuffledXtrain,1)

        currentX = shuffledXtrain(i,:);
        currentY = shuffledYtrain(i);

        p = 1 / (1 + exp(-dot(currentX,w)) );
        w = w + currentAlpha*( (currentY - p)*currentX - C*w ); 

    end 

    %compute loss funcion and decide if is close enough to max/min
    %point. (Check how much loss function changed)
    P = 1 + exp(-Xtrain*w');
    P = bsxfun(@rdivide,1,P);

    LossFunction = bsxfun(@times,Ytrain,log(P)) + bsxfun(@times,(1-Ytrain),log(1-P));
    LossFunction = sum(LossFunction);

    currentValue = LossFunction - 0.5*C*sum(dot(w,w));

    convValue = abs(lastValue - currentValue);
    lastValue = currentValue;

    fprintf('T=%i (alpha=%.9f): %f %f \n', T, currentAlpha, convValue, currentValue);

    %Adaptative Learning
    %learning rate decreases with time: the closer we are to
    %the global max/min, the lower we want the learning rate to be
    if T > 0
       currentAlpha = currentAlpha * adaptativeLearningRate;
    end

end

%OUTPUTING MODEL
predictions = 1 + exp(-Xtest*w');
predictions = bsxfun(@rdivide,1,predictions);

predictionFileName = ['predLR_C', num2str(C) ,'_alpha', num2str(alpha) ,'_T', num2str(maxT),'.txt'];

fileID = fopen(predictionFileName,'w');

fprintf(fileID,'%f %i\n',[predictions'; Ytest']);

fclose(fileID);

%RUN EVALUATION SCRIPT

evalOutputFileName = ['evalLR_C', num2str(C) ,'_alpha', num2str(alpha) ,'_T', num2str(maxT),'.txt'];

terminalCommand = ['perl Eval-Score.pl ' fileLocationTest ' ' predictionFileName ' ' evalOutputFileName ' 0'];

[status,cmdout] = system(terminalCommand);

toc

