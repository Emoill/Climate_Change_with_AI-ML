





# https://huggingface.co/datasets/lambada

import pandas as pd
from datasets import load_dataset

dataset = pd.DataFrame(load_dataset("lambada")['validation']['text'], columns=['text'])

dataset[['input', 'target']] = dataset['text'].str.rsplit(pat=' ', n=1, expand=True)


for i in range(len(dataset)):
	dataset.iloc[i]['input']

score = [0, 0]

'bepis' in ['chees', 'eb', 'bpis', 'efas']


#Importing tqdm function of tqdm module
from tqdm import tqdm
from time import sleep
for i in tqdm(range(200)):
	# Waiting for 0.01 sec before next execution
	sleep(.01)

'''

import torch
test = torch.hub.load('facebook/opt-125m' 'custom', path='EX1/llm-part/model2', force_reload=True, model='opt-125m')


model = torch.load('model2/config.json')

import json

obj = json.load(open('model2/config.json', 'r'))


'''


from transformers import AutoModelForCausalLM, AutoTokenizer, pipeline

pipe = pipeline(
	task = "text-generation",
	model = AutoModelForCausalLM.from_pretrained('model2'), # loaded from directory
	tokenizer = AutoTokenizer.from_pretrained('facebook/opt-125m') # re-use from original model
)
pipe.predict('today i want to go to the')[0]['generated_text']




input_text = "today i will go to a"


from transformers import AutoModelForCausalLM, AutoTokenizer, GPTQConfig, pipeline
tokenizer = AutoTokenizer.from_pretrained(model_id)

input_ids = tokenizer('filling in the missing word indicated by <blank>.\n' + input_text + ' <blank>', return_tensors="pt").input_ids
outputs = model.generate(
	tokenizer(input_text, return_tensors="pt").input_ids
)
print(tokenizer.decode(outputs[0]))

























from transformers import T5Tokenizer, T5ForConditionalGeneration

tokenizer = T5Tokenizer.from_pretrained("google/flan-t5-small")
model = T5ForConditionalGeneration.from_pretrained("google/flan-t5-small")

input_text = "translate English to German: How old are you?"
input_ids = tokenizer(input_text, return_tensors="pt").input_ids

outputs = model.generate(input_ids)
print(tokenizer.decode(outputs[0]))

#%%
