'''
https://cocodataset.org/#format-results

For detection with bounding boxes, please use the following format:
[{
	"image_id" : int,
	"category_id" : int,
	"bbox" : [x,y,width,height],
	"score" : float,
}]
'''

from EX1 import funcs

model_path = 'model8.tflite'
test_image_path = 'test1.jpg'

boxes, classes, scores = (
	funcs.test_model(model_path, test_image_path, render=False, get_detection=True))

results = []

for box, clas, score in zip(boxes, classes, scores):
	results.append(
		{
			'image_id': 0,
			'category_id': clas,
			'bbox': box,
			'score': score
		}
	)

import json

with open('results.json', 'w') as json_file:
	json.dump(str(results), json_file)
