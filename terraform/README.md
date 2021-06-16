This repo is a demonstration of using Terraform to deploy multiple Nginx servers with one HAProxy server on AWS cloud.
The script will create all the required resources for the demo except for an SSH key which allows you (and Terraform's scripts) to connect securely to the servers.

## Project Architecture
![Project Architecture](Architecture.jpg?raw=true)

## Instructions:
1. Clone the Repo
2. Run the command: terraform init
3. Follow the In  structions in config.tf.example

## Still Missing:
- Dynamically add web servers by changing "webservers_count". Currently HAProxy doesn't updates.
