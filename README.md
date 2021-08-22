Hi.  So I built the docker image in an instance I just spun up.  I ended up getting it working with ELB and such that way first.

Once I tried to terraform it without a config management tool it forced me into using the ECR to store it and using a single instance ECS cluster to run it.
Some trial and error with the network mode made it interesting.
I technically got it to connect using awsvpc but I got a funky error from the application itself:
	panic: Get "https://www.rearc.io/quest001001222/": dial tcp 13.227.246.113:443: i/o timeout goroutine 1 [running]: main.main() /home/ubuntu/001.go:18 +0x4a9

After I switched to host network mode and changed the network configurations for the service and lb target I again got it to work.

The hardcodes that would need to be replaced in the terraform are the aws region, my IP in the security group, the ami for the ECS instance from us-east-2, the docker image location in my ECR and the self signed certificate I uploaded
