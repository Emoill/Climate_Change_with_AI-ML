from sklearn.model_selection import train_test_split
import pandas as pd

seed = 42

def get_test_table(scaled=False):
    if scaled:
        file = 'data_temp/gauge24scaled.csv'
    else:
        file = 'data_temp/gauge24.csv'

    df = pd.read_csv(file)

    df = df.sort_values('date_column')

    response = 'prec'
    X = df.drop([response], axis=1)
    y = df[response]

    split_point = int(len(df) * 0.7)
    
    X_train = X.iloc[:split_point]
    y_train = y.iloc[:split_point]
    X_test = X.iloc[split_point:]
    y_test = y.iloc[split_point:]

    return X_train, X_test, y_train, y_test
