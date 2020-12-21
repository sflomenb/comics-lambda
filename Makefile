ACCOUNT := 325586671899
IMAGE_NAME := comics-lambda
REPO_NAME := comics-repo
TAG := latest

tag-and-push: comics.py Dockerfile
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(ACCOUNT).dkr.ecr.us-east-1.amazonaws.com
	docker tag	$(IMAGE_NAME):$(TAG) $(ACCOUNT).dkr.ecr.us-east-1.amazonaws.com/$(REPO_NAME):$(TAG)
	docker push $(ACCOUNT).dkr.ecr.us-east-1.amazonaws.com/$(REPO_NAME):$(TAG)
	touch $@
