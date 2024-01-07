from sklearn.model_selection import train_test_split
import pandas as pd

seed = 42


def get_test_table(scaled: bool = False, train_size: int = .7):
	"""
	returns a train & test set from the temporary table located in /data_temp
	:param scaled: whether to use the scaled or unscaled table
	:param train_size: proportion of the data to use for training
	:return: X_train, X_test, y_train, y_test
	"""
	if scaled:
		file = 'data_temp/gauge24scaled.csv'
	else:
		file = 'data_temp/gauge24.csv'

	df = pd.read_csv(file).drop('Unnamed: 0', axis=1)
	df['date'] = pd.to_datetime(df['date'])

	response = 'prec'
	X = df.drop([response], axis=1)
	y = df[response]

	split_point = int(len(df) * train_size)

	return (
		X.iloc[:split_point],
		X.iloc[split_point:],
		y.iloc[:split_point],
		y.iloc[split_point:]
	)
