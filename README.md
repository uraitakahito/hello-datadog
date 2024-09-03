## How to start up

Build the image:

```sh
PROJECT=$(basename `pwd`) && docker image build -t $PROJECT-image . --build-arg user_id=`id -u` --build-arg group_id=`id -g`
```

Run docker containers:

```sh
docker container run -it --rm --init --hostname=$PROJECT --mount type=bind,src=`pwd`,dst=/app --name $PROJECT-container $PROJECT-image /bin/zsh
```

Start the Agent:

```sh
sudo service datadog-agent start
sudo datadog-agent status
```
