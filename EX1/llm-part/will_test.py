# https://huggingface.co/docs/transformers/main_classes/quantization

from awq import AutoAWQForCausalLM
from transformers import AutoTokenizer

model_path = "mhemetfaik/flan-t5-large-copy"
quant_path = '4test'

#quant_config = {"zero_point": True, "q_group_size": 128, "w_bit": 4, "version":"GEMM"}
quant_config = {"w_bit": 4}

# Load model
model = AutoAWQForCausalLM.from_pretrained(model_path)
tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)

# Quantize
model.quantize(tokenizer, quant_config=quant_config)



from transformers import AwqConfig, AutoConfig
from huggingface_hub import HfApi

# modify the config file so that it is compatible with transformers integration
quantization_config = AwqConfig(
	bits = quant_config["w_bit"],
).to_dict()

# the pretrained transformers model is stored in the model attribute + we need to pass a dict
model.model.config.quantization_config = quantization_config
# a second solution would be to use Autoconfig and push to hub (what we do at llm-awq)


# save model weights
model.save_quantized(quant_path)
tokenizer.save_pretrained(quant_path)































# https://huggingface.co/datasets/lambada

import pandas as pd
from datasets import load_dataset

dataset = pd.DataFrame(load_dataset("lambada")['validation']['text'], columns=['text'])

dataset[['input', 'target']] = dataset['text'].str.rsplit(pat=' ', n=1, expand=True)
