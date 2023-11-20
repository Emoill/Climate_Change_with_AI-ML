





# https://huggingface.co/datasets/lambada

import pandas as pd
from datasets import load_dataset

dataset = pd.DataFrame(load_dataset("lambada")['validation']['text'], columns=['text'])

dataset[['input', 'target']] = dataset['text'].str.rsplit(pat=' ', n=1, expand=True)




import torch
test = torch.hub.load('facebook/opt-125m' 'custom', path='EX1/llm-part/model2', force_reload=True, model='opt-125m')


model = torch.load('model2/config.json')

import json

obj = json.load(open('model2/config.json', 'r'))



from transformers import AutoModelForCausalLM
test = AutoModelForCausalLM.from_pretrained('model2')

