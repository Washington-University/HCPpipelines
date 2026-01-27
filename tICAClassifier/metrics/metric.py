import numpy as np
from sklearn.metrics import confusion_matrix, roc_auc_score, precision_recall_curve, auc

def get_metrics(TN, FP, FN, TP):
    stat=dict()
    stat['accuracy']=(TN+TP)/(TN+FP+FN+TP)
    f1_score = TP / (TP + 1/2 * (FN + FP) + 1e-8)
    P = TP + FN
    N = FP + TN
    TPR = TP / P
    FPR = FP / N
    TNR = 1 - FPR
    beta=P/N
    weighted_f1_score = (1+beta**2) * TP / ( (1+beta**2)*TP + beta**2 * FN + FP + 1e-8)
    stat['TP'] = int(TP)
    stat['FN'] = int(FN)
    stat['TN'] = int(TN)
    stat['FP'] = int(FP)
    stat['TNR'] = float(TNR)
    stat['TPR'] = float(TPR)
    stat['FPR'] = float(FPR)
    stat['F1 score'] = float(f1_score)
    stat['weighted F1 score'] = float(weighted_f1_score)
    stat['Balanced Accuracy'] = float((TPR+TNR)/2)
    stat['Precision'] = float(TP / (TP + FP + 1e-8))
    stat['(3*TPR+TNR)/4'] = float((3*TPR+TNR)/4)
    stat['(3*TNR+TPR)/4'] = float((3*TNR+TPR)/4)
    return stat

def npv_spec_auc(y_true, y_scores):
    # focus on the classification on noise component
    precision, recall, _ = precision_recall_curve(1-y_true, 1-y_scores)
    npv_specificity_auc=auc(recall, precision)
    return npv_specificity_auc

def pr_auc(y_true, y_scores):
    precision, recall, _ = precision_recall_curve(y_true, y_scores)
    prauc=auc(recall, precision)
    return prauc

class MetricFunc():
    def __init__(self,threshold=0.5):
        self.threshold=threshold
        
    def forward(self, pred_proba, target):
        """
        pred: Tensor of shape (batch_size, num_class) containing predicted logits.
        target: Tensor of shape (batch_size, num_class) containing true labels.
        """
        result={}
        pred_class=pred_proba>=self.threshold
        # Get the true class
        #print(target.shape)
        #print(pred_class.shape)
        cm=confusion_matrix(target, pred_class)
        #print(cm)
        tn, fp, fn, tp = cm.ravel()
        metrics_stat=get_metrics(tn, fp, fn, tp)
        metrics_stat['AUC']=float(roc_auc_score(target, pred_proba))
        metrics_stat['PRAUC']=pr_auc(target, pred_proba)
        metrics_stat['NPV_Spec_AUC']=npv_spec_auc(target, pred_proba)
        return metrics_stat
