tag-and-push: comics.py Dockerfile
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 325586671899.dkr.ecr.us-east-1.amazonaws.com
	docker tag	comics-lambda:latest 325586671899.dkr.ecr.us-east-1.amazonaws.com/comics-repo:latest
	docker push 325586671899.dkr.ecr.us-east-1.amazonaws.com/comics-repo:latest
	touch $@
