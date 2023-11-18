





# https://huggingface.co/datasets/lambada

import pandas as pd
from datasets import load_dataset

dataset = pd.DataFrame(load_dataset("lambada")['validation']['text'], columns=['text'])

dataset[['input', 'target']] = dataset['text'].str.rsplit(pat=' ', n=1, expand=True)

#%%
