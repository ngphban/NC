SF Food Trucks
===

> San Francisco's finger-licking street food now at your fingertips.

#### Docker

There are two different ways of getting the app up and running with Docker. 

##### Docker Network
```
$ ./setup-docker.sh
```

##### Docker Compose
```
$ docker-compose up
```

The app can also be easily deployed on AWS Elastic Container Service. Once you have [aws ecs cli](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_installation.html) installed, you can run the following to deploy it on ECS!
```
$ ./setup-aws-ecs.sh
```
