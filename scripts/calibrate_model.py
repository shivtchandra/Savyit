
import json
import os
from lib.services.inhouse_model_weights import InhouseModelWeights

def calibrate():
    data_path = 'data/kaggle_indian_bank_sms_dataset.jsonl'
    
    fin_scores = []
    others_scores = []
    
    with open(data_path, 'r') as f:
        for line in f:
            row = json.loads(line)
            score = InhouseModelWeights.score(row['raw_sms'])
            if row['is_financial_transaction'] == 1:
                fin_scores.append(score)
            else:
                others_scores.append(score)
    
    print(f"Financial: min={min(fin_scores):.2f}, max={max(fin_scores):.2f}, avg={sum(fin_scores)/len(fin_scores):.2f}")
    if others_scores:
        print(f"Others: min={min(others_scores):.2f}, max={max(others_scores):.2f}, avg={sum(others_scores)/len(others_scores):.2f}")
    else:
        print("No non-financial rows found in dataset analysis.")

if __name__ == "__main__":
    calibrate()
