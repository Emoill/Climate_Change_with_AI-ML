from sklearn.model_selection import train_test_split
import pandas as pd

seed = 42

def get_test_table(scaled=False):
	if scaled:
		file = 'data_temp/gauge24scaled.csv'
	else:
		file = 'data_temp/gauge24.csv'



	df = pd.read_csv(file)

	response = 'prec'

	X = df.drop([response], axis=1)
	y = df[response]

	X_train, X_test, y_train, y_test = train_test_split(X, y, random_state=seed)

	return X_train, X_test, y_train, y_test
